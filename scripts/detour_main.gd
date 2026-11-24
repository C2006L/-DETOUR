extends Node3D
class_name DetourMain

const C = preload("res://scripts/detour_config.gd")

var world: DetourWorld
var path_manager: PathManager
var ui: DetourUI

var gold: int = C.START_GOLD
var core_hp: int = C.CORE_HP
var wave_index: int = 0
var wave_active: bool = false
var game_over: bool = false
var prep_timer: float = C.PREP_TIME

var enemies: Array[DetourEnemy] = []
var towers: Dictionary = {}
var spawn_queue: Array[String] = []
var spawn_timer: float = 0.0

var paused: bool = false
var speed_scale: float = 1.0
var _kills: int = 0
var _elapsed: float = 0.0
var _core_pulse: float = 0.0
var _hover_rubble: Node3D = null
var range_ring: MeshInstance3D = null  # 选中炮塔时常驻显示真实射程圈
var _range_ring_mat: StandardMaterial3D = null

# 建造模式：半透明炮塔预览 + 射程环（只跟随鼠标悬停的合法平台）
var build_preview: Node3D = null
var build_preview_ring: MeshInstance3D = null
var build_preview_mat: StandardMaterial3D = null
var _preview_type: String = ""
var _preview_slot: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	path_manager = PathManager.new()
	path_manager.name = "PathManager"
	add_child(path_manager)

	world = DetourWorld.new()
	world.name = "World"
	add_child(world)
	# 暂停时冻结核心脉动/灯光动画：渲染照常，仅动画时间停止，恢复后无跳变
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.build(path_manager)

	ui = DetourUI.new()
	ui.name = "UI"
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	ui.build_choice.connect(_on_build_choice)
	ui.upgrade_requested.connect(_on_upgrade_requested)
	ui.sell_requested.connect(_on_sell_requested)
	ui.pause_toggled.connect(_on_pause_toggled)
	ui.speed_toggled.connect(_on_speed_toggled)
	ui.wave_start_requested.connect(_on_wave_start_requested)
	ui.restart_requested.connect(_on_restart)
	_refresh_hud()

func _process(delta: float) -> void:
	# 预览属于规划反馈：暂停时也跟随鼠标更新，便于暂停状态下规划建造
	if not game_over:
		_update_build_preview()
	if game_over or paused:
		return
	_elapsed += delta
	for e in enemies:
		if is_instance_valid(e):
			e.face_camera(world.main_camera)

	if not wave_active:
		prep_timer -= delta
		if prep_timer <= 0.0:
			_start_wave()
	else:
		_tick_spawns(delta)
		if spawn_queue.is_empty() and enemies.is_empty():
			_finish_wave()

	_refresh_hud()
	_update_rubble_hover()
	_update_range_ring()

# ------------------------------------------------------------
# 悬停到可拆废墟时高亮警示标记，并在状态栏给出提示（纯视觉，不改数值）
func _update_rubble_hover() -> void:
	var ground := _screen_to_ground(get_viewport().get_mouse_position())
	var hit: Node3D = null
	if ground != Vector3.INF:
		hit = _rubble_near(ground)
	if hit != _hover_rubble:
		if is_instance_valid(_hover_rubble):
			_set_rubble_highlight(_hover_rubble, false)
		_hover_rubble = hit
		if is_instance_valid(hit):
			_set_rubble_highlight(hit, true)
	if is_instance_valid(hit):
		ui.lbl_status.text = "可拆除废墟 · 点击 +20 金"

func _set_rubble_highlight(node: Node3D, on: bool) -> void:
	var mark := node.get_node_or_null("Mark")
	if mark:
		mark.scale = Vector3.ONE * (1.45 if on else 1.0)

