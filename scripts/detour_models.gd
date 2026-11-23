extends RefCounted
class_name DetourModels

# ------------------------------------------------------------
# 游戏实体模型：三种炮塔 / 两种敌人 / 能源核心 / 入口 / 平台 / 废墟
# 造型全部重做，保留塔防逻辑依赖的节点名：
#   Head, MuzzleL, MuzzleR, MuzzleRing, SpinRing, EnergyCore, Leg0..3
# ------------------------------------------------------------

const VF = preload("res://scripts/voxel_factory.gd")
const C = preload("res://scripts/detour_config.gd")

# 参考图配色
const IVORY := Color(0.82, 0.79, 0.70)
const STONE := Color(0.53, 0.51, 0.46)
const DARK := Color(0.16, 0.17, 0.18)
const METAL := Color(0.37, 0.39, 0.41)
const STL := Color(0.55, 0.57, 0.58)
const RUST := Color(0.66, 0.29, 0.12)
const ORANGE := Color(0.96, 0.48, 0.10)
const YELLOW := Color(0.98, 0.74, 0.14)
const CYAN := Color(0.17, 0.86, 0.96)
const CDARK := Color(0.05, 0.34, 0.44)
const RED := Color(0.90, 0.16, 0.12)

# 视觉等比放大：只作用于模型的直接子节点，不动根节点 scale
# （逻辑层 upgrade() 会覆盖 model.scale，故放大必须下沉一层）
static func _inflate(root: Node3D, factor: float) -> void:
	for child in root.get_children():
		if child is Node3D:
			var n := child as Node3D
			n.scale *= factor
			n.position *= factor

# ============================================================
#  T1 机枪塔 — 双枪管 / 橙黄装甲 / 青蓝传感器
# ============================================================
static func build_minigun() -> Node3D:
	var root := Node3D.new()
	root.name = "MinigunTower"
	# 八角基座 + 边缘环
	VF.pcyl(root, "Plinth", 0.47, 0.10, Vector3(0, 0.05, 0), "darkmetal", Color.WHITE, 0.0, 8)
	VF.pcyl(root, "PlinthRim", 0.40, 0.06, Vector3(0, 0.13, 0), "metal", STL, 0.0, 8)
	# 四条斜撑 + 液压杆
	var legs := [Vector3(-0.30, 0, -0.30), Vector3(0.30, 0, -0.30), Vector3(-0.30, 0, 0.30), Vector3(0.30, 0, 0.30)]
	for i in range(4):
		var p: Vector3 = legs[i]
		var leg := VF.pbox(root, "Leg%d" % i, Vector3(0.11, 0.40, 0.11), Vector3(p.x, 0.34, p.z), "darkmetal")
		leg.rotation.z = 0.30 if p.x < 0.0 else -0.30
		leg.rotation.x = -0.22 if p.z < 0.0 else 0.22
		VF.pbox(root, "Foot%d" % i, Vector3(0.18, 0.06, 0.18), Vector3(p.x * 1.18, 0.04, p.z * 1.18), "metal")
	# 机身：橙黄装甲 + 深色机械芯
	VF.pbox(root, "Core", Vector3(0.52, 0.34, 0.46), Vector3(0, 0.56, 0), "metal", METAL)
	VF.pbox(root, "ArmorFront", Vector3(0.50, 0.26, 0.10), Vector3(0, 0.58, -0.25), "paint", ORANGE)
	VF.pbox(root, "ArmorTop", Vector3(0.44, 0.08, 0.38), Vector3(0, 0.76, 0), "paint", YELLOW)
	VF.pbox(root, "ArmorSideL", Vector3(0.08, 0.24, 0.34), Vector3(-0.30, 0.56, 0), "paint", RUST)
	VF.pbox(root, "ArmorSideR", Vector3(0.08, 0.24, 0.34), Vector3(0.30, 0.56, 0), "paint", RUST)
	# 侧面弹药箱 + 弹链
	VF.pbox(root, "AmmoBox", Vector3(0.18, 0.22, 0.26), Vector3(0.34, 0.60, 0.18), "metal", DARK)
	for i in range(3):
		VF.pbox(root, "AmmoL%d" % i, Vector3(0.09, 0.05, 0.09), Vector3(0.36, 0.66 - i * 0.07, 0.06), "plain", YELLOW, 0.3)
	# 旋转头
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.84, 0)
	root.add_child(head)
	VF.pcyl(head, "TurretRing", 0.26, 0.10, Vector3(0, 0, 0), "darkmetal", Color.WHITE, 0.0, 8)
	VF.pbox(head, "TurretBody", Vector3(0.42, 0.20, 0.36), Vector3(0, 0.08, -0.02), "paint", ORANGE)
	VF.pbox(head, "TurretRoof", Vector3(0.34, 0.06, 0.30), Vector3(0, 0.21, -0.02), "paint", YELLOW)
	# 双枪管（水平圆柱）+ 散热环
	for side in [-1.0, 1.0]:
		var sx: float = 0.13 * float(side)
		var barrel := VF.pcyl(head, "Barrel%s" % ("L" if side < 0 else "R"), 0.055, 0.62,
			Vector3(sx, 0.09, -0.43), "darkmetal", Color.WHITE, 0.0, 8)
		barrel.rotation.x = PI * 0.5
		for k in range(3):
			var ring := VF.pcyl(head, "Coolant", 0.075, 0.035, Vector3(sx, 0.09, -0.28 - k * 0.15), "metal", STL, 0.0, 8)
			ring.rotation.x = PI * 0.5
		var muzzle := VF.pcyl(head, "Muzzle%s" % ("L" if side < 0 else "R"), 0.085, 0.10,
			Vector3(sx, 0.09, -0.78), "paint", RUST, 0.0, 8)
		muzzle.rotation.x = PI * 0.5
	# 青蓝传感器 + 天线
	VF.pbox(head, "Sensor", Vector3(0.13, 0.09, 0.09), Vector3(0, 0.14, -0.20), "glass", CYAN, 2.6)
	VF.pbox(head, "Antenna", Vector3(0.035, 0.26, 0.035), Vector3(0.14, 0.32, 0.08), "metal", STL)
	# V0.3 精修：旋转底座齿圈 + 装甲铆钉 + 枪管护罩
	VF.pcyl(root, "BaseGear", 0.52, 0.05, Vector3(0, 0.17, 0), "darkmetal", Color.WHITE, 0.0, 12)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		VF.pbox(root, "GearTooth", Vector3(0.08, 0.06, 0.10),
			Vector3(cos(a) * 0.52, 0.17, sin(a) * 0.52), "metal", STL).rotation.y = -a
	for i in range(4):
		var a2 := TAU * float(i) / 4.0 + PI * 0.25
		VF.pcyl(head, "Rivet", 0.035, 0.03,
			Vector3(cos(a2) * 0.18, 0.24, sin(a2) * 0.16), "darkmetal", Color.WHITE, 0.0, 6)
	for side in [-1.0, 1.0]:
		var sx: float = 0.13 * float(side)
		VF.pbox(head, "BarrelShroud", Vector3(0.20, 0.14, 0.30),
			Vector3(sx, 0.09, -0.30), "paint", ORANGE)
	_inflate(root, 1.2)  # V0.3：整体放大 20%（不覆盖根节点 scale）
	return root

