extends RefCounted
class_name DetourProps

# ------------------------------------------------------------
# 场景道具库：工业建筑 / 围墙 / 植被 / 集装箱 / 管道 / 围栏 / 废墟杂物
# 造型参考秋日工业遗迹微缩景观，全部程序化体素组合。
# ------------------------------------------------------------

const VF = preload("res://scripts/voxel_factory.gd")

const IVORY := Color(0.82, 0.79, 0.69)
const SAND := Color(0.70, 0.66, 0.55)
const STONE := Color(0.53, 0.51, 0.46)
const DARK := Color(0.16, 0.17, 0.18)
const METAL := Color(0.37, 0.39, 0.41)
const STL := Color(0.55, 0.57, 0.58)
const RUST := Color(0.66, 0.29, 0.12)
const ORANGE := Color(0.96, 0.48, 0.10)
const YELLOW := Color(0.98, 0.74, 0.14)
const CYAN := Color(0.17, 0.86, 0.96)
const CDARK := Color(0.05, 0.34, 0.44)
const GREEN := Color(0.32, 0.46, 0.20)
const WOOD := Color(0.44, 0.30, 0.17)
const LEAF_A := Color(0.94, 0.56, 0.10)
const LEAF_B := Color(0.99, 0.75, 0.20)
const LEAF_C := Color(0.80, 0.30, 0.08)

# ============================================================
#  A 型建筑：暖白多层主厂房（阳台 / 楼梯 / 窗 / 屋顶设备）
# ============================================================
static func build_facility_a() -> Node3D:
	var root := Node3D.new()
	root.name = "FacilityA"
	# 基座
	VF.pbox(root, "Foundation", Vector3(2.70, 0.18, 2.10), Vector3(0, 0.09, 0), "stone", STONE)
	# 一层
	VF.pbox(root, "Floor1", Vector3(2.46, 1.02, 1.86), Vector3(0, 0.69, 0), "concrete", IVORY)
	VF.pbox(root, "Floor1Trim", Vector3(2.54, 0.10, 1.94), Vector3(0, 1.22, 0), "stone", SAND)
	# 二层（略收进，形成层次）
	VF.pbox(root, "Floor2", Vector3(2.20, 0.92, 1.66), Vector3(0, 1.72, 0), "concrete", SAND)
	VF.pbox(root, "Floor2Trim", Vector3(2.28, 0.09, 1.74), Vector3(0, 2.20, 0), "stone", IVORY)
	# 三层 / 顶层小屋
	VF.pbox(root, "Floor3", Vector3(1.50, 0.70, 1.20), Vector3(-0.30, 2.36, -0.10), "concrete", IVORY)
	VF.pbox(root, "RoofSlab", Vector3(1.62, 0.10, 1.32), Vector3(-0.30, 2.75, -0.10), "stone", SAND)
	# 一层窗（正面 + 侧面）
	for i in range(4):
		var x := -0.88 + float(i) * 0.58
		_frame_window(root, "W1_%d" % i, Vector3(x, 0.82, -0.96), false)
	for i in range(3):
		var z := -0.55 + float(i) * 0.58
		_frame_window(root, "WS1_%d" % i, Vector3(-1.26, 0.82, z), true)
	# 二层窗
	for i in range(3):
		var x := -0.72 + float(i) * 0.72
		_frame_window(root, "W2_%d" % i, Vector3(x, 1.84, -0.86), false)
	# 卷帘门 / 入口
	VF.pbox(root, "DoorFrame", Vector3(0.82, 0.92, 0.10), Vector3(0.55, 0.62, -0.96), "darkmetal")
	VF.pbox(root, "Door", Vector3(0.68, 0.78, 0.04), Vector3(0.55, 0.60, -1.02), "metal", METAL)
	for k in range(5):
		VF.pbox(root, "DoorSlat", Vector3(0.66, 0.025, 0.03), Vector3(0.55, 0.30 + k * 0.15, -1.05), "darkmetal")
	# 二层阳台（悬挑 + 栏杆）
	VF.pbox(root, "Balcony", Vector3(1.40, 0.10, 0.42), Vector3(0.20, 1.26, -1.02), "stone", SAND)
	for i in range(6):
		var x := -0.42 + float(i) * 0.25
		VF.pbox(root, "Baluster", Vector3(0.035, 0.30, 0.035), Vector3(x, 1.46, -1.18), "metal", METAL)
	VF.pbox(root, "RailTop", Vector3(1.36, 0.05, 0.05), Vector3(0.20, 1.62, -1.18), "darkmetal")
	# 外部楼梯
	for k in range(6):
		VF.pbox(root, "Stair%d" % k, Vector3(0.42, 0.08, 0.26),
			Vector3(-1.34, 0.18 + k * 0.20, -0.70 + k * 0.16), "stone", STONE)
	# 屋顶设备
	VF.pcyl(root, "Vent1", 0.16, 0.34, Vector3(0.62, 2.42, 0.44), "metal", METAL, 0.0, 8)
	VF.pcyl(root, "Vent2", 0.12, 0.26, Vector3(0.30, 2.38, 0.52), "rust", RUST, 0.0, 8)
	VF.pbox(root, "RooftopTank", Vector3(0.52, 0.46, 0.52), Vector3(0.62, 2.50, -0.42), "metal", STL)
	for sx in [-1.0, 1.0]:
		VF.pbox(root, "TankLeg", Vector3(0.08, 0.22, 0.08), Vector3(0.62 + sx * 0.20, 2.22, -0.42), "darkmetal")
	# 藤蔓 / 爬墙植被
	_vines(root, "VineA", -1.28, 0.55, 1.40, 0.42)
	_vines(root, "VineB", 1.24, 0.60, 0.90, -0.30)
	return root

