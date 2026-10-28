extends TestCase
## Jobs by place: click a worker, then a stove (Chef there), a counter or table
## (Server), a register (Cashier there) or the Pod bay (Rest). One Chef per
## stove and one Cashier per register; a Chef speeds up only its own stove.
## Fixture: stoves at (0, 0) and (2, 0), seats/tables at (6..7, 0..1).


func _first(state: GameState, piece_id: String) -> PlacedPiece:
	return state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == piece_id)[0]


func test_click_a_place_sets_the_job() -> void:
	var data := TestFixtures.data({"start_registers": 1, "start_counters": 1})
	var state := GameState.new_game(1, data)
	var synth := state.synths[0]
	assert_eq(GameLoop.assign_to(state, synth.id, state.stoves[1].piece_uid, data), GameLoop.OK, "stove")
	assert_eq(synth.role, Synth.CHEF, "Chef")
	assert_eq(synth.station_uid, state.stoves[1].piece_uid, "at that stove")
	assert_eq(GameLoop.assign_to(state, synth.id, _first(state, "register").uid, data), GameLoop.OK, "register")
	assert_eq(synth.role, Synth.CASHIER, "Cashier at that register")
	assert_eq(GameLoop.assign_to(state, synth.id, _first(state, "table").uid, data), GameLoop.OK, "table")
	assert_eq(synth.role, Synth.SERVER, "Server")
	assert_eq(synth.station_uid, "", "no station")
	assert_eq(GameLoop.assign_to(state, synth.id, _first(state, "counter").uid, data), GameLoop.OK, "counter")
	assert_eq(synth.role, Synth.SERVER, "Server too")
	assert_eq(GameLoop.send_to_rest(state, synth.id), GameLoop.OK, "Pod bay")
	assert_eq(synth.role, Synth.REST, "Rest")
	state.storage["fern"] = 1
	GameLoop.place_piece(state, "fern", Vector2i(4, 4), false, data)
	assert_eq(GameLoop.assign_to(state, synth.id, Layout.piece_at(state, Vector2i(4, 4), data).uid, data),
		GameLoop.NO_JOB_THERE, "décor has no job")


func test_one_chef_per_stove() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var a := state.add_synth("chef", "", data)
	var b := state.add_synth("chef", "", data)
	GameLoop.assign_to(state, a.id, state.stoves[0].piece_uid, data)
	GameLoop.assign_to(state, b.id, state.stoves[0].piece_uid, data)
	assert_eq(b.role, Synth.CHEF, "the new Chef takes the stove")
	assert_eq(a.role, Synth.REST, "the old one goes to Rest")


func test_chef_speeds_up_only_its_stove() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.synths[0].role = Synth.REST
	var chef := state.add_synth("chef", "", data)
	GameLoop.assign_to(state, chef.id, state.stoves[0].piece_uid, data)
	GameLoop.start_cooking(state, 0, "tea", data)
	GameLoop.start_cooking(state, 1, "tea", data)
	GameLoop.advance(state, 3, data)
	assert_eq(state.stoves[0].remaining, 4.0, "speed 2 with its Chef")
	assert_eq(state.stoves[1].remaining, 7.0, "base speed 1 without")


func test_busy_worker_keeps_its_job() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 1
	GameLoop.advance(state, 4, data)
	assert_true(state.synths[0].is_delivering(), "setup: carrying a dish")
	assert_eq(GameLoop.assign_to(state, state.synths[0].id, state.stoves[0].piece_uid, data), GameLoop.SYNTH_BUSY, "busy")
	assert_eq(GameLoop.send_to_rest(state, state.synths[0].id), GameLoop.SYNTH_BUSY, "busy")


func test_old_greeter_becomes_server_and_old_chef_gets_a_stove() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var raw := SaveSystem.to_dict(state)
	raw["synths"].append({"id": "synth_90", "species_id": "worker", "role": "greeter", "battery": 50.0, "level": 1, "xp": 0})
	raw["synths"].append({"id": "synth_91", "species_id": "chef", "role": "chef", "battery": 50.0, "level": 1, "xp": 0})
	var loaded := SaveSystem.from_dict(JSON.parse_string(JSON.stringify(raw)))
	Roles.bind_free(loaded, data)
	assert_eq(loaded.synth_by_id("synth_90").role, Synth.SERVER, "Greeter -> Server")
	assert_eq(loaded.synth_by_id("synth_91").station_uid, loaded.stoves[0].piece_uid, "Chef took a free stove")