# ============================================================
#  T2 重炮塔 — 粗炮管 / 机械转台 / 俯仰结构
# ============================================================
static func build_cannon() -> Node3D:
	var root := Node3D.new()
	root.name = "CannonTower"
	VF.pcyl(root, "Plinth", 0.55, 0.12, Vector3(0, 0.06, 0), "darkmetal", Color.WHITE, 0.0, 8)
	VF.pcyl(root, "BaseRing", 0.46, 0.08, Vector3(0, 0.16, 0), "metal", METAL, 0.0, 10)
	# 粗腿 + 液压
	var legs := [Vector3(-0.36, 0, -0.36), Vector3(0.36, 0, -0.36), Vector3(-0.36, 0, 0.36), Vector3(0.36, 0, 0.36)]
	for i in range(4):
		var p: Vector3 = legs[i]
		VF.pbox(root, "Leg%d" % i, Vector3(0.17, 0.40, 0.17), Vector3(p.x, 0.36, p.z), "darkmetal")
		VF.pbox(root, "Foot%d" % i, Vector3(0.25, 0.08, 0.25), Vector3(p.x * 1.16, 0.05, p.z * 1.16), "metal", METAL)
		VF.pcyl(root, "Piston%d" % i, 0.05, 0.26, Vector3(p.x * 0.82, 0.52, p.z * 0.82), "darkmetal", Color.WHITE, 0.0, 6)
	VF.pcyl(root, "Turntable", 0.40, 0.14, Vector3(0, 0.56, 0), "metal", STL, 0.0, 10)
	VF.pcyl(root, "GearRing", 0.44, 0.05, Vector3(0, 0.64, 0), "darkmetal", Color.WHITE, 0.0, 12)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.70, 0)
	root.add_child(head)
	# 厚重装甲本体：多层叠出倒角感
	VF.pbox(head, "Body", Vector3(0.68, 0.36, 0.58), Vector3(0, 0.04, 0), "paint", RUST)
	VF.pbox(head, "ArmorTop", Vector3(0.58, 0.14, 0.50), Vector3(0, 0.26, -0.02), "paint", ORANGE)
	VF.pbox(head, "ArmorFront", Vector3(0.50, 0.22, 0.10), Vector3(0, 0.06, -0.32), "paint", ORANGE)
	for sx in [-1.0, 1.0]:
		VF.pbox(head, "SidePlate", Vector3(0.10, 0.30, 0.44), Vector3(sx * 0.39, 0.04, 0), "metal", METAL)
		for k in range(2):
			VF.pcyl(head, "Bolt", 0.035, 0.04, Vector3(sx * 0.45, 0.14 - k * 0.18, -0.14 + k * 0.28), "darkmetal", Color.WHITE, 0.0, 6).rotation.z = PI * 0.5
	# 俯仰轴 + 粗炮管
	VF.pcyl(head, "PitchAxle", 0.17, 0.52, Vector3(0, 0.10, -0.20), "darkmetal", Color.WHITE, 0.0, 8).rotation.z = PI * 0.5
	var barrel := VF.pcyl(head, "Barrel", 0.14, 0.94, Vector3(0, 0.12, -0.74), "paint", ORANGE, 0.0, 10)
	barrel.rotation.x = PI * 0.5
	barrel.rotation.z = 0.06
	for k in range(3):
		var band := VF.pcyl(head, "BarrelBand", 0.16, 0.06, Vector3(0, 0.12, -0.48 - k * 0.22), "darkmetal", Color.WHITE, 0.0, 10)
		band.rotation.x = PI * 0.5
	var muzzle := VF.pcyl(head, "MuzzleRing", 0.19, 0.20, Vector3(0, 0.13, -1.22), "darkmetal", Color.WHITE, 0.0, 10)
	muzzle.rotation.x = PI * 0.5
	VF.pcyl(head, "MuzzleInner", 0.11, 0.22, Vector3(0, 0.13, -1.23), "glass", RED, 0.8, 8).rotation.x = PI * 0.5
	# 传感器 + 弹药箱
	VF.pbox(head, "Sensor", Vector3(0.12, 0.10, 0.10), Vector3(0, 0.30, -0.26), "glass", RED, 2.4)
	VF.pbox(head, "AmmoBox", Vector3(0.30, 0.20, 0.30), Vector3(0, 0.10, 0.34), "metal", DARK)
	# V0.3 精修：后坐缓冲筒（炮管两侧）+ 炮口制退器开槽 + 底座齿圈 + 侧履带板
	for sx in [-1.0, 1.0]:
		var recoil := VF.pcyl(head, "Recoil%d" % int(sx), 0.07, 0.42,
			Vector3(sx * 0.22, 0.12, -0.52), "darkmetal", Color.WHITE, 0.0, 8)
		recoil.rotation.x = PI * 0.5
		for k in range(3):
			VF.pbox(head, "MuzzleSlot", Vector3(0.05, 0.06, 0.14),
				Vector3(sx * 0.08, 0.13 + float(k) * 0.06, -1.30), "darkmetal")
	VF.pcyl(root, "BaseGear", 0.62, 0.05, Vector3(0, 0.21, 0), "darkmetal", Color.WHITE, 0.0, 12)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		VF.pbox(root, "GearTooth", Vector3(0.10, 0.06, 0.11),
			Vector3(cos(a) * 0.62, 0.21, sin(a) * 0.62), "metal", METAL).rotation.y = -a
	for sx in [-1.0, 1.0]:
		for k in range(4):
			VF.pbox(root, "TrackPad", Vector3(0.14, 0.08, 0.20),
				Vector3(sx * 0.58, 0.05, -0.30 + float(k) * 0.20), "darkmetal")
	_inflate(root, 1.2)
	return root

