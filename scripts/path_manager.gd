extends Node
class_name PathManager

signal path_changed

var world_points: Array[Vector3] = []
var dynamic_blockers: Dictionary = {}
var _cached_length := 0.0

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	world_points.clear()
	for cell in DetourConfig.PATH_CELLS:
		world_points.append(DetourConfig.grid_to_world(cell.x, cell.y, DetourConfig.ROAD_Y + 0.30))
	_cached_length = 0.0
	for i in range(world_points.size() - 1):
		_cached_length += world_points[i].distance_to(world_points[i + 1])
	path_changed.emit()

func get_points() -> Array[Vector3]:
	return world_points.duplicate()

func get_point(index: int) -> Vector3:
	if index < 0 or index >= world_points.size():
		return Vector3.ZERO
	return world_points[index]

func point_count() -> int:
	return world_points.size()

func total_length() -> float:
	return _cached_length

# 归一化进度：越接近 1 越靠近核心（用于炮塔优先索敌）
func progress_at(pos: Vector3, from_index: int) -> float:
	if world_points.is_empty():
		return 0.0
	var travelled := 0.0
	for i in range(min(from_index, world_points.size() - 1)):
		travelled += world_points[i].distance_to(world_points[i + 1])
	if from_index < world_points.size() - 1:
		travelled += world_points[from_index].distance_to(pos)
	return clampf(travelled / maxf(_cached_length, 0.001), 0.0, 1.0)

# ---- 为后续动态改道预留的接口 ----
func set_cell_blocked(cell: Vector2i, blocked: bool) -> void:
	if blocked:
		dynamic_blockers[cell] = true
	else:
		dynamic_blockers.erase(cell)

func compute_dynamic_path(start_cell: Vector2i, goal_cell: Vector2i) -> Array[Vector3]:
	# Reserved for V0.2 terrain deformation / dynamic rerouting.
	var astar := AStarGrid2D.new()
	astar.size = Vector2i(DetourConfig.GRID_W, DetourConfig.GRID_H)
	astar.cell_size = Vector2(DetourConfig.CELL, DetourConfig.CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for cell in dynamic_blockers.keys():
		astar.set_point_solid(cell, true)
	var points := astar.get_id_path(start_cell, goal_cell)
	var result: Array[Vector3] = []
	for p in points:
		result.append(DetourConfig.grid_to_world(p.x, p.y, DetourConfig.ROAD_Y + 0.30))
	return result