# ============================================================
#  B 型建筑：锈色坡顶仓库（烟囱 / 破顶 / 管道）
# ============================================================
static func build_facility_b() -> Node3D:
	var root := Node3D.new()
	root.name = "FacilityB"
	VF.pbox(root, "Foundation", Vector3(2.30, 0.16, 1.90), Vector3(0, 0.08, 0), "stone", STONE)
	VF.pbox(root, "Hall", Vector3(2.10, 1.50, 1.70), Vector3(0, 0.91, 0), "rust", RUST)
	# 破坡顶（两段倾斜板 + 缺口）
	var roof_l := VF.pbox(root, "RoofL", Vector3(1.20, 0.10, 1.86), Vector3(-0.54, 1.88, 0), "metal", METAL)
	roof_l.rotation.z = 0.24
	var roof_r := VF.pbox(root, "RoofR", Vector3(0.86, 0.10, 1.86), Vector3(0.66, 1.76, 0), "rust", RUST)
	roof_r.rotation.z = -0.30
	# 大门 + 窗
	VF.pbox(root, "Gate", Vector3(0.92, 0.96, 0.06), Vector3(0, 0.64, -0.88), "darkmetal")
	VF.pbox(root, "GatePanel", Vector3(0.80, 0.84, 0.04), Vector3(0, 0.62, -0.92), "metal", STL)
	for i in range(3):
		_frame_window(root, "BW_%d" % i, Vector3(-0.62 + float(i) * 0.62, 1.24, -0.88), false)
	# 烟囱
	VF.pbox(root, "Stack", Vector3(0.42, 1.60, 0.42), Vector3(0.72, 2.30, 0.48), "brick", STONE)
	VF.pbox(root, "StackCap", Vector3(0.52, 0.12, 0.52), Vector3(0.72, 3.14, 0.48), "darkmetal")
	# 侧管道
	var pipe := VF.pcyl(root, "SidePipe", 0.10, 1.20, Vector3(-1.12, 0.90, 0.30), "metal", STL, 0.0, 8)
	pipe.rotation.z = 0.10
	Vbox(root, "PipeJoint", Vector3(0.24, 0.14, 0.24), Vector3(-1.12, 1.48, 0.30), "darkmetal")
	# 破损缺口（边缘碎块）
	Vbox(root, "Break1", Vector3(0.24, 0.22, 0.24), Vector3(0.96, 1.50, -0.70), "brick", STONE)
	Vbox(root, "Break2", Vector3(0.18, 0.16, 0.18), Vector3(1.02, 1.32, -0.46), "stone", STL)
	_vines(root, "VineC", -1.10, 0.40, 1.10, -0.20)
	return root