# ============================================================
#  T3 电磁塔 — 青蓝核心 / 多层能量环
# ============================================================
static func build_tesla() -> Node3D:
	var root := Node3D.new()
	root.name = "TeslaTower"
	VF.pcyl(root, "Plinth", 0.46, 0.10, Vector3(0, 0.05, 0), "darkmetal", Color.WHITE, 0.0, 8)
	var legs := [Vector3(-0.30, 0, -0.30), Vector3(0.30, 0, -0.30), Vector3(-0.30, 0, 0.30), Vector3(0.30, 0, 0.30)]
	for i in range(4):
		var p: Vector3 = legs[i]
		var leg := VF.pbox(root, "Leg%d" % i, Vector3(0.10, 0.40, 0.10), Vector3(p.x, 0.32, p.z), "darkmetal")
		leg.rotation.z = 0.32 if p.x < 0.0 else -0.32
		VF.pbox(root, "Foot%d" % i, Vector3(0.16, 0.06, 0.16), Vector3(p.x * 1.2, 0.04, p.z * 1.2), "metal")
	VF.pcyl(root, "PillarBase", 0.24, 0.16, Vector3(0, 0.50, 0), "metal", METAL, 0.0, 8)
	VF.pcyl(root, "Pillar", 0.15, 0.44, Vector3(0, 0.76, 0), "darkmetal", Color.WHITE, 0.0, 8)
	# 下部固定环
	_energy_ring(root, "LowerRing", 0.36, 0.02, 0.62, 10, CDARK, 0.9)
	# 旋转能量环（逻辑会转这个节点）
	var spin := Node3D.new()
	spin.name = "SpinRing"
	spin.position.y = 0.92
	root.add_child(spin)
	_energy_ring(spin, "SpinA", 0.40, 0.0, 0.0, 12, CYAN, 1.6)
	_energy_ring(spin, "SpinB", 0.30, 0.16, 0.0, 10, CDARK, 1.2)
	# 中央八面体能量核心（逻辑会转它）
	var core := VF.pocta(root, "EnergyCore", 0.22, 0.36, Vector3(0, 0.92, 0), "glass", CYAN, 3.0)
	core.name = "EnergyCore"
	_energy_ring(root, "UpperRing", 0.26, 0.0, 1.24, 8, CYAN, 1.3)
	VF.pcyl(root, "Cap", 0.10, 0.10, Vector3(0, 1.44, 0), "metal", STL, 0.0, 8)
	VF.pbox(root, "Antenna", Vector3(0.04, 0.22, 0.04), Vector3(0, 1.58, 0), "metal", STL)
	# 侧面能量导管
	for sx in [-1.0, 1.0]:
		VF.pbox(root, "Conduit", Vector3(0.06, 0.30, 0.06), Vector3(sx * 0.22, 0.70, 0), "glass", CYAN, 1.4)
	# V0.3 精修：外层能量环 + 电弧尖刺 + 底部齿圈 + 垂直能量柱
	_energy_ring(root, "OuterRing", 0.52, 0.90, 0.0, 14, CYAN, 1.0)
	_energy_ring(root, "LowerHalo", 0.44, 0.50, 0.0, 12, CDARK, 1.2)
	VF.pcyl(root, "BaseGear", 0.52, 0.05, Vector3(0, 0.19, 0), "darkmetal", Color.WHITE, 0.0, 12)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		VF.pcyl(root, "Spike", 0.03, 0.30,
			Vector3(cos(a) * 0.50, 1.10, sin(a) * 0.50), "glass", CYAN, 2.2, 6)
	for i in range(4):
		var a3 := TAU * float(i) / 4.0
		VF.pbox(root, "EnergyPillar", Vector3(0.05, 0.60, 0.05),
			Vector3(cos(a3) * 0.30, 0.85, sin(a3) * 0.30), "glass", CYAN, 1.6)
	_inflate(root, 1.2)
	return root

