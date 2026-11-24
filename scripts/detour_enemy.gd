extends CharacterBody3D
class_name DetourEnemy

signal died(enemy: DetourEnemy)
signal reached_core(enemy: DetourEnemy)

var enemy_type: String = "scout"
var max_hp: float = 40.0
var hp: float = 40.0
var move_speed: float = 2.4
var reward: int = 10
var core_damage: int = 1

var path: Array[Vector3] = []
var path_index: int = 0
var progress: float = 0.0

var slow_factor: float = 1.0
var slow_timer: float = 0.0
var model: Node3D
var hp_bar: Node3D
var hp_fill: MeshInstance3D
var slow_ring: MeshInstance3D  # 减速指示环：受电磁塔减速时常驻显形，材质独立不共享
var _leg_base_y: Array[float] = []
var _anim_time: float = 0.0
var _flash_timer: float = 0.0
var path_manager: PathManager

# 血条专用 unshaded 材质缓存：不受场景光照影响，避免暗场景把血量压成黑色
static var _hp_bar_mats: Dictionary = {}

static func _hp_bar_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _hp_bar_mats.has(key):
		return _hp_bar_mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.35
	_hp_bar_mats[key] = m
	return m

func setup(type: String, points: Array[Vector3], manager: PathManager) -> void:
	# 暂停时冻结移动/动画；根节点 main 为 ALWAYS，子节点需显式声明 PAUSABLE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy_type = type
	path = points.duplicate()
	path_manager = manager
	var cfg: Dictionary = DetourConfig.ENEMIES[type]
	max_hp = float(cfg["hp"])
	hp = max_hp
	move_speed = float(cfg["speed"])
	reward = int(cfg["reward"])
	core_damage = int(cfg["core_damage"])

	collision_layer = 2
	collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 0.32 if type == "scout" else 0.48
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = shape.radius
	add_child(col)

	model = DetourModels.build_scout() if type == "scout" else DetourModels.build_mech()
	add_child(model)
	for i in range(4):
		var leg: Node3D = model.get_node_or_null("Leg%d" % i)
		_leg_base_y.append(leg.position.y if leg else 0.0)

	_build_hp_bar()
	_build_slow_ring()
	if path.size() > 0:
		global_position = path[0]

func _build_hp_bar() -> void:
	hp_bar = Node3D.new()
	hp_bar.name = "HealthBar"
	hp_bar.position.y = 1.05 if enemy_type == "mech" else 0.78
	add_child(hp_bar)
	var bg := MeshInstance3D.new()
	var bgm := BoxMesh.new()
	bgm.size = Vector3(0.60, 0.08, 0.02)
	bg.mesh = bgm
	# 深色底衬：仍用 unshaded，保证暗场景里也能看清血条轮廓
	bg.material_override = _hp_bar_mat(Color(0.06, 0.07, 0.09))
	hp_bar.add_child(bg)
	hp_fill = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.56, 0.05, 0.02)
	hp_fill.mesh = fm
	hp_fill.material_override = _hp_bar_mat(Color(0.30, 0.92, 0.46))
	# 填充必须位于底衬【朝向相机】的一侧（局部 +Z），否则会被底衬完全遮住显示为黑色
	hp_fill.position.z = 0.02
	hp_bar.add_child(hp_fill)

# 减速指示环：电磁塔命中后显形，玩家可直观看到"这个敌人被减速了"。
# 用独立材质实例（不经过 VoxelFactory 缓存），避免染色连带影响其他敌人。
func _build_slow_ring() -> void:
	slow_ring = MeshInstance3D.new()
	slow_ring.name = "SlowRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34 if enemy_type == "scout" else 0.50
	torus.outer_radius = 0.40 if enemy_type == "scout" else 0.57
	torus.rings = 8
	torus.ring_segments = 20
	slow_ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.85, 0.92)
	m.emission_enabled = true
	m.emission = Color(0.16, 0.85, 0.92)
	m.emission_energy_multiplier = 1.4
	slow_ring.material_override = m
	slow_ring.rotation.x = PI * 0.5
	slow_ring.position.y = 0.04
	slow_ring.visible = false
	add_child(slow_ring)

func _physics_process(delta: float) -> void:
	_anim_time += delta
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
	# 减速指示环：随减速状态显隐，并缓慢旋转强调"受控"状态
	if slow_ring:
		slow_ring.visible = slow_timer > 0.0
		if slow_ring.visible:
			slow_ring.rotation.z += delta * 1.8
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			model.scale = Vector3.ONE

	if path_index >= path.size():
		return
	var target := path[path_index]
	var flat := Vector3(target.x, global_position.y, target.z)
	var offset := flat - global_position
	var dist := offset.length()
	if dist < 0.16:
		path_index += 1
		if path_index >= path.size():
			reached_core.emit(self)
			return
		return
	var dir := offset / dist
	velocity = dir * move_speed * slow_factor
	move_and_slide()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), 0.25)
	progress = path_manager.progress_at(global_position, path_index)

	for i in range(4):
		var leg: Node3D = model.get_node_or_null("Leg%d" % i)
		if leg and i < _leg_base_y.size():
			leg.position.y = _leg_base_y[i] + sin(_anim_time * (10.0 if enemy_type == "scout" else 6.0) + float(i) * PI) * 0.05

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, 1.0 - factor)
	slow_timer = maxf(slow_timer, duration)

func take_damage(amount: float) -> void:
	# 已死亡敌人不再结算，避免同帧多发子弹/溅射重复触发 died 信号
	# （重复发信号会重复发放金币与击杀计数）
	if hp <= 0.0:
		return
	hp -= amount
	_flash_timer = 0.10
	model.scale = Vector3(1.12, 0.90, 1.12)
	var ratio := clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	hp_fill.scale.x = ratio
	hp_fill.position.x = -(1.0 - ratio) * 0.28
	hp_fill.material_override = _hp_bar_mat(
		Color(0.30, 0.92, 0.46) if ratio > 0.4 else Color(0.95, 0.30, 0.20))
	if hp <= 0.0:
		died.emit(self)

func face_camera(cam: Camera3D) -> void:
	if hp_bar and cam:
		hp_bar.rotation.y = atan2(cam.global_position.x - global_position.x,
			cam.global_position.z - global_position.z)