# ------------------------------------------------------------
# 选中炮塔时显示真实射程圈（半透明环）。跟随 ui.selected_tower_slot：
# 打开炮塔菜单即显示，关闭或出售后自动隐藏。电磁塔借此明确 4.0 格真实范围。
func _update_range_ring() -> void:
	var show := ui.tower_menu != null and ui.tower_menu.visible and ui.selected_tower_slot >= 0
	var tw: DetourTower = null
	if show:
		tw = towers.get(ui.selected_tower_slot) as DetourTower
	if show and is_instance_valid(tw):
		if range_ring == null:
			range_ring = MeshInstance3D.new()
			range_ring.name = "RangeRing"
			var torus := TorusMesh.new()
			torus.inner_radius = 0.96
			torus.outer_radius = 1.0
			torus.rings = 6
			torus.ring_segments = 48
			range_ring.mesh = torus
			_range_ring_mat = StandardMaterial3D.new()
			_range_ring_mat.albedo_color = C.C_CYAN
			_range_ring_mat.emission_enabled = true
			_range_ring_mat.emission = C.C_CYAN
			_range_ring_mat.emission_energy_multiplier = 0.9
			range_ring.material_override = _range_ring_mat
			range_ring.rotation.x = PI * 0.5
			add_child(range_ring)
		range_ring.visible = true
		range_ring.global_position = tw.global_position + Vector3(0, 0.30, 0)
		range_ring.scale = Vector3.ONE * tw.range
	else:
		if is_instance_valid(range_ring):
			range_ring.visible = false

# ------------------------------------------------------------
func _tick_spawns(delta: float) -> void:
	if spawn_queue.is_empty():
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var type: String = spawn_queue.pop_front()
	_spawn_enemy(type)
	spawn_timer = 0.72 if type == "scout" else 1.35

func _spawn_enemy(type: String) -> void:
	var enemy := DetourEnemy.new()
	add_child(enemy)
	enemy.setup(type, path_manager.get_points(), path_manager)
	enemy.died.connect(_on_enemy_died)
	enemy.reached_core.connect(_on_enemy_reached_core)
	enemies.append(enemy)

func _start_wave() -> void:
	if wave_index >= C.WAVES.size() or game_over:
		return
	wave_index += 1
	wave_active = true
	spawn_queue.clear()
	var groups: Array = C.WAVES[wave_index - 1]
	var max_count := 0
	for g in groups:
		max_count = maxi(max_count, int(g["count"]))
	for i in range(max_count):
		for g in groups:
			if i < int(g["count"]):
				spawn_queue.append(String(g["type"]))
	spawn_timer = 0.5

func _finish_wave() -> void:
	wave_active = false
	if wave_index >= C.WAVES.size():
		_end_game(true)
	else:
		prep_timer = C.PREP_TIME
		gold += 40
		_show_toast("第 %d 波结束 · 奖励 40 金" % wave_index)

func _on_wave_start_requested() -> void:
	if not wave_active and not game_over and wave_index < C.WAVES.size():
		_start_wave()

# ------------------------------------------------------------
func _on_enemy_died(enemy: DetourEnemy) -> void:
	gold += enemy.reward
	_kills += 1
	spawn_explosion(enemy.global_position, enemy.enemy_type == "mech")
	enemies.erase(enemy)
	enemy.queue_free()

func _on_enemy_reached_core(enemy: DetourEnemy) -> void:
	core_hp -= enemy.core_damage
	_core_pulse = 0.5
	spawn_explosion(enemy.global_position, false)
	enemies.erase(enemy)
	enemy.queue_free()
	if core_hp <= 0:
		core_hp = 0
		_end_game(false)

# ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_build_mode()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		ui.hide_menus()
		var screen := get_viewport().get_mouse_position()
		var ground := _screen_to_ground(screen)
		if ground == Vector3.INF:
			return
		_handle_world_click(ground, screen)
	if event is InputEventKey and event.pressed and not event.echo:
		# 数字键 1/2/3 与点击底部炮塔卡等价（进入对应建造模式）
		if event.keycode == KEY_1:
			ui.select_build_type("minigun")
			return
		elif event.keycode == KEY_2:
			ui.select_build_type("cannon")
			return
		elif event.keycode == KEY_3:
			ui.select_build_type("tesla")
			return
		elif event.keycode == KEY_ESCAPE:
			_cancel_build_mode()
			ui.hide_menus()
			return
		elif event.keycode == KEY_SPACE:
			ui._on_pause()