static func _energy_ring(parent: Node3D, name: String, radius: float,
		y: float, z_off: float, count: int, tint: Color, emission: float) -> void:
	var g := Node3D.new()
	g.name = name
	g.position = Vector3(0, y, z_off)
	parent.add_child(g)
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var seg := VF.pbox(g, "Seg%d" % i, Vector3(radius * 0.42, 0.045, 0.07),
			Vector3(cos(a) * radius, 0.0, sin(a) * radius), "glass", tint, emission)
		seg.rotation.y = -a

# ============================================================
#  E1 侦察机械虫 — 四足 / 低矮装甲 / 橙色传感器
# ============================================================
static func build_scout() -> Node3D:
	var root := Node3D.new()
	root.name = "ScoutBot"
	# 机身：主壳 + 分层装甲
	VF.pbox(root, "Chassis", Vector3(0.44, 0.18, 0.58), Vector3(0, 0.40, 0), "darkmetal")
	VF.pbox(root, "Shell", Vector3(0.40, 0.10, 0.46), Vector3(0, 0.53, 0.02), "metal", STL)
	VF.pbox(root, "ArmorF", Vector3(0.34, 0.10, 0.16), Vector3(0, 0.50, -0.28), "paint", ORANGE)
	VF.pbox(root, "ArmorB", Vector3(0.30, 0.08, 0.14), Vector3(0, 0.50, 0.30), "rust", RUST)
	# 头 + 双传感器
	VF.pbox(root, "Head", Vector3(0.28, 0.16, 0.22), Vector3(0, 0.44, -0.40), "metal", METAL)
	VF.pbox(root, "SensorL", Vector3(0.07, 0.06, 0.05), Vector3(-0.08, 0.48, -0.52), "glass", RED, 2.4)
	VF.pbox(root, "SensorR", Vector3(0.07, 0.06, 0.05), Vector3(0.08, 0.48, -0.52), "glass", RED, 2.4)
	# 背部散热鳍 + 天线
	for i in range(3):
		VF.pbox(root, "Fin%d" % i, Vector3(0.05, 0.14, 0.20), Vector3(-0.10 + i * 0.10, 0.62, 0.10), "darkmetal")
	VF.pbox(root, "Antenna", Vector3(0.03, 0.20, 0.03), Vector3(0.12, 0.66, 0.16), "metal", STL)
	# V0.3 精修：头部护罩 + 触角 + 侧面装甲板（提升等距视角辨识度）
	VF.pbox(root, "HeadCrest", Vector3(0.32, 0.06, 0.18), Vector3(0, 0.54, -0.40), "paint", ORANGE)
	for sx in [-1.0, 1.0]:
		VF.pbox(root, "AntennaTip", Vector3(0.03, 0.16, 0.03),
			Vector3(sx * 0.12, 0.56, -0.52), "metal", METAL).rotation.z = sx * 0.5
		VF.pbox(root, "SideArmor", Vector3(0.06, 0.14, 0.30),
			Vector3(sx * 0.24, 0.44, 0.02), "rust", RUST)
		VF.pcyl(root, "SensorGlow", 0.05, 0.03,
			Vector3(sx * 0.085, 0.48, -0.54), "glass", RED, 2.0, 8).rotation.x = PI * 0.5
	# 四足：每足为上节 + 下节 + 脚爪（整组作为 LegN，逻辑改其 y 做动画）
	var legs := [Vector3(-0.30, 0, -0.22), Vector3(0.30, 0, -0.22), Vector3(-0.30, 0, 0.22), Vector3(0.30, 0, 0.22)]
	for i in range(4):
		var p: Vector3 = legs[i]
		var leg := Node3D.new()
		leg.name = "Leg%d" % i
		leg.position = Vector3(p.x, 0.36, p.z)
		root.add_child(leg)
		var upper := VF.pbox(leg, "Upper", Vector3(0.09, 0.26, 0.09), Vector3(0, -0.10, 0), "paint", ORANGE)
		upper.rotation.z = 0.45 if p.x < 0.0 else -0.45
		VF.pbox(leg, "Joint", Vector3(0.13, 0.10, 0.13), Vector3(0, -0.24, 0), "darkmetal")
		var lower := VF.pbox(leg, "Lower", Vector3(0.07, 0.28, 0.07), Vector3(0, -0.38, 0), "metal", METAL)
		lower.rotation.z = -0.25 if p.x < 0.0 else 0.25
		VF.pbox(leg, "Claw", Vector3(0.16, 0.06, 0.18), Vector3(0, -0.53, -0.02), "darkmetal")
	return root

