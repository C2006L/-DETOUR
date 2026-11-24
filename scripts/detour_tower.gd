extends Node3D
class_name DetourTower

var tower_type: String = "minigun"
var level: int = 1
var invested: int = 0
var slot_index: int = -1

var range: float = 4.5
var damage: float = 5.0
var interval: float = 0.25
var splash: float = 0.0
var slow: float = 0.0
var slow_duration: float = 1.5
var projectile_speed: float = 24.0

var cooldown: float = 0.0
var model: Node3D
var head: Node3D
var detection: Area3D
var main_ref: Node
var _spin: float = 0.0

func setup(type: String, slot: int, ref: Node) -> void:
	# 暂停时冻结索敌/冷却/旋转；根节点 main 为 ALWAYS，子节点需显式声明 PAUSABLE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	tower_type = type
	slot_index = slot
	main_ref = ref
	var cfg: Dictionary = DetourConfig.TOWERS[type]
	range = float(cfg["range"])
	damage = float(cfg["damage"])
	interval = float(cfg["interval"])
	splash = float(cfg.get("splash", 0.0))
	slow = float(cfg.get("slow", 0.0))
	slow_duration = float(cfg.get("slow_duration", 1.5))
	projectile_speed = float(cfg.get("projectile_speed", 0.0))
	invested = int(cfg["cost"])

	match type:
		"minigun": model = DetourModels.build_minigun()
		"cannon": model = DetourModels.build_cannon()
		"tesla": model = DetourModels.build_tesla()
	add_child(model)
	head = model.get_node_or_null("Head")

	detection = Area3D.new()
	detection.name = "Detection"
	detection.collision_layer = 0
	detection.collision_mask = 2
	var shape := SphereShape3D.new()
	shape.radius = range
	var col := CollisionShape3D.new()
	col.shape = shape
	detection.add_child(col)
	add_child(detection)

func _process(delta: float) -> void:
	_spin += delta
	cooldown -= delta
	var target := _find_target()
	if tower_type == "tesla":
		# 能量环转速与"是否有目标"挂钩：待机慢转，交战快转，
		# 让能量环成为真实攻击状态的指示，而非无目标的常速空转假象
		var combat_speed := 4.2 if target != null else 0.7
		var ring: Node3D = model.get_node_or_null("SpinRing")
		if ring:
			ring.rotation.y += delta * combat_speed
		var core: MeshInstance3D = model.get_node_or_null("EnergyCore") as MeshInstance3D
		if core:
			core.rotation.y -= delta * (2.0 if target != null else 0.35)
	if target == null:
		return
	if head:
		var yaw := _yaw_to(target.global_position)
		head.rotation.y = lerp_angle(head.rotation.y, yaw, clampf(delta * 9.0, 0.0, 1.0))
	if cooldown <= 0.0:
		_fire(target)
		cooldown = interval / float(DetourConfig.UPGRADE_RATE_MULT[level - 1])

# 开火瞬间让能量核心脉冲放大并短暂增亮，给玩家明确的"这一帧真的开火了"反馈。
# 用独立 Tween 只作用于 core 的 scale，不与 _process 里持续赋值的 rotation.y 冲突。
func _pulse_tesla_core() -> void:
	var core: MeshInstance3D = model.get_node_or_null("EnergyCore") as MeshInstance3D
	if core == null:
		return
	var base := Vector3.ONE
	var tw := create_tween()
	tw.tween_property(core, "scale", base * 1.45, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(core, "scale", base, 0.18).set_ease(Tween.EASE_IN_OUT)

# 统一的水平面朝向计算：模型正面为 -Z，故绕 Y 的 yaw = atan2(-dx, -dz)。
# 忽略 Y（高度差），确保炮口旋转与子弹飞行都基于同一个 XZ 平面方向。
func _yaw_to(world_pos: Vector3) -> float:
	var from := head.global_position if head else global_position
	var dx := world_pos.x - from.x
	var dz := world_pos.z - from.z
	return atan2(-dx, -dz)

# 地图铺在 XZ 平面，Y 是高度。索敌/范围判定一律用 XZ 平面距离，
# 避免把 3D 球体或 Z 轴当成平面造成误判；半径与数值保持 C.TOWERS 原样。
func _in_range(e: DetourEnemy) -> bool:
	var dx := e.global_position.x - global_position.x
	var dz := e.global_position.z - global_position.z
	return dx * dx + dz * dz <= range * range

func _find_target() -> DetourEnemy:
	var best: DetourEnemy = null
	var best_progress := -1.0
	for e in main_ref.enemies:
		if not is_instance_valid(e) or e.hp <= 0.0:
			continue
		if _in_range(e) and e.progress > best_progress:
			best = e
			best_progress = e.progress
	return best

func _fire(target: DetourEnemy) -> void:
	if tower_type == "tesla":
		# 电磁塔为范围伤害，同样按 XZ 平面判定命中，不依赖 3D 重叠体
		# 遍历快照：伤害致命会经 died 信号移除 enemies 元素，直接遍历会漏掉相邻敌人
		for e in main_ref.enemies.duplicate():
			if is_instance_valid(e) and e.hp > 0.0 and _in_range(e):
				e.apply_slow(slow, slow_duration)
				e.take_damage(damage * float(DetourConfig.UPGRADE_DAMAGE_MULT[level - 1]))
		main_ref.spawn_tesla_effect(global_position, range)
		_pulse_tesla_core()
		return
	# 开火瞬间把炮口精确对准目标（跳过 lerp 中间态），使炮口节点朝向、
	# 炮口生成点与子弹速度方向指向同一目标方向
	if head:
		head.rotation.y = _yaw_to(target.global_position)
		head.force_update_transform()
	var scene := preload("res://scripts/detour_projectile.gd")
	var origin := global_position + Vector3(0, 0.85, 0)
	if tower_type == "minigun":
		var m1: Node3D = head.get_node_or_null("MuzzleL") if head else null
		var m2: Node3D = head.get_node_or_null("MuzzleR") if head else null
		if m1 and m2:
			origin = (m1.global_position + m2.global_position) * 0.5
		elif head:
			origin = head.global_position
	elif tower_type == "cannon":
		var barrel: Node3D = head.get_node_or_null("MuzzleRing") if head else null
		if barrel:
			origin = barrel.global_position
	var proj := Area3D.new()
	proj.set_script(scene)
	main_ref.add_child(proj)
	proj.global_position = origin
	proj.setup(target, projectile_speed,
		damage * float(DetourConfig.UPGRADE_DAMAGE_MULT[level - 1]), splash, main_ref, tower_type == "cannon")
	main_ref.spawn_muzzle_flash(origin, tower_type)

func upgrade_cost() -> int:
	if level >= 3:
		return -1
	return int(DetourConfig.UPGRADE_COSTS[level - 1])

func upgrade() -> bool:
	if level >= 3:
		return false
	# 先取当前等级的升级费用再加级：加级后 upgrade_cost() 返回的是下一级价格
	var cost := upgrade_cost()
	level += 1
	invested += cost
	model.scale = Vector3.ONE * (1.0 + float(level - 1) * 0.07)
	if level == 3:
		var badge := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.16, 0.16)
		badge.mesh = bm
		badge.material_override = VoxelFactory.get_mat(DetourConfig.C_YELLOW, 1.8)
		badge.position = Vector3(0, 1.35, 0)
		model.add_child(badge)
	return true

func sell_value() -> int:
	return int(float(invested) * DetourConfig.SELL_RATIO)