static func Vbox(parent: Node3D, name: String, size: Vector3, pos: Vector3, preset: String, tint: Color = Color.WHITE) -> MeshInstance3D:
	return VF.pbox(parent, name, size, pos, preset, tint)

static func _frame_window(parent: Node3D, name: String, pos: Vector3, side: bool) -> void:
	var g := Node3D.new()
	g.name = name
	g.position = pos
	parent.add_child(g)
	if side:
		VF.pbox(g, "Frame", Vector3(0.06, 0.34, 0.38), Vector3(0, 0, 0), "darkmetal")
		VF.pbox(g, "Glass", Vector3(0.03, 0.26, 0.30), Vector3(-0.04, 0, 0), "glass", Color(0.42, 0.62, 0.62), 0.5)
		VF.pbox(g, "Bar", Vector3(0.05, 0.30, 0.025), Vector3(-0.06, 0, 0), "metal", STL)
	else:
		VF.pbox(g, "Frame", Vector3(0.38, 0.34, 0.06), Vector3(0, 0, 0), "darkmetal")
		VF.pbox(g, "Glass", Vector3(0.30, 0.26, 0.03), Vector3(0, 0, -0.04), "glass", Color(0.42, 0.62, 0.62), 0.5)
		VF.pbox(g, "Bar", Vector3(0.025, 0.30, 0.05), Vector3(0, 0, -0.06), "metal", STL)
	VF.pbox(g, "Sill", Vector3(0.44, 0.04, 0.10) if not side else Vector3(0.10, 0.04, 0.44),
		Vector3(0, -0.19, -0.04) if not side else Vector3(-0.04, -0.19, 0), "stone", SAND)

static func _vines(parent: Node3D, name: String, x: float, y0: float, height: float, z: float) -> void:
	var g := Node3D.new()
	g.name = name
	parent.add_child(g)
	var patches := []
	for i in range(14):
		var t := float(i) / 14.0
		var px := x + sin(float(i) * 1.7) * 0.08
		var py := y0 + t * height
		var pz := z + cos(float(i) * 2.1) * 0.06
		var c := GREEN if i % 3 != 0 else LEAF_A
		patches.append({"size": Vector3(0.14, 0.10 + float(i % 3) * 0.05, 0.12),
			"pos": Vector3(px, py, pz), "color": c, "rot": Vector3(0, float(i), 0)})
	VF.batch(g, "VineLeaves", patches, "foliage")

