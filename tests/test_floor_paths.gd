extends TestCase
## Walking routes never cross furniture or décor, go through the door, and
## round the front to the Pod bay. Fixture floor 8 x 6, stoves on (0..3, 0),
## seats (6, 0), (7, 0), tables (6, 1), (7, 1).


func _paths(state: GameState, data: GameData) -> FloorPaths:
	var paths := FloorPaths.new()
	paths.update(state, data)
	return paths


func _crosses(state: GameState, data: GameData, points: PackedVector2Array, allowed: Array[Vector2i]) -> bool:
	for i: int in range(1, points.size()):
		for step: int in 20:
			var at := points[i - 1].lerp(points[i], step / 20.0)
			var cell := Vector2i(floori(at.x), floori(at.y))
			if allowed.has(cell):
				continue
			if Layout.piece_at(state, cell, data) != null:
				return true
	return false


func test_route_goes_round_a_wall_of_pieces() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	for x: int in 7:
		state.storage["fern"] = 1
		GameLoop.place_piece(state, "fern", Vector2i(x, 3), false, data)
	var paths := _paths(state, data)
	var route := paths.route(Vector2(1.5, 1.5), Vector2(1.5, 5.5))
	assert_true(not _crosses(state, data, route, []), "no piece crossed")
	assert_true(route.has(Vector2(7.5, 3.5)), "through the only gap")
	assert_true(FloorPaths.length(route) > 4.0, "longer than straight through")


func test_route_to_a_seat_ends_on_it_without_crossing_others() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var paths := _paths(state, data)
	var route := paths.route(Vector2(4.5, 4.5), Vector2(6.5, 0.5))
	assert_eq(route[route.size() - 1], Vector2(6.5, 0.5), "ends at the seat")
	assert_true(not _crosses(state, data, route, [Vector2i(6, 0)] as Array[Vector2i]), "only the seat itself")


func test_in_through_the_door_and_out_to_the_pod_bay() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var paths := _paths(state, data)
	var inward := paths.route(Vector2(13, 5.5), Vector2(4.5, 4.5))
	assert_true(inward.has(paths.door_out()) and inward.has(paths.door_in()), "through the door")
	var to_bay := paths.route(Vector2(4.5, 4.5), Vector2(1.0, 7.0))
	assert_true(to_bay.has(paths.door_in()) and to_bay.has(Vector2(8.5, 6.6)), "out the door and round the front")
	assert_eq(FloorPaths.point_at(to_bay, 1.0), Vector2(1.0, 7.0), "ends at the Pod")
	assert_eq(FloorPaths.point_at(to_bay, 0.0), Vector2(4.5, 4.5), "starts where it was")


func test_grid_follows_the_floor() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var paths := _paths(state, data)
	var before := paths.key()
	state.storage["fern"] = 1
	GameLoop.place_piece(state, "fern", Vector2i(4, 4), false, data)
	paths.update(state, data)
	assert_true(paths.key() != before, "rebuilt after a piece moved")
	var route := paths.route(Vector2(3.5, 4.5), Vector2(5.5, 4.5))
	assert_true(not _crosses(state, data, route, []), "goes round the new fern")