# ============================================================
#  E2 重装机甲 — 大体型 / 厚装甲 / 红色核心
# ============================================================
static func build_mech() -> Node3D:
	var root := Node3D.new()
	root.name = "HeavyMech"
	# 髋部 + 躯干（多层厚装甲）
	VF.pbox(root, "Hip", Vector3(0.72, 0.26, 0.62), Vector3(0, 0.72, 0.06), "darkmetal")
	VF.pbox(root, "Body", Vector3(0.84, 0.50, 0.86), Vector3(0, 1.02, -0.04), "paint", RUST)
	VF.pbox(root, "Chest", Vector3(0.64, 0.30, 0.16), Vector3(0, 1.08, -0.50), "paint", ORANGE)
	VF.pocta(root, "Core", 0.14, 0.16, Vector3(0, 1.08, -0.60), "glass", RED, 3.0)
	VF.pbox(root, "BackPack", Vector3(0.56, 0.40, 0.24), Vector3(0, 1.06, 0.46), "metal", METAL)
	for sx in [-1.0, 1.0]:
		VF.pcyl(root, "Exhaust", 0.08, 0.30, Vector3(sx * 0.20, 1.40, 0.46), "darkmetal", Color.WHITE, 0.0, 8)
	# 头 + 红色目镜
	VF.pbox(root, "Head", Vector3(0.34, 0.26, 0.30), Vector3(0, 1.42, -0.22), "darkmetal")
	VF.pbox(root, "Eye", Vector3(0.22, 0.07, 0.06), Vector3(0, 1.45, -0.39), "glass", RED, 2.8)
	VF.pbox(root, "Crest", Vector3(0.10, 0.12, 0.24), Vector3(0, 1.62, -0.20), "paint", ORANGE)
	# 肩甲 + 机械臂
	for sx in [-1.0, 1.0]:
		VF.pbox(root, "Shoulder", Vector3(0.26, 0.24, 0.50), Vector3(sx * 0.58, 1.18, -0.04), "paint", ORANGE)
		VF.pbox(root, "UpperArm", Vector3(0.18, 0.42, 0.18), Vector3(sx * 0.62, 0.88, -0.06), "metal", METAL)
		VF.pbox(root, "ForeArm", Vector3(0.22, 0.34, 0.24), Vector3(sx * 0.64, 0.56, -0.14), "darkmetal")
		VF.pbox(root, "Vent", Vector3(0.06, 0.20, 0.30), Vector3(sx * 0.44, 1.02, -0.32), "darkmetal")
	# V0.3 精修：胸口核心护框 + 双层肩甲 + 背部散热栅 + 警示条
	for sx in [-1.0, 1.0]:
		VF.pbox(root, "CoreFrame", Vector3(0.05, 0.26, 0.10),
			Vector3(sx * 0.13, 1.08, -0.62), "darkmetal")
		VF.pbox(root, "ShoulderPlate", Vector3(0.32, 0.08, 0.54),
			Vector3(sx * 0.58, 1.34, -0.04), "paint", ORANGE)
		VF.pbox(root, "ShoulderStripe", Vector3(0.34, 0.05, 0.12),
			Vector3(sx * 0.58, 1.40, -0.22), "hazard", Color.WHITE)
	for i in range(4):
		VF.pbox(root, "BackVent", Vector3(0.40, 0.05, 0.06),
			Vector3(0, 0.90 + float(i) * 0.11, 0.60), "darkmetal")
	# 四条粗机械腿 + 履带式脚板（节点名与结构不变，逻辑动画依赖）
	var legs := [Vector3(-0.30, 0, -0.24), Vector3(0.30, 0, -0.24), Vector3(-0.30, 0, 0.28), Vector3(0.30, 0, 0.28)]
	for i in range(4):
		var p: Vector3 = legs[i]
		var leg := Node3D.new()
		leg.name = "Leg%d" % i
		leg.position = Vector3(p.x, 0.58, p.z)
		root.add_child(leg)
		VF.pbox(leg, "Thigh", Vector3(0.20, 0.38, 0.22), Vector3(0, -0.16, 0), "metal", METAL)
		VF.pbox(leg, "Knee", Vector3(0.24, 0.16, 0.24), Vector3(0, -0.38, 0), "darkmetal")
		var shin := VF.pbox(leg, "Shin", Vector3(0.17, 0.36, 0.18), Vector3(0, -0.56, 0), "paint", RUST)
		shin.rotation.z = 0.10 if p.x < 0.0 else -0.10
		VF.pbox(leg, "Foot", Vector3(0.30, 0.10, 0.34), Vector3(0, -0.76, -0.04), "darkmetal")
		for k in range(3):
			VF.pbox(leg, "TrackPad", Vector3(0.32, 0.05, 0.09),
				Vector3(0, -0.82, -0.12 + float(k) * 0.12), "darkmetal", Color.WHITE)
	return root

