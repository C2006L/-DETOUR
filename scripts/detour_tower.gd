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
	if tower_type == "tesla":
		var ring: Node3D = model.get_node_or_null("SpinRing")
		if ring:
			ring.rotation.y = _spin * 1.6
		var core: MeshInstance3D = model.get_node_or_null("EnergyCore") as MeshInstance3D
		if core:
			core.rotation.y = -_spin * 0.9
	cooldown -= delta
	var target := _find_target()
	if target == null:
		return
	if head:
		var to := target.global_position - head.global_position
		var yaw := atan2(-to.x, -to.z)
		head.rotation.y = lerp_angle(head.rotation.y, yaw, clampf(delta * 9.0, 0.0, 1.0))
	if cooldown <= 0.0:
		_fire(target)
		cooldown = interval / float(DetourConfig.UPGRADE_RATE_MULT[level - 1])

func _find_target() -> DetourEnemy:
	var best: DetourEnemy = null
	var best_progress := -1.0
	for body in detection.get_overlapping_bodies():
		if body is DetourEnemy and body.hp > 0.0:
			var e := body as DetourEnemy
			if e.progress > best_progress:
				best = e
				best_progress = e.progress
	return best

func _fire(target: DetourEnemy) -> void:
	if tower_type == "tesla":
		for body in detection.get_overlapping_bodies():
			if body is DetourEnemy and body.hp > 0.0:
				var e := body as DetourEnemy
				e.apply_slow(slow, slow_duration)
				e.take_damage(damage * float(DetourConfig.UPGRADE_DAMAGE_MULT[level - 1]))
		main_ref.spawn_tesla_effect(global_position, range)
		return
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
	level += 1
	invested += upgrade_cost()
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