# ============================================================
#  围墙 / 集装箱 / 管道 / 围栏 / 机械 / 杂物
# ============================================================
static func build_wall(seed_v: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "BrokenWall"
	var h := 0.70 + float(seed_v % 3) * 0.18
	VF.pbox(root, "Wall", Vector3(0.94, h, 0.42), Vector3(0, h * 0.5, 0), "brick", STONE)
	VF.pbox(root, "Cap", Vector3(0.96, 0.07, 0.46), Vector3(0, h + 0.02, 0), "stone", SAND)
	if seed_v % 3 == 0:
		VF.pbox(root, "Chipped", Vector3(0.30, 0.20, 0.44), Vector3(0.32, h - 0.10, 0), "brick", STONE)
	return root

static func build_container(color: Color = Color(0.55, 0.20, 0.16)) -> Node3D:
	var root := Node3D.new()
	root.name = "Container"
	VF.pbox(root, "Body", Vector3(1.34, 0.62, 0.82), Vector3(0, 0.35, 0), "rust", color)
	VF.pbox(root, "Top", Vector3(1.38, 0.07, 0.86), Vector3(0, 0.70, 0), "darkmetal")
	for i in range(7):
		var x := -0.56 + float(i) * 0.19
		VF.pbox(root, "RibF", Vector3(0.045, 0.54, 0.03), Vector3(x, 0.35, -0.43), "metal", METAL)
		VF.pbox(root, "RibB", Vector3(0.045, 0.54, 0.03), Vector3(x, 0.35, 0.43), "metal", METAL)
	for sx in [-1.0, 1.0]:
		VF.pbox(root, "Door", Vector3(0.03, 0.54, 0.36), Vector3(sx * 0.68, 0.35, 0), "darkmetal")
	return root

static func build_pipe() -> Node3D:
	var root := Node3D.new()
	root.name = "Pipe"
	var tube := VF.pcyl(root, "Tube", 0.14, 1.80, Vector3(0, 0.52, 0), "metal", STL, 0.0, 10)
	tube.rotation.z = PI * 0.5
	for sx in [-1.0, 1.0]:
		var joint := VF.pcyl(root, "Joint", 0.19, 0.14, Vector3(sx * 0.82, 0.52, 0), "darkmetal", Color.WHITE, 0.0, 10)
		joint.rotation.z = PI * 0.5
	VF.pbox(root, "Support", Vector3(0.16, 0.44, 0.32), Vector3(0, 0.24, 0), "darkmetal")
	VF.pbox(root, "Brace", Vector3(0.40, 0.08, 0.36), Vector3(0, 0.06, 0), "stone", STONE)
	# 阀门
	var valve := VF.pcyl(root, "Valve", 0.20, 0.04, Vector3(0, 0.52, 0), "paint", ORANGE, 0.0, 8)
	valve.rotation.x = PI * 0.5
	return root

static func build_fence() -> Node3D:
	var root := Node3D.new()
	root.name = "WireFence"
	for i in range(3):
		var x := -0.60 + float(i) * 0.60
		VF.pbox(root, "Post%d" % i, Vector3(0.06, 0.72, 0.06), Vector3(x, 0.36, 0), "metal", METAL)
		VF.pbox(root, "PostCap%d" % i, Vector3(0.10, 0.06, 0.10), Vector3(x, 0.74, 0), "darkmetal")
	# 细网格（多根细条）
	for i in range(7):
		var y := 0.10 + float(i) * 0.09
		VF.pbox(root, "WireH%d" % i, Vector3(1.24, 0.012, 0.012), Vector3(0, y, 0), "metal", STL)
	for i in range(9):
		var x := -0.56 + float(i) * 0.14
		VF.pbox(root, "WireV%d" % i, Vector3(0.012, 0.62, 0.012), Vector3(x, 0.41, 0), "metal", STL)
	VF.pbox(root, "TopRail", Vector3(1.28, 0.04, 0.04), Vector3(0, 0.70, 0), "paint", YELLOW)
	return root

static func build_machine() -> Node3D:
	var root := Node3D.new()
	root.name = "OldMachine"
	VF.pbox(root, "Base", Vector3(0.86, 0.16, 0.70), Vector3(0, 0.08, 0), "stone", STONE)
	VF.pbox(root, "Body", Vector3(0.66, 0.52, 0.52), Vector3(0, 0.42, 0), "metal", METAL)
	VF.pbox(root, "Panel", Vector3(0.50, 0.30, 0.06), Vector3(0, 0.46, -0.30), "darkmetal")
	for i in range(3):
		VF.pcyl(root, "Lamp", 0.045, 0.04, Vector3(-0.16 + float(i) * 0.16, 0.52, -0.36),
			"glass", ORANGE, 1.6, 8).rotation.x = PI * 0.5
	# 齿轮（用扁圆柱 + 齿块）
	for i in range(8):
		var a := TAU * float(i) / 8.0
		VF.pbox(root, "GearTooth", Vector3(0.10, 0.08, 0.10),
			Vector3(0.40 + cos(a) * 0.26, 0.44, sin(a) * 0.26), "rust", RUST).rotation.y = -a
	VF.pcyl(root, "Gear", 0.24, 0.10, Vector3(0.40, 0.44, 0), "rust", RUST, 0.0, 10).rotation.x = PI * 0.5
	# 顶部弯管
	var elbow := VF.pcyl(root, "Elbow", 0.08, 0.50, Vector3(-0.22, 0.90, 0), "metal", STL, 0.0, 8)
	elbow.rotation.z = 0.32
	return root

static func build_barrel() -> Node3D:
	var root := Node3D.new()
	root.name = "Barrel"
	VF.pcyl(root, "Body", 0.21, 0.52, Vector3(0, 0.26, 0), "rust", RUST, 0.0, 10)
	for y in [0.12, 0.40]:
		VF.pcyl(root, "Band", 0.225, 0.06, Vector3(0, y, 0), "darkmetal", Color.WHITE, 0.0, 10)
	VF.pcyl(root, "Lid", 0.21, 0.04, Vector3(0, 0.54, 0), "metal", METAL, 0.0, 10)
	return root

static func build_crate() -> Node3D:
	var root := Node3D.new()
	root.name = "Crate"
	VF.pbox(root, "Body", Vector3(0.48, 0.44, 0.48), Vector3(0, 0.22, 0), "wood", WOOD)
	for sx in [-1.0, 1.0]:
		VF.pbox(root, "Strap", Vector3(0.05, 0.46, 0.50), Vector3(sx * 0.20, 0.22, 0), "darkmetal")
	VF.pbox(root, "Top", Vector3(0.50, 0.04, 0.50), Vector3(0, 0.46, 0), "wood", Color(0.34, 0.23, 0.13))
	return root

# ============================================================
#  植被：秋季树（多簇不规则树冠）/ 灌木 / 碎石
# ============================================================
static func build_tree(scale: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "AutumnTree"
	root.scale = Vector3.ONE * scale
	# 树干分叉
	VF.pbox(root, "Trunk", Vector3(0.18, 0.92, 0.18), Vector3(0, 0.46, 0), "wood", WOOD)
	VF.pbox(root, "BranchL", Vector3(0.10, 0.44, 0.10), Vector3(-0.20, 1.02, 0), "wood", WOOD).rotation.z = 0.55
	VF.pbox(root, "BranchR", Vector3(0.10, 0.42, 0.10), Vector3(0.20, 1.06, 0.06), "wood", WOOD).rotation.z = -0.60
	# 多簇不规则树冠（不是单一球）
	var clusters := [
		[Vector3(0, 1.36, 0), 0.68, LEAF_A], [Vector3(-0.32, 1.18, 0.10), 0.50, LEAF_B],
		[Vector3(0.34, 1.24, -0.10), 0.52, LEAF_A], [Vector3(0.10, 1.62, 0.14), 0.46, LEAF_C],
		[Vector3(-0.16, 1.56, -0.24), 0.42, LEAF_B], [Vector3(0.30, 1.50, 0.26), 0.40, LEAF_A],
	]
	for i in range(clusters.size()):
		var c: Array = clusters[i]
		var pos: Vector3 = c[0]
		var sz := float(c[1])
		var col: Color = c[2]
		VF.pbox(root, "Crown%d" % i, Vector3(sz, sz * 0.72, sz * 0.92),
			pos, "foliage", col).rotation.y = float(i) * 0.7
		VF.pbox(root, "CrownTip%d" % i, Vector3(sz * 0.58, sz * 0.42, sz * 0.58),
			pos + Vector3(0.08, sz * 0.42, -0.05), "foliage",
			LEAF_B if i % 2 == 0 else LEAF_C)
	return root

static func build_shrub(seed_v: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Shrub"
	var patches := []
	for i in range(6):
		var a := TAU * float(i) / 6.0 + float(seed_v)
		var rad := 0.12 + float((i + seed_v) % 3) * 0.07
		patches.append({"size": Vector3(0.22, 0.16 + float(i % 3) * 0.06, 0.22),
			"pos": Vector3(cos(a) * rad, 0.10, sin(a) * rad),
			"color": GREEN if i % 2 == 0 else LEAF_A, "rot": Vector3(0, float(i), 0)})
	VF.batch(root, "Leaves", patches, "foliage")
	return root

static func build_rocks(seed_v: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Rocks"
	var patches := []
	for i in range(7):
		var a := TAU * float(i) / 7.0 + float(seed_v) * 0.9
		var rad := float((i * 3 + seed_v) % 5) * 0.11
		var sz := 0.10 + float((i + seed_v) % 4) * 0.055
		patches.append({"size": Vector3(sz, sz * 0.7, sz * 0.85),
			"pos": Vector3(cos(a) * rad, sz * 0.35, sin(a) * rad),
			"color": STONE if i % 2 == 0 else SAND, "rot": Vector3(0, float(i) * 0.8, 0)})
	VF.batch(root, "Stones", patches, "stone")
	return root