# ============================================================
#  能源核心 — 地图视觉焦点：多层基座 / 环形装置 / 发光晶体 / 粒子
# ============================================================
static func build_core() -> Node3D:
	var root := Node3D.new()
	root.name = "EnergyCore"
	# 多层八角机械基座
	VF.pcyl(root, "Foundation", 1.28, 0.16, Vector3(0, 0.08, 0), "stone", STONE, 0.0, 8)
	VF.pcyl(root, "Deck", 1.10, 0.12, Vector3(0, 0.22, 0), "darkmetal", Color.WHITE, 0.0, 8)
	VF.pcyl(root, "Inlay", 0.86, 0.06, Vector3(0, 0.30, 0), "glass", CDARK, 1.2, 8)
	VF.pcyl(root, "UpperDeck", 0.72, 0.10, Vector3(0, 0.38, 0), "metal", METAL, 0.0, 8)
	# 8 根支柱 + 顶部灯
	for i in range(8):
		var a := TAU * float(i) / 8.0 + PI * 0.125
		var px := cos(a) * 0.92
		var pz := sin(a) * 0.92
		VF.pbox(root, "Pillar%d" % i, Vector3(0.16, 0.72, 0.16), Vector3(px, 0.72, pz), "darkmetal")
		VF.pbox(root, "PillarCap%d" % i, Vector3(0.22, 0.10, 0.22), Vector3(px, 1.12, pz), "metal", STL)
		VF.pbox(root, "Lamp%d" % i, Vector3(0.10, 0.14, 0.10), Vector3(px, 1.22, pz), "glass", CYAN, 2.6)
	# 机械支撑臂
	for i in range(4):
		var a := TAU * float(i) / 4.0
		var arm := VF.pbox(root, "Brace%d" % i, Vector3(0.12, 0.62, 0.12),
			Vector3(cos(a) * 0.60, 0.86, sin(a) * 0.60), "metal", METAL)
		arm.rotation.z = cos(a) * 0.34
		arm.rotation.x = -sin(a) * 0.34
	# 环绕能量环（两层）
	_core_ring(root, "CoreRingLo", 0.62, 0.84, 14, CDARK, 1.4)
	_core_ring(root, "CoreRingHi", 0.48, 1.34, 12, CYAN, 2.0)
	# 中央发光晶体
	var crystal := VF.pocta(root, "Crystal", 0.36, 0.66, Vector3(0, 1.10, 0), "glass", CYAN, 3.2)
	crystal.name = "Crystal"
	VF.pocta(root, "CrystalInner", 0.18, 0.42, Vector3(0, 1.10, 0), "glass", Color(0.85, 1.0, 1.0), 4.0)
	# 顶部装置
	VF.pcyl(root, "Crown", 0.26, 0.14, Vector3(0, 1.92, 0), "darkmetal", Color.WHITE, 0.0, 8)
	VF.pbox(root, "Beacon", Vector3(0.10, 0.34, 0.10), Vector3(0, 2.14, 0), "glass", CYAN, 3.0)
	# 能量粒子（环绕晶体的发光小块）
	var particles := []
	for i in range(18):
		var a := float(i) * 2.399963
		var rad := 0.52 + float(i % 4) * 0.09
		var yy := 0.70 + float((i * 7) % 12) * 0.11
		particles.append({"size": Vector3(0.055, 0.055, 0.055),
			"pos": Vector3(cos(a) * rad, yy, sin(a) * rad), "color": CYAN})
	VF.batch(root, "EnergyParticles", particles, "glass", 3.4)
	# V0.3 精修：外层防护罩肋架 + 顶部尖塔 + 更多能量粒子 + 生命值反馈挂点
	for i in range(8):
		var a := TAU * float(i) / 8.0 + PI * 0.125
		var px := cos(a) * 1.16
		var pz := sin(a) * 1.16
		var strut := VF.pbox(root, "Shroud%d" % i, Vector3(0.10, 1.10, 0.10),
			Vector3(px, 0.92, pz), "darkmetal")
		strut.rotation.z = cos(a) * 0.14
		strut.rotation.x = -sin(a) * 0.14
		VF.pcyl(root, "ShroudCap%d" % i, 0.10, 0.08,
			Vector3(px, 1.46, pz), "metal", STL, 0.0, 8)
	VF.pcone(root, "Spire", 0.20, 0.50, Vector3(0, 2.30, 0), "glass", CYAN, 2.2, 6)
	# 地面蓝光 + 点光
	var disc := VF.pcyl(root, "GroundGlow", 1.42, 0.02, Vector3(0, 0.035, 0), "glass", CYAN, 1.6, 16)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "CoreLight"
	light.light_color = CYAN
	light.light_energy = 5.0
	light.omni_range = 11.0
	light.position = Vector3(0, 1.2, 0)
	root.add_child(light)
	return root

