extends TestCase
## Playtest 7: the door stays clear, a Chef stays with its cooking dish, café
## and Pod workers swap places, 3x top speed.
## Data from TestFixtures: floor 8 x 6 (door tile (7, 5)), 2 seats with tables.


func test_nothing_blocks_the_door() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.coins = 1000
	GameLoop.buy_piece(state, "fern", data)
	assert_eq(Layout.door_cell(state), Vector2i(7, 5), "the tile just inside the door")
	assert_eq(GameLoop.place_piece(state, "fern", Vector2i(7, 5), false, data), GameLoop.BLOCKS_DOOR, "refused")
	assert_eq(GameLoop.place_piece(state, "fern", Vector2i(6, 5), false, data), GameLoop.OK, "next to it is fine")


func test_a_chef_stays_with_its_cooking_dish() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var stoves := state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "stove")
	var chef := state.add_synth("chef", "", data)
	GameLoop.assign_to(state, chef.id, stoves[0].uid, data)
	GameLoop.start_cooking(state, state.stoves.find(Layout.stove_of(state, stoves[0].uid)), "tea", data)
	assert_eq(GameLoop.assign_to(state, chef.id, stoves[1].uid, data), GameLoop.CHEF_COOKING, "not to the next stove")
	assert_eq(GameLoop.send_to_rest(state, chef.id), GameLoop.OK, "another job is fine")


func test_a_cafe_worker_and_a_pod_worker_swap() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var stove: PlacedPiece = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "stove")[0]
	var chef := state.add_synth("chef", "", data)
	GameLoop.assign_to(state, chef.id, stove.uid, data)
	var resting := state.add_synth("worker", "", data)
	resting.role = Synth.REST
	assert_eq(GameLoop.swap_jobs(state, chef.id, resting.id), GameLoop.OK, "swapped")
	assert_eq([resting.role, resting.station_uid], [Synth.CHEF, stove.uid], "the rested one takes the stove")
	assert_eq(chef.role, Synth.REST, "the Chef goes to rest")
	var server := state.synths[0]
	assert_eq(GameLoop.swap_jobs(state, server.id, resting.id), GameLoop.NO_JOB_THERE, "two in the café don't swap")


func test_top_speed_is_3x() -> void:
	assert_eq(GameState.SPEEDS, [0, 1, 2, 3] as Array[int], "pause, 1x, 2x, 3x")
