extends Node3D
class_name DetourWorld

# ------------------------------------------------------------
# 地图视觉层：只负责场景搭建，不含游戏逻辑。
# 保留逻辑层依赖的全部接口：build_pads / rubble_nodes / core_node /
# entry_node / main_camera / world_root，以及 slot_index、rubble_index 元数据。
# ------------------------------------------------------------

const VF = preload("res://scripts/voxel_factory.gd")
const M = preload("res://scripts/detour_materials.gd")
const C = preload("res://scripts/detour_config.gd")
const DM = preload("res://scripts/detour_models.gd")
const DP = preload("res://scripts/detour_props.gd")

var path_manager: PathManager
var build_pads: Array[Node3D] = []
var rubble_nodes: Array[Node3D] = []
var core_node: Node3D
var entry_node: Node3D
var main_camera: Camera3D
var world_root: Node3D

var _t := 0.0
var _core_ring_lo: Node3D
var _core_ring_hi: Node3D
var _core_crystal: MeshInstance3D
var _gate_veil: MeshInstance3D
var _core_light: OmniLight3D
var _core_glow: MeshInstance3D
var _core_health_ratio := 1.0

func build(manager: PathManager) -> void:
	path_manager = manager
	world_root = Node3D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)
	_build_ground()
	_build_roads()
	_build_border()
	_build_pads()
	_build_rubble()
	_build_core_and_gate()
	_build_decor()
	_build_lighting()

func _process(delta: float) -> void:
	_t += delta
	if _core_ring_lo:
		_core_ring_lo.rotation.y = _t * 0.32
	if _core_ring_hi:
		_core_ring_hi.rotation.y = -_t * 0.48
	if _core_crystal:
		_core_crystal.rotation.y = _t * 0.22
		var pulse := 1.0 + sin(_t * (2.0 + (1.0 - _core_health_ratio) * 6.0)) * (0.04 + (1.0 - _core_health_ratio) * 0.10)
		_core_crystal.scale = Vector3.ONE * pulse
		_core_crystal.position.y = 1.10 + sin(_t * 1.6) * 0.05
	# 生命值反馈：血量越低，光越暗且闪烁越急，并偏红
	if _core_light:
		var warning := 1.0 - _core_health_ratio
		var flicker := 1.0 - warning * 0.45 * (0.5 + 0.5 * sin(_t * 9.0))
		_core_light.light_energy = (2.5 + _core_health_ratio * 2.5) * flicker
		_core_light.light_color = Color(1.0 - warning * 0.55, 0.55 + _core_health_ratio * 0.31, 0.35 + _core_health_ratio * 0.61)
	if _gate_veil:
		_gate_veil.scale.x = 0.02 * (1.0 + sin(_t * 4.0) * 0.35)

func set_core_health_ratio(ratio: float) -> void:
	_core_health_ratio = clampf(ratio, 0.0, 1.0)

# ------------------------------------------------------------
static func _height_at(gx: int, gy: int) -> float:
	var outer := gx <= 0 or gy <= 0 or gx >= C.GRID_W - 1 or gy >= C.GRID_H - 1
	if outer:
		return 0.22
	return sin(float(gx) * 0.9 + float(gy) * 0.4) * 0.05 + cos(float(gy) * 1.1 - float(gx) * 0.5) * 0.04

static func _hash(a: int, b: int) -> float:
	var v := sin(float(a) * 127.1 + float(b) * 311.7) * 43758.5453
	return v - floor(v)

static func _cell_on_path(gx: int, gy: int) -> bool:
	for c in C.PATH_CELLS:
		if c.x == gx and c.y == gy:
			return true
	return false

static func _cell_near_path(gx: int, gy: int, radius: int = 1) -> bool:
	for c in C.PATH_CELLS:
		if absi(c.x - gx) <= radius and absi(c.y - gy) <= radius:
			return true
	return false

static func _cell_is_build(gx: int, gy: int) -> bool:
	for c in C.BUILD_CELLS:
		if c.x == gx and c.y == gy:
			return true
	return false