# 世界点击路由：建造模式下优先直接建造；未选择时保留原平台弹出菜单。
func _handle_world_click(ground: Vector3, screen: Vector2) -> void:
	if game_over:
		return
	var build_type := ui.selected_build_type()
	if build_type != "":
		var slot := _pad_near(ground)
		if slot >= 0:
			# 已建塔平台优先打开升级/出售菜单，并退出建造模式，避免误覆盖原交互
			if towers.has(slot):
				_show_toast("平台已被占用 · 已打开升级/出售面板")
				_show_tower_menu_at(towers[slot], screen)
				ui.clear_build_selection()
				_hide_build_preview()
				return
			var cost := int(C.TOWERS[build_type]["cost"])
			if gold < cost:
				_show_toast("金币不足 · %s 需要 %d 金" % [C.TOWERS[build_type]["name"], cost])
				return
			_on_build_choice(build_type, slot)
			return
		_show_toast("请选择青蓝色建造平台 · ESC / 右键取消")
		return

	var tower := _tower_near(ground)
	if tower != null:
		_show_tower_menu_at(tower, screen)
		return
	var rubble := _rubble_near(ground)
	if rubble != null:
		_try_clear_rubble(rubble)
		return
	var pad_slot := _pad_near(ground)
	if pad_slot >= 0:
		ui.show_build_menu(screen, pad_slot)

func _show_tower_menu_at(tower: DetourTower, screen: Vector2) -> void:
	var role: String = String(C.TOWERS[tower.tower_type].get("role", ""))
	ui.show_tower_menu(screen, tower.slot_index,
		"%s  Lv.%d%s" % [C.TOWERS[tower.tower_type]["name"], tower.level,
			" · " + role if role != "" else ""],
		"升级  %d 金" % tower.upgrade_cost() if tower.upgrade_cost() > 0 else "已满级",
		"出售  +%d 金" % tower.sell_value())

# ------------------------------------------------------------
# 建造预览：半透明炮塔本体 + 与真实射程一致的半透明环
# ------------------------------------------------------------
func _cancel_build_mode() -> void:
	if ui.selected_build_type() == "":
		ui.hide_menus()
		return
	ui.clear_build_selection()
	_hide_build_preview()
	_show_toast("已取消建造")

func _hide_build_preview() -> void:
	if is_instance_valid(build_preview):
		build_preview.queue_free()
	build_preview = null
	build_preview_ring = null
	build_preview_mat = null
	_preview_type = ""
	_preview_slot = -1

func _rebuild_build_preview(type: String) -> void:
	_hide_build_preview()
	var ghost: Node3D
	match type:
		"minigun": ghost = DetourModels.build_minigun()
		"cannon": ghost = DetourModels.build_cannon()
		"tesla": ghost = DetourModels.build_tesla()
		_: return
	ghost.name = "BuildPreview"
	build_preview_mat = StandardMaterial3D.new()
	build_preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	build_preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	build_preview_mat.albedo_color = Color(C.C_CYAN.r, C.C_CYAN.g, C.C_CYAN.b, 0.34)
	for mi in ghost.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = mi as MeshInstance3D
		mesh.material_override = build_preview_mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshInstance3D.new()
	ring.name = "RangeRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.96
	torus.outer_radius = 1.0
	torus.rings = 6
	torus.ring_segments = 48
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(C.C_CYAN.r, C.C_CYAN.g, C.C_CYAN.b, 0.55)
	rm.emission_enabled = true
	rm.emission = C.C_CYAN
	rm.emission_energy_multiplier = 0.5
	ring.material_override = rm
	ring.rotation.x = PI * 0.5
	ring.position.y = 0.16
	ghost.add_child(ring)
	build_preview_ring = ring
	add_child(ghost)
	build_preview = ghost
	_preview_type = type

func _update_build_preview() -> void:
	var type := ui.selected_build_type()
	if type == "" or not C.TOWERS.has(type):
		_hide_build_preview()
		return
	var ground := _screen_to_ground(get_viewport().get_mouse_position())
	if ground == Vector3.INF:
		_hide_build_preview()
		return
	var slot := _pad_near(ground)
	if slot < 0 or towers.has(slot):
		_hide_build_preview()
		return
	if type != _preview_type:
		_rebuild_build_preview(type)
	if not is_instance_valid(build_preview):
		return
	var pad: Node3D = world.build_pads[slot]
	build_preview.visible = true
	build_preview.global_position = pad.global_position + Vector3(0, 0.14, 0)
	var cfg: Dictionary = C.TOWERS[type]
	var affordable := gold >= int(cfg["cost"])
	var tint: Color = C.C_CYAN if affordable else C.C_RED
	if build_preview_mat != null:
		build_preview_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.34)
	if is_instance_valid(build_preview_ring):
		build_preview_ring.scale = Vector3.ONE * float(cfg["range"])
		var rm := build_preview_ring.material_override as StandardMaterial3D
		if rm != null:
			rm.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
			rm.emission = tint
	_preview_slot = slot

