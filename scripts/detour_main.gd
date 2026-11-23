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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ui.hide_menus()
		var ground := _screen_to_ground(get_viewport().get_mouse_position())
		if ground == Vector3.INF:
			return
		var tower := _tower_near(ground)
		if tower != null:
			ui.show_tower_menu(get_viewport().get_mouse_position(), tower.slot_index,
				"%s  Lv.%d" % [C.TOWERS[tower.tower_type]["name"], tower.level],
				"升级  %d 金" % tower.upgrade_cost() if tower.upgrade_cost() > 0 else "已满级",
				"出售  +%d 金" % tower.sell_value())
			return
		var rubble := _rubble_near(ground)
		if rubble != null:
			_try_clear_rubble(rubble)
			return
		var slot := _pad_near(ground)
		if slot >= 0:
			ui.show_build_menu(get_viewport().get_mouse_position(), slot)
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		ui._on_pause()

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
	if towers.has(slot) or game_over:
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
	if not towers.has(slot):
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
	if not towers.has(slot):
		return
	var tower: DetourTower = towers[slot]
	gold += tower.sell_value()
	spawn_explosion(tower.global_position, false)
	towers.erase(slot)
	tower.queue_free()
	_refresh_hud()

func _try_clear_rubble(node: Node3D) -> void:
	if not is_instance_valid(node) or node.has_meta("clearing"):
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
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 1.6, 0.30)
	tw.parallel().tween_property(m, "emission_energy_multiplier", 0.0, 0.30)
	tw.tween_callback(mi.queue_free)

func spawn_build_effect(pos: Vector3) -> void:
	_spawn_sparks(pos + Vector3(0, 0.3, 0), C.C_YELLOW, 8, 0.35)

func explode_at(pos: Vector3, radius: float, damage: float) -> void:
	for e in enemies:
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
	Engine.time_scale = 1.0
	get_tree().paused = false
	ui.show_result(victory, "完成波次 %d / %d  ·  击毁 %d 个敌人  ·  剩余金币 %d"
		% [wave_index, C.WAVES.size(), _kills, gold])
	_refresh_hud()

func _on_restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()