static func _cell_is_rubble(gx: int, gy: int) -> bool:
	for c in C.RUBBLE_CELLS:
		if c.x == gx and c.y == gy:
			return true
	return false

# ------------------------------------------------------------
func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	world_root.add_child(ground)
	# 地基（整块深色岩盘）
	VF.pbox(ground, "Bedrock", Vector3(C.GRID_W + 0.8, 0.44, C.GRID_H + 0.8),
		Vector3(0, -0.40, 0), "stone", Color(0.17, 0.16, 0.15))

	# 石质工业地砖：深灰 / 灰褐为主，浅绿仅作极小点缀
	var tiles := []
	var pebbles := []
	var leaves := []
	var cracks := []
	var grass := []
	for gx in range(C.GRID_W):
		for gy in range(C.GRID_H):
			var h := _height_at(gx, gy)
			var r := _hash(gx, gy)
			# 深灰褐基调，随机在深灰与灰褐之间摆动
			var base := Color(0.37, 0.35, 0.32)
			if r > 0.62:
				base = Color(0.43, 0.40, 0.35)   # 灰褐
			elif r < 0.28:
				base = Color(0.30, 0.30, 0.30)   # 深灰
			if _cell_near_path(gx, gy, 1):
				base = Color(0.40, 0.39, 0.36)   # 路旁略浅的石板
			# 浅绿苔藓只保留极少，且压暗成橄榄褐
			if not _cell_near_path(gx, gy, 1) and r > 0.90 and not _cell_is_build(gx, gy):
				base = Color(0.34, 0.36, 0.24)
			base *= 0.90 + r * 0.18
			var th := 0.34 + h
			var wp := C.grid_to_world(gx, gy, -th * 0.5)
			tiles.append({"size": Vector3(0.97, th, 0.97), "pos": wp, "color": base})

			if _cell_is_build(gx, gy) or _cell_is_rubble(gx, gy):
				continue
			# 碎石（密度提高）
			for k in range(4):
				var r2 := _hash(gx * 7 + k, gy * 13 + k)
				if r2 > 0.48:
					continue
				var ox := (_hash(gx + k, gy) - 0.5) * 0.78
				var oz := (_hash(gx, gy + k) - 0.5) * 0.78
				var sz := 0.06 + r2 * 0.18
				pebbles.append({"size": Vector3(sz, sz * 0.6, sz * 0.8),
					"pos": wp + Vector3(ox, th * 0.5 + sz * 0.3, oz),
					"color": Color(0.42, 0.40, 0.36) if k != 1 else Color(0.55, 0.50, 0.42),
					"rot": Vector3(0, r2 * 6.0, 0)})
			# 落叶（提高密度）
			if _hash(gx + 31, gy + 17) > 0.68:
				var lx := (_hash(gx, gy + 3) - 0.5) * 0.7
				var lz := (_hash(gx + 5, gy) - 0.5) * 0.7
				leaves.append({"size": Vector3(0.11, 0.02, 0.07),
					"pos": wp + Vector3(lx, th * 0.5 + 0.012, lz),
					"color": Color(0.78, 0.36, 0.08) if gx % 3 == 0 else
						(Color(0.90, 0.58, 0.12) if gx % 3 == 1 else Color(0.62, 0.24, 0.08)),
					"rot": Vector3(0, float(gx + gy), 0)})
			# 地面裂缝
			if _hash(gx + 9, gy + 4) > 0.82 and not _cell_near_path(gx, gy, 0):
				cracks.append({"size": Vector3(0.46, 0.012, 0.04),
					"pos": wp + Vector3(0, th * 0.5 + 0.008, 0),
					"color": Color(0.11, 0.10, 0.09), "rot": Vector3(0, float(gx * gy % 8) * 0.4, 0)})
			# 枯草簇（细短、暗黄褐）
			if _hash(gx + 55, gy + 23) > 0.84 and not _cell_near_path(gx, gy, 1):
				for k in range(3):
					var ox := (_hash(gx + k, gy + 9) - 0.5) * 0.4
					var oz := (_hash(gx + 3, gy + k) - 0.5) * 0.4
					grass.append({"size": Vector3(0.025, 0.14 + float(k % 2) * 0.06, 0.025),
						"pos": wp + Vector3(ox, th * 0.5 + 0.07, oz),
						"color": Color(0.52, 0.44, 0.22), "rot": Vector3(0.2 * k, 0, 0.25 * k)})
	# 地砖用 cobble 纹理（砖缝+倒角），使其像石砖而非纯色积木
	VF.batch(ground, "StoneTiles", tiles, "cobble")
	VF.batch(ground, "Pebbles", pebbles, "stone")
	VF.batch(ground, "Leaves", leaves, "foliage")
	VF.batch(ground, "Cracks", cracks, "plain")
	VF.batch(ground, "DryGrass", grass, "foliage")

