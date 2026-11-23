extends Area3D
class_name DetourProjectile

var target: DetourEnemy
var speed: float = 20.0
var damage: float = 5.0
var splash: float = 0.0
var main_ref: Node
var is_shell: bool = false
var mesh_node: MeshInstance3D
var life: float = 3.0
var _roll: float = 0.0

func setup(t: DetourEnemy, spd: float, dmg: float, spl: float, ref: Node, shell: bool) -> void:
	# 暂停时冻结子弹飞行；根节点 main 为 ALWAYS，子节点需显式声明 PAUSABLE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	target = t
	speed = spd
	damage = dmg
	splash = spl
	main_ref = ref
	is_shell = shell
	collision_layer = 4
	collision_mask = 0
	mesh_node = MeshInstance3D.new()
	var m: Mesh
	if shell:
		var sphere := SphereMesh.new()
		sphere.radius = 0.13
		sphere.height = 0.26
		sphere.radial_segments = 6
		sphere.rings = 4
		m = sphere
	else:
		var cube := BoxMesh.new()
		cube.size = Vector3(0.10, 0.10, 0.22)
		m = cube
	mesh_node.mesh = m
	mesh_node.material_override = VoxelFactory.get_mat(
		DetourConfig.C_ORANGE if shell else DetourConfig.C_CYAN, 2.4 if shell else 2.0)
	add_child(mesh_node)
	var light := OmniLight3D.new()
	light.light_color = DetourConfig.C_ORANGE if shell else DetourConfig.C_CYAN
	light.light_energy = 0.8
	light.omni_range = 1.8
	add_child(light)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if not is_instance_valid(target):
		queue_free()
		return
	var aim := target.global_position + Vector3(0, 0.42 if target.enemy_type == "scout" else 0.85, 0)
	var offset := aim - global_position
	var dir := offset.normalized()
	if offset.length() < speed * delta + 0.12:
		impact(aim)
		return
	global_position += dir * speed * delta
	# 让子弹长轴（局部 -Z）指向实际飞行方向，与炮口朝向一致；
	# 翻滚仅作为绕飞行轴的自转，不再改变飞行朝向
	if is_instance_valid(mesh_node):
		mesh_node.look_at(global_position + dir, Vector3.UP)
		_roll += delta * 14.0
		mesh_node.rotate_object_local(Vector3.FORWARD, _roll)

func impact(at: Vector3) -> void:
	if splash > 0.0:
		main_ref.explode_at(at, splash, damage)
	else:
		target.take_damage(damage)
	main_ref.spawn_hit_effect(at, is_shell)
	queue_free()