static func _core_ring(parent: Node3D, name: String, radius: float,
		y: float, count: int, tint: Color, emission: float) -> void:
	var g := Node3D.new()
	g.name = name
	g.position.y = y
	parent.add_child(g)
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var seg := VF.pbox(g, "Seg%d" % i, Vector3(radius * 0.44, 0.06, 0.09),
			Vector3(cos(a) * radius, 0.0, sin(a) * radius), "glass", tint, emission)
		seg.rotation.y = -a
		g.set_meta("ring_group", true)

# ============================================================
#  敌人入口 — 红橙工业传送门
# ============================================================
static func build_gate() -> Node3D:
	var root := Node3D.new()
	root.name = "EnemyGate"
	# 门柱
	for sz in [-1.0, 1.0]:
		VF.pbox(root, "Pillar", Vector3(0.30, 1.60, 0.30), Vector3(0, 0.80, sz * 0.78), "darkmetal")
		VF.pbox(root, "PillarArmor", Vector3(0.36, 1.20, 0.16), Vector3(0.04, 0.86, sz * 0.78), "paint", RUST)
		for k in range(3):
			VF.pbox(root, "Alarm", Vector3(0.10, 0.10, 0.10), Vector3(-0.18, 0.55 + k * 0.38, sz * 0.78), "glass", RED, 2.4)
	# 横梁 + 警示牌
	VF.pbox(root, "Lintel", Vector3(0.34, 0.28, 1.90), Vector3(0, 1.72, 0), "metal", METAL)
	VF.pbox(root, "Sign", Vector3(0.10, 0.32, 0.90), Vector3(-0.22, 1.72, 0), "hazard", Color.WHITE)
	# 能量幕（半透明发光面）
	var veil := VF.pbox(root, "Veil", Vector3(0.02, 1.30, 1.30), Vector3(0.10, 0.78, 0), "glass", RED, 1.8)
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 地面警示光圈 + 箭头
	var glow := VF.pcyl(root, "GroundGlow", 0.82, 0.02, Vector3(0, 0.03, 0), "glass", RED, 1.6, 12)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(3):
		var arrow := VF.pbox(root, "Arrow%d" % i, Vector3(0.06, 0.06, 0.22),
			Vector3(0.36, 0.10, -0.30 + float(i) * 0.30), "glass", RED, 2.2)
		arrow.rotation.x = PI * 0.5
	var light := OmniLight3D.new()
	light.name = "GateLight"
	light.light_color = RED
	light.light_energy = 4.0
	light.omni_range = 7.0
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)
	return root