func _build_roads() -> void:
	var roads := Node3D.new()
	roads.name = "Roads"
	world_root.add_child(roads)
	var pts := path_manager.get_points()
	# 浅灰混凝土（相对深色地面形成对比），比 V0.2 更中性
	var concrete := Color(0.56, 0.55, 0.52)
	var concrete_alt := Color(0.49, 0.48, 0.46)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mid := (a + b) * 0.5
		var d := b - a
		var length := d.length()
		var yaw := -atan2(d.z, d.x)
		# 路基（深色，让拼缝透出）
		var base := VF.pbox(roads, "RoadBase_%d" % i, Vector3(length + C.CELL * 0.4, 0.10, C.ROAD_WIDTH + 0.10),
			Vector3(mid.x, C.ROAD_Y - 0.015, mid.z), "darkmetal")
		base.rotation.y = yaw
		# 分段混凝土板：每 ~1 格一块，块间留缝形成拼接感
		var seg_count := maxi(1, roundi(length / (C.CELL * 0.92)))
		var seg_len := length / float(seg_count)
		for k in range(seg_count):
			var t := (float(k) + 0.5) / float(seg_count) - 0.5
			var px := mid.x + cos(yaw) * t * length
			var pz := mid.z - sin(yaw) * t * length
			var tint := concrete if k % 3 != 0 else concrete_alt
			tint *= 0.94 + _hash(i, k) * 0.12  # 轻微磨损明暗
			var plate := VF.pbox(roads, "Plate_%d_%d" % [i, k],
				Vector3(seg_len - 0.035, 0.055, C.ROAD_WIDTH - 0.06),
				Vector3(px, C.ROAD_Y + 0.035, pz), "concrete", tint)
			plate.rotation.y = yaw
		# 两侧黄黑警示边缘
		for side in [-1.0, 1.0]:
			var strip := VF.pbox(roads, "Hazard_%d_%d" % [i, int(side)],
				Vector3(length * 0.99, 0.03, 0.13),
				Vector3(mid.x + sin(yaw) * (C.ROAD_WIDTH * 0.5 + 0.02) * side,
					C.ROAD_Y + 0.075,
					mid.z + cos(yaw) * (C.ROAD_WIDTH * 0.5 + 0.02) * side), "hazard", Color.WHITE)
			strip.rotation.y = yaw
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# 路缘石块
		for side in [-1.0, 1.0]:
			var curb := VF.pbox(roads, "Curb_%d_%d" % [i, int(side)],
				Vector3(length * 0.98, 0.05, 0.12),
				Vector3(mid.x + sin(yaw) * (C.ROAD_WIDTH * 0.5 + 0.16) * side,
					C.ROAD_Y + 0.02,
					mid.z + cos(yaw) * (C.ROAD_WIDTH * 0.5 + 0.16) * side), "stone", Color(0.50, 0.48, 0.44))
			curb.rotation.y = yaw
		# 方向箭头（沿行进方向，间隔更大避免黄线感）
		var arrows := maxi(1, int(length / 3.2))
		for k in range(arrows):
			var t := (float(k) + 0.5) / float(arrows) - 0.5
			var px := mid.x + cos(yaw) * t * length
			var pz := mid.z - sin(yaw) * t * length
			_road_arrow(roads, Vector3(px, C.ROAD_Y + 0.068, pz), yaw)
	# 转角连续铺装（八角形基底 + 中心板，避免直角缺口）
	for p in pts:
		var j := VF.pcyl(roads, "JunctionBase", C.ROAD_WIDTH * 0.72, 0.10,
			Vector3(p.x, C.ROAD_Y - 0.015, p.z), "darkmetal", Color.WHITE, 0.0, 8)
		j.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		VF.pcyl(roads, "JunctionPlate", C.ROAD_WIDTH * 0.60, 0.055,
			Vector3(p.x, C.ROAD_Y + 0.035, p.z), "concrete", concrete, 0.0, 8)
	# 起点 / 终点标识板
	var first: Vector3 = pts[0]
	var last: Vector3 = pts[pts.size() - 1]
	VF.pcyl(roads, "StartPlate", C.ROAD_WIDTH * 0.62, 0.06,
		Vector3(first.x, C.ROAD_Y + 0.045, first.z), "hazard", Color.WHITE, 0.0, 12)