func _screen_to_ground(screen: Vector2) -> Vector3:
	var cam := world.main_camera
	if cam == null:
		return Vector3.INF
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var plane := Plane(Vector3.UP, 0.30)
	var hit = plane.intersects_ray(from, dir)
	if hit == null:
		return Vector3.INF
	return hit

func _pad_near(pos: Vector3) -> int:
	var best := -1
	var best_d := 0.72
	for pad in world.build_pads:
		var d := pad.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = int(pad.get_meta("slot_index"))
	return best

func _tower_near(pos: Vector3) -> DetourTower:
	for t in towers.values():
		var tw := t as DetourTower
		if tw.global_position.distance_to(pos) < 0.62:
			return tw
	return null

func _rubble_near(pos: Vector3) -> Node3D:
	for r in world.rubble_nodes:
		# 已拆除的节点会在 Tween 完成后释放，数组里可能残留失效引用；
		# 跳过它们，避免访问 global_position 抛错中断整个输入处理链
		if not is_instance_valid(r):
			continue
		if r.has_meta("clearing"):
			continue
		if r.global_position.distance_to(pos) < 0.70:
			return r
	return null

func _on_build_choice(type: String, slot: int) -> void:
	if game_over or slot < 0 or slot >= world.build_pads.size() or not C.TOWERS.has(type):
		return
	if towers.has(slot):
		_show_toast("平台已被占用")
		return
	var cfg: Dictionary = C.TOWERS[type]
	var cost := int(cfg["cost"])
	if gold < cost:
		_show_toast("金币不足")
		return
	gold -= cost
	var tower := DetourTower.new()
	tower.name = "Tower_%s_%d" % [type, slot]
	add_child(tower)
	var pad: Node3D = world.build_pads[slot]
	tower.global_position = pad.global_position + Vector3(0, 0.14, 0)
	tower.setup(type, slot, self)
	towers[slot] = tower
	spawn_build_effect(tower.global_position)
	_refresh_hud()

func _on_upgrade_requested(slot: int) -> void:
	if game_over or not towers.has(slot):
		return
	var tower: DetourTower = towers[slot]
	var cost := tower.upgrade_cost()
	if cost < 0:
		_show_toast("已满级")
		return
	if gold < cost:
		_show_toast("金币不足")
		return
	gold -= cost
	tower.upgrade()
	spawn_build_effect(tower.global_position)
	_refresh_hud()

func _on_sell_requested(slot: int) -> void:
	if game_over or not towers.has(slot):
		return
	var tower: DetourTower = towers[slot]
	gold += tower.sell_value()
	spawn_explosion(tower.global_position, false)
	towers.erase(slot)
	tower.queue_free()
	_refresh_hud()

func _try_clear_rubble(node: Node3D) -> void:
	if game_over or not is_instance_valid(node) or node.has_meta("clearing"):
		return
	node.set_meta("clearing", true)
	# 立即移出可交互列表：否则 Tween 释放节点后数组残留失效引用，
	# 后续点击在 _rubble_near 中访问 global_position 抛错，中断整个输入链（表现为点击无响应）
	world.rubble_nodes.erase(node)
	if _hover_rubble == node:
		_hover_rubble = null
	gold += 20
	spawn_explosion(node.global_position, false)
	_show_toast("废墟拆除 · +20 金")
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3.ZERO, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)
	_refresh_hud()

# ------------------------------------------------------------
func spawn_muzzle_flash(pos: Vector3, type: String) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16 if type == "minigun" else 0.24
	mesh.height = mesh.radius * 2.0
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = C.C_ORANGE if type == "cannon" else C.C_CYAN
	m.emission_enabled = true
	m.emission = m.albedo_color
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.9, 0.09)
	tw.parallel().tween_property(m, "emission_energy_multiplier", 0.0, 0.09)
	tw.tween_callback(mi.queue_free)

