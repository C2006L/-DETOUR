extends RefCounted
class_name VoxelFactory

# ------------------------------------------------------------
# 体素几何工厂
# - 旧接口 box/cylinder/get_mat 保留（特效与子弹使用）
# - 新接口 pbox/pcyl/pocta 使用统一材质预设
# - batch() 用 MultiMesh 批量渲染海量小细节，避免上千个独立节点
# ------------------------------------------------------------

const M = preload("res://scripts/detour_materials.gd")

static var _mat_cache: Dictionary = {}
static var _unit_box: BoxMesh = null
static var _unit_cyl: CylinderMesh = null

# ---------------- 旧接口（特效/子弹） ----------------
static func get_mat(color: Color, emission: float = 0.0, metallic: float = 0.15, roughness: float = 0.72) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%.2f" % [color.to_html(), emission, metallic, roughness]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mat_cache[key] = m
	return m

static func box(parent: Node3D, name: String, size: Vector3, pos: Vector3, color: Color,
		emission: float = 0.0, metallic: float = 0.15, roughness: float = 0.72) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = get_mat(color, emission, metallic, roughness)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func cylinder(parent: Node3D, name: String, radius: float, height: float, pos: Vector3,
		color: Color, emission: float = 0.0, sides: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = get_mat(color, emission, 0.35, 0.55)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func prism(parent: Node3D, name: String, size: Vector3, pos: Vector3, color: Color,
		emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var arr := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var p0 := Vector3(-hx, -hy, -hz)
	var p1 := Vector3(hx, -hy, -hz)
	var p2 := Vector3(hx, -hy, hz)
	var p3 := Vector3(-hx, -hy, hz)
	var p4 := Vector3(-hx, hy, hz)
	var p5 := Vector3(hx, hy, hz)
	for tri in [[p0, p2, p1], [p0, p3, p2], [p0, p1, p5], [p0, p5, p4], [p1, p2, p5], [p2, p4, p5], [p3, p4, p2], [p3, p0, p4]]:
		for v in tri:
			st.add_vertex(v)
	st.generate_normals()
	arr = st.commit()
	mi.mesh = arr
	mi.position = pos
	mi.material_override = get_mat(color, emission)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func ring_of_boxes(parent: Node3D, name: String, radius: float, count: int,
		box_size: Vector3, y: float, color: Color, emission: float = 0.0) -> Node3D:
	var group := Node3D.new()
	group.name = name
	group.position.y = y
	parent.add_child(group)
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var b := box(group, "%s_%d" % [name, i], box_size,
			Vector3(cos(a) * radius, 0.0, sin(a) * radius), color, emission)
		b.rotation.y = -a
	return group

# ---------------- 新接口（统一材质预设 + 共享网格） ----------------
static func _unit_box_mesh() -> BoxMesh:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	return _unit_box

static func pbox(parent: Node3D, name: String, size: Vector3, pos: Vector3,
		preset: String, tint: Color = Color.WHITE, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = _unit_box_mesh()
	mi.scale = size
	mi.position = pos
	mi.material_override = M.mat(preset, tint, emission)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func pcyl(parent: Node3D, name: String, radius: float, height: float, pos: Vector3,
		preset: String, tint: Color = Color.WHITE, emission: float = 0.0, sides: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = M.mat(preset, tint, emission)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

# 八面体晶体（发光核心 / 能源水晶）
static func pocta(parent: Node3D, name: String, radius: float, height: float, pos: Vector3,
		preset: String, tint: Color, emission: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, height, 0)
	var bot := Vector3(0, -height, 0)
	var ring := [
		Vector3(radius, 0, 0), Vector3(0, 0, radius),
		Vector3(-radius, 0, 0), Vector3(0, 0, -radius),
	]
	for i in range(4):
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		st.add_vertex(top); st.add_vertex(a); st.add_vertex(b)
		st.add_vertex(bot); st.add_vertex(b); st.add_vertex(a)
	st.generate_normals()
	mi.mesh = st.commit()
	mi.position = pos
	mi.material_override = M.mat(preset, tint, emission)
	parent.add_child(mi)
	return mi

# 棱锥（尖顶 / 机械脚）
static func pcone(parent: Node3D, name: String, radius: float, height: float, pos: Vector3,
		preset: String, tint: Color, emission: float = 0.0, sides: int = 4) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(sides):
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var p0 := Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		st.add_vertex(Vector3(0, height, 0)); st.add_vertex(p0); st.add_vertex(p1)
		st.add_vertex(Vector3(0, 0, 0)); st.add_vertex(p1); st.add_vertex(p0)
	st.generate_normals()
	mi.mesh = st.commit()
	mi.position = pos
	mi.material_override = M.mat(preset, tint, emission)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

# 批量立方体：items = [{size, pos, color, rot(可选)}]
static func batch(parent: Node3D, name: String, items: Array, preset: String,
		emission: float = 0.0, cast_shadow: bool = false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _unit_box_mesh()
	mm.instance_count = items.size()
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var sz: Vector3 = it.get("size", Vector3.ONE)
		var pos: Vector3 = it.get("pos", Vector3.ZERO)
		var rot: Vector3 = it.get("rot", Vector3.ZERO)
		var xf := Transform3D()
		if rot.x != 0.0:
			xf = xf.rotated(Vector3.RIGHT, rot.x)
		if rot.y != 0.0:
			xf = xf.rotated(Vector3.UP, rot.y)
		if rot.z != 0.0:
			xf = xf.rotated(Vector3.FORWARD, rot.z)
		xf = xf.scaled(sz)
		xf.origin = pos
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, it.get("color", Color.WHITE))
	var mi := MultiMeshInstance3D.new()
	mi.name = name
	mi.multimesh = mm
	mi.material_override = M.batch_mat(preset, emission)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
