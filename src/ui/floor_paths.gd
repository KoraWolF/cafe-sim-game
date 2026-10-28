class_name FloorPaths
extends RefCounted
## Walking routes (cell units) that never cross furniture or décor: the
## shortest path over the empty tiles inside the café (8 directions, no corner
## cutting), through the door to the street, and round the front to the Pod
## bay. Visual only: the game's timing does not depend on it.

## Just inside and just outside the door, and the corner on the way to the Pod bay.
const EDGE: float = 0.3

var _grid := AStarGrid2D.new()
var _key: String = ""
var _width: int = 0
var _rows: int = 0


## Rebuilds the grid when the floor changed.
func update(state: GameState, data: GameData) -> void:
	var key := "%d:" % state.floor_rows
	for placed: PlacedPiece in state.placed:
		key += "%s@%d,%d%s;" % [placed.piece_id, placed.cell.x, placed.cell.y, "r" if placed.rotated else ""]
	if key == _key:
		return
	_key = key
	_width = state.floor_width
	_rows = state.floor_rows
	_grid.region = Rect2i(0, 0, _width, _rows)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for placed: PlacedPiece in state.placed:
		for cell: Vector2i in Layout.cells(placed, data):
			_grid.set_point_solid(cell, true)


## The floor's version (changes whenever a piece moves).
func key() -> String:
	return _key


func inside(at: Vector2) -> bool:
	return at.x >= 0.0 and at.y >= 0.0 and at.x < _width and at.y < _rows


func door_in() -> Vector2:
	return Vector2(_width - EDGE, _rows - 0.5)


func door_out() -> Vector2:
	return Vector2(_width + EDGE, _rows - 0.5)


## Points from `from` to `to` (both included) that avoid every piece.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var at := from
	if inside(from) and inside(to):
		points.append_array(_inside(from, to))
		return points
	if inside(from):
		points.append_array(_inside(from, door_in()))
		points.append(door_out())
		at = door_out()
	if inside(to):
		points.append_array(_outside(at, door_out()))
		points.append(door_in())
		points.append_array(_inside(door_in(), to))
		return points
	points.append_array(_outside(at, to))
	return points


## Outside: round the café's front-right corner when one end is the Pod bay
## (below the floor) and the other the street (right of the door).
func _outside(from: Vector2, to: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var corner := Vector2(_width + 0.5, _rows + 0.6)
	var in_bay := func(p: Vector2) -> bool: return p.y > _rows and p.x < _width + 0.2
	if in_bay.call(from) != in_bay.call(to):
		result.append(corner)
	result.append(to)
	return result


## Inside: A* over the empty tiles (the start and end tiles are allowed even
## if a piece stands there, e.g. a seat), then the exact end point.
func _inside(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _cell(from)
	var end := _cell(to)
	var result := PackedVector2Array()
	var start_solid := _grid.is_point_solid(start)
	var end_solid := _grid.is_point_solid(end)
	_grid.set_point_solid(start, false)
	_grid.set_point_solid(end, false)
	var path := _grid.get_id_path(start, end, true)
	_grid.set_point_solid(start, start_solid)
	_grid.set_point_solid(end, end_solid)
	for i: int in range(1, path.size() - 1):
		result.append(Vector2(path[i]) + Vector2(0.5, 0.5))
	result.append(to)
	return result


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(at.x), 0, _width - 1), clampi(floori(at.y), 0, _rows - 1))


## Total length of a route.
static func length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i: int in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## The point a share (0..1) of the way along a route.
static func point_at(points: PackedVector2Array, share: float) -> Vector2:
	var left := clampf(share, 0.0, 1.0) * length(points)
	for i: int in range(1, points.size()):
		var step := points[i - 1].distance_to(points[i])
		if left <= step:
			return points[i - 1].lerp(points[i], left / step if step > 0.0 else 1.0)
		left -= step
	return points[points.size() - 1]