func spawn_hit_effect(pos: Vector3, big: bool) -> void:
	_spawn_sparks(pos, C.C_ORANGE if big else C.C_CYAN, 5 if big else 3, 0.22)

func spawn_explosion(pos: Vector3, big: bool) -> void:
	var color: Color = C.C_ORANGE if big else C.C_YELLOW
	_spawn_sparks(pos, color, 12 if big else 7, 0.45)
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.35 if big else 0.22
	sph.height = sph.radius * 2.0
	mi.mesh = sph
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * (3.2 if big else 2.0), 0.26)
	tw.parallel().tween_property(m, "emission_energy_multiplier", 0.0, 0.26)
	tw.tween_callback(mi.queue_free)

func _spawn_sparks(pos: Vector3, color: Color, count: int, lifetime: float) -> void:
	for i in range(count):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.10, 0.10, 0.10)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
		mi.material_override = m
		add_child(mi)
		mi.global_position = pos
		var a := TAU * float(i) / float(count)
		var dest := pos + Vector3(cos(a) * (0.6 + float(i % 3) * 0.2),
			0.4 + float(i % 4) * 0.18, sin(a) * (0.6 + float(i % 3) * 0.2))
		var tw := create_tween()
		tw.tween_property(mi, "global_position", dest, lifetime)
		tw.parallel().tween_property(mi, "scale", Vector3.ZERO, lifetime)
		tw.tween_callback(mi.queue_free)

func spawn_tesla_effect(pos: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.20
	ring.outer_radius = 0.28
	ring.rings = 12
	ring.ring_segments = 24
	mi.mesh = ring
	var m := StandardMaterial3D.new()
	m.albedo_color = C.C_CYAN
	m.emission_enabled = true
	m.emission = C.C_CYAN
	m.emission_energy_multiplier = 2.5
	mi.material_override = m
	mi.rotation.x = PI * 0.5
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.6, 0)
	var tw := create_tween()
	# 视觉对齐：TorusMesh 外缘半径 = 0.28，放大 radius/0.28 倍后外缘≈radius，
	# 使开火特效环与电磁塔 4.0 格真实 AOE 判定范围一致（原来只到 1.79 格）
	var target_scale := radius / 0.28
	tw.tween_property(mi, "scale", Vector3.ONE * target_scale, 0.30)
	tw.parallel().tween_property(m, "emission_energy_multiplier", 0.0, 0.30)
	tw.tween_callback(mi.queue_free)

func spawn_build_effect(pos: Vector3) -> void:
	_spawn_sparks(pos + Vector3(0, 0.3, 0), C.C_YELLOW, 8, 0.35)

func explode_at(pos: Vector3, radius: float, damage: float) -> void:
	# 遍历快照：take_damage 致命时会经 died 信号从 enemies 中移除该敌人，
	# 直接遍历原数组会跳过紧邻的下一个敌人，导致范围内部分敌人漏伤/漏金币。
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.global_position.distance_to(pos) <= radius:
			e.take_damage(damage)
	spawn_explosion(pos, true)

# ------------------------------------------------------------
func _on_pause_toggled() -> void:
	paused = !paused
	get_tree().paused = paused

func _on_speed_toggled() -> void:
	speed_scale = ui.speed_scale()
	Engine.time_scale = speed_scale

func _refresh_hud() -> void:
	var status := ""
	if game_over:
		status = "已结束"
	elif wave_active:
		status = "进攻中 · 剩余 %d" % (enemies.size() + spawn_queue.size())
	else:
		status = "准备中 %ds" % maxi(0, int(prep_timer))
	ui.update_hud(gold, core_hp, wave_index, C.WAVES.size(), status)
	world.set_core_health_ratio(float(core_hp) / float(C.CORE_HP))

func _show_toast(text: String) -> void:
	ui.lbl_status.text = text

func _end_game(victory: bool) -> void:
	game_over = true
	wave_active = false
	ui.build_input_enabled = false
	ui.clear_build_selection()
	_hide_build_preview()
	Engine.time_scale = 1.0
	get_tree().paused = false
	ui.show_result(victory, "完成波次 %d / %d  ·  击毁 %d 个敌人  ·  剩余金币 %d"
		% [wave_index, C.WAVES.size(), _kills, gold])
	_refresh_hud()

func _on_restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()