# ============================================================
#  建造平台 — 金属基座 + 青蓝标记
# ============================================================
static func build_pad() -> Node3D:
	var root := Node3D.new()
	root.name = "BuildPad"
	VF.pcyl(root, "PadBase", 0.56, 0.10, Vector3(0, 0.05, 0), "darkmetal", Color.WHITE, 0.0, 8)
	VF.pcyl(root, "PadTop", 0.48, 0.06, Vector3(0, 0.13, 0), "metal", METAL, 0.0, 8)
	VF.pcyl(root, "PadInlay", 0.36, 0.02, Vector3(0, 0.17, 0), "glass", CDARK, 0.9, 8)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		VF.pbox(root, "Mark%d" % i, Vector3(0.10, 0.02, 0.045),
			Vector3(cos(a) * 0.44, 0.17, sin(a) * 0.44), "glass", CYAN, 1.4).rotation.y = -a
	return root

# ============================================================
#  可破坏废墟 — 破碎砖石 + 铁梁
# ============================================================
static func build_rubble() -> Node3D:
	var root := Node3D.new()
	root.name = "Rubble"
	VF.pbox(root, "Slab1", Vector3(0.78, 0.32, 0.62), Vector3(0, 0.16, 0), "brick", STONE)
	VF.pbox(root, "Slab2", Vector3(0.48, 0.46, 0.42), Vector3(0.22, 0.24, -0.22), "stone", STL)
	var beam := VF.pbox(root, "Beam", Vector3(0.66, 0.08, 0.10), Vector3(-0.12, 0.44, 0.14), "rust", RUST)
	beam.rotation.y = 0.5
	beam.rotation.z = 0.2
	VF.pbox(root, "Chunk1", Vector3(0.26, 0.20, 0.24), Vector3(-0.44, 0.10, 0.36), "stone", STONE)
	VF.pbox(root, "Chunk2", Vector3(0.20, 0.16, 0.20), Vector3(0.42, 0.08, 0.38), "darkmetal")
	VF.pbox(root, "Hazard", Vector3(0.50, 0.03, 0.10), Vector3(-0.06, 0.47, 0.10), "hazard", Color.WHITE).rotation.y = 0.5
	# 可拆警示标记：地面上方的发光菱形 + 底座警示圈，作为"可拆除"的常驻标识。
	# 逻辑层通过节点名 Mark 做 hover 高亮（只改缩放/自发光，不改共享材质）。
	var mark := Node3D.new()
	mark.name = "Mark"
	root.add_child(mark)
	var gem := VF.pocta(mark, "Gem", 0.13, 0.19, Vector3(0, 0.80, 0), "plain", ORANGE, 1.8)
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := VF.pcyl(mark, "Ring", 0.44, 0.025, Vector3(0, 0.035, 0), "hazard", Color.WHITE, 0.35, 12)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