static func _road_arrow(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g := Node3D.new()
	g.name = "Arrow"
	g.position = pos
	g.rotation.y = yaw
	parent.add_child(g)
	VF.pbox(g, "Shaft", Vector3(0.42, 0.015, 0.07), Vector3(-0.05, 0, 0), "glass", YELLOW_COLOR, 0.7).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wing1 := VF.pbox(g, "Wing1", Vector3(0.22, 0.015, 0.06), Vector3(0.22, 0, 0.12), "glass", YELLOW_COLOR, 0.7)
	wing1.rotation.y = 0.7
	wing1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wing2 := VF.pbox(g, "Wing2", Vector3(0.22, 0.015, 0.06), Vector3(0.22, 0, -0.12), "glass", YELLOW_COLOR, 0.7)
	wing2.rotation.y = -0.7
	wing2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

const YELLOW_COLOR := Color(0.98, 0.78, 0.22)

func _build_border() -> void:
	var walls := Node3D.new()
	walls.name = "BorderWalls"
	world_root.add_child(walls)
	for gx in range(C.GRID_W):
		for gy in range(C.GRID_H):
			var edge := gx == 0 or gy == 0 or gx == C.GRID_W - 1 or gy == C.GRID_H - 1
			if not edge:
				continue
			if gx == 0 and gy == 7:
				continue  # 入口
			if (gx + gy) % 5 == 0:
				continue  # 部分缺口，形成破损感
			var w := DP.build_wall(gx * 3 + gy)
			w.position = C.grid_to_world(gx, gy, 0.24)
			w.rotation.y = float((gx + gy) % 4) * 0.08
			walls.add_child(w)

func _build_pads() -> void:
	var pads := Node3D.new()
	pads.name = "BuildPads"
	world_root.add_child(pads)
	for i in range(C.BUILD_CELLS.size()):
		var cell: Vector2i = C.BUILD_CELLS[i]
		var pad := DM.build_pad()
		pad.position = C.grid_to_world(cell.x, cell.y, 0.24)
		pad.set_meta("slot_index", i)
		pads.add_child(pad)
		build_pads.append(pad)

func _build_rubble() -> void:
	var group := Node3D.new()
	group.name = "RubbleZones"
	world_root.add_child(group)
	for i in range(C.RUBBLE_CELLS.size()):
		var cell: Vector2i = C.RUBBLE_CELLS[i]
		var r := DM.build_rubble()
		r.position = C.grid_to_world(cell.x, cell.y, 0.20)
		r.set_meta("rubble_index", i)
		r.rotation.y = float(i) * 0.6
		group.add_child(r)
		rubble_nodes.append(r)

func _build_core_and_gate() -> void:
	var last: Vector3 = path_manager.get_point(path_manager.point_count() - 1)
	core_node = DM.build_core()
	core_node.position = Vector3(last.x, 0.24, last.z + 0.30)
	world_root.add_child(core_node)
	_core_ring_lo = core_node.get_node_or_null("CoreRingLo")
	_core_ring_hi = core_node.get_node_or_null("CoreRingHi")
	_core_crystal = core_node.get_node_or_null("Crystal") as MeshInstance3D
	_core_light = core_node.get_node_or_null("CoreLight") as OmniLight3D
	_core_glow = core_node.get_node_or_null("GroundGlow") as MeshInstance3D

	var first: Vector3 = path_manager.get_point(0)
	entry_node = DM.build_gate()
	entry_node.position = Vector3(first.x - 0.35, 0.24, first.z)
	world_root.add_child(entry_node)
	_gate_veil = entry_node.get_node_or_null("Veil") as MeshInstance3D

func _build_decor() -> void:
	var decor := Node3D.new()
	decor.name = "Decor"
	world_root.add_child(decor)

	# 两栋不同造型的工业建筑 + 一座小仓库
	var fa := DP.build_facility_a()
	fa.position = C.grid_to_world(2, 1, 0.24)
	decor.add_child(fa)
	var fb := DP.build_facility_b()
	fb.position = C.grid_to_world(16, 1, 0.24)
	decor.add_child(fb)
	var shed := DP.build_facility_b()
	shed.scale = Vector3.ONE * 0.72
	shed.position = C.grid_to_world(3, 12, 0.24)
	shed.rotation.y = PI * 0.5
	decor.add_child(shed)

	# 秋季树木：金黄 / 橙红 / 默认三种混用，控制密度不遮挡路线与建造位
	var trees := [
		[0, 2, 0.92, "gold"], [0, 9, 0.82, "red"], [5, 13, 0.88, "gold"],
		[11, 13, 0.96, "red"], [18, 1, 0.94, "gold"], [19, 10, 0.86, "red"],
		[19, 3, 0.90, "gold"], [8, 0, 0.84, "red"], [12, 0, 0.90, "gold"],
		[1, 6, 0.80, "red"], [17, 6, 0.78, "gold"],
	]
	for i in range(trees.size()):
		var t: Array = trees[i]
		var tree: Node3D
		if t[3] == "gold":
			tree = DP.build_tree_gold(float(t[2]))
		elif t[3] == "red":
			tree = DP.build_tree_red(float(t[2]))
		else:
			tree = DP.build_tree(float(t[2]))
		tree.position = C.grid_to_world(t[0], t[1], 0.24)
		tree.rotation.y = float(i) * 0.9
		decor.add_child(tree)

	# 集装箱
	var containers := [
		[4, 0, Color(0.58, 0.22, 0.14), 0.0],
		[13, 0, Color(0.18, 0.40, 0.48), 0.0],
		[7, 13, Color(0.58, 0.24, 0.14), 0.15],
		[14, 13, Color(0.42, 0.44, 0.26), -0.1],
	]
	for item in containers:
		var box := DP.build_container(item[2])
		box.position = C.grid_to_world(item[0], item[1], 0.24)
		box.rotation.y = float(item[3])
		decor.add_child(box)

	# 管道
	for cell in [Vector2i(11, 1), Vector2i(6, 13), Vector2i(18, 11)]:
		var pipe := DP.build_pipe()
		pipe.position = C.grid_to_world(cell.x, cell.y, 0.24)
		pipe.rotation.y = float(cell.x % 3) * 0.4
		decor.add_child(pipe)

	# 铁丝围栏（顶边，避开集装箱）
	for gx in range(5, 12):
		var fence := DP.build_fence()
		fence.position = C.grid_to_world(gx, 0, 0.24)
		decor.add_child(fence)

	# 废弃机械设备
	for cell in [Vector2i(9, 3), Vector2i(15, 11)]:
		var machine := DP.build_machine()
		machine.position = C.grid_to_world(cell.x, cell.y, 0.24)
		machine.rotation.y = float(cell.x) * 0.5
		decor.add_child(machine)
	# 机械残骸（倾倒机架 + 断齿轮，增加废墟感）
	for i in range(3):
		var wreck := DP.build_wreckage(i)
		wreck.position = C.grid_to_world([7, 11, 16][i], [11, 2, 9][i], 0.24)
		wreck.rotation.y = float(i) * 1.3
		decor.add_child(wreck)

	# 油桶 / 木箱
	var barrels := [Vector2i(4, 2), Vector2i(14, 2), Vector2i(9, 13), Vector2i(17, 12)]
	for c in barrels:
		var b := DP.build_barrel()
		b.position = C.grid_to_world(c.x, c.y, 0.24)
		decor.add_child(b)
	var crates := [Vector2i(5, 2), Vector2i(15, 2), Vector2i(8, 11), Vector2i(17, 4)]
	for c in crates:
		var k := DP.build_crate()
		k.position = C.grid_to_world(c.x, c.y, 0.24)
		k.rotation.y = float(c.x % 4) * 0.3
		decor.add_child(k)

	# 灌木与碎石堆（避开道路与功能格）
	var shrubs := [Vector2i(2, 4), Vector2i(4, 9), Vector2i(9, 5), Vector2i(12, 3),
		Vector2i(14, 9), Vector2i(18, 9), Vector2i(6, 2), Vector2i(10, 6), Vector2i(16, 7)]
	for i in range(shrubs.size()):
		var c: Vector2i = shrubs[i]
		var s := DP.build_shrub(i)
		s.position = C.grid_to_world(c.x, c.y, 0.24)
		decor.add_child(s)
	var rocks := [Vector2i(2, 8), Vector2i(5, 10), Vector2i(12, 12), Vector2i(18, 3),
		Vector2i(10, 4), Vector2i(15, 6), Vector2i(4, 6), Vector2i(17, 8)]
	for i in range(rocks.size()):
		var c: Vector2i = rocks[i]
		var r := DP.build_rocks(i)
		r.position = C.grid_to_world(c.x, c.y, 0.24)
		decor.add_child(r)

func _build_lighting() -> void:
	# 环境：深色背景 + 暖色环境光 + 轻雾 + 柔和辉光
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.038, 0.048)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.56, 0.46)
	e.ambient_light_energy = 0.95
	if "ssao_enabled" in e:
		e.ssao_enabled = true
		e.ssao_intensity = 1.1
		e.ssao_radius = 2.2
	e.glow_enabled = true
	e.glow_intensity = 0.42
	e.glow_bloom = 0.12
	e.glow_hdr_threshold = 1.05
	e.fog_enabled = true
	e.fog_light_color = Color(0.14, 0.13, 0.14)
	e.fog_density = 0.004
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	env.environment = e
	add_child(env)

	# 暖色秋日阳光
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.83, 0.62)
	sun.light_energy = 2.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.035
	sun.rotation_degrees = Vector3(-52, -42, 0)
	add_child(sun)

	# 冷色补光，让青蓝能量更立体
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.42, 0.62, 0.95)
	fill.light_energy = 0.5
	fill.rotation_degrees = Vector3(-30, 138, 0)
	add_child(fill)

	# 正交等距相机：地图占据主要画面
	main_camera = Camera3D.new()
	main_camera.name = "IsoCamera"
	main_camera.projection = 1  # 正交投影 (Perspective=0, Orthogonal=1, Frustum=2)
	main_camera.size = 18.8
	var center := C.grid_to_world((C.GRID_W - 1) * 0.5, (C.GRID_H - 1) * 0.5, 0.6)
	# 视线目标略向屏幕下方偏移，使地图整体在画面中上移，避开底部建造栏
	var look_target := center + Vector3(1.0, 0.0, 1.0)
	main_camera.position = center + Vector3(20.0, 26.0, 20.0)
	add_child(main_camera)
	main_camera.look_at(look_target)
	main_camera.current = true
