extends TestCase
## Throwing food away: the player marks a counter (or a stove's waiting batch)
## and an idle server carries it all to the nearest bin, no refund. Data from
## TestFixtures with 2 counters and a bin, nobody arriving, carrying 3 s at speed 1;
## the starter is the only server.


func _data(overrides := {}) -> GameData:
	var settings := {"start_counters": 2, "start_bins": 1, "carry_seconds": 3, "arrival_min_seconds": 1000,
		"arrival_max_seconds": 1000, "first_arrival_seconds": 1000}
	settings.merge(overrides, true)
	return TestFixtures.data(settings)


func _first(state: GameState, piece_id: String) -> PlacedPiece:
	for placed: PlacedPiece in state.placed:
		if placed.piece_id == piece_id:
			return placed
	return null


func test_server_takes_a_counter_to_the_bin() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	var counter := _first(state, "counter")
	Counters.put(state, counter.uid, "tea", 3)
	var coins := state.coins
	assert_eq(GameLoop.throw_away(state, counter.uid, data), GameLoop.OK, "marked")
	assert_true(state.discard.has(counter.uid), "waiting for a server")
	var events := GameLoop.advance(state, 1, data)
	var server := state.synths[0]
	assert_true(server.is_discarding(), "the server took it")
	assert_eq(server.task_bin_uid, _first(state, "bin").uid, "to the bin")
	assert_eq(events.thrown_away, 3, "all three servings")
	assert_true(not (state.counter_count.has(counter.uid)), "the counter is free at once")
	assert_eq(state.counter.get("tea", 0), 0, "nothing left to serve")
	assert_true(not (state.discard.has(counter.uid)), "no longer marked")
	GameLoop.advance(state, 3, data)
	assert_true(not (server.is_busy()), "back after the trip")
	assert_eq(state.coins, coins, "no refund")


func test_marked_at_night_is_done_next_shift() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	var counter := _first(state, "counter")
	Counters.put(state, counter.uid, "tea", 2)
	state.phase = GameState.Phase.NIGHT
	assert_eq(GameLoop.throw_away(state, counter.uid, data), GameLoop.OK, "can mark at night")
	assert_eq(state.counter_count[counter.uid], 2, "nothing happens at night")
	state.phase = GameState.Phase.SHIFT
	GameLoop.advance(state, 1, data)
	assert_true(not (state.counter_count.has(counter.uid)), "thrown away first thing in the shift")


func test_stove_batch_can_be_thrown_away() -> void:
	var data := _data({"start_counters": 1})
	var state := GameState.new_game(1, data)
	var counter := _first(state, "counter")
	Counters.put(state, counter.uid, "jelly", 1)
	state.stoves[0].recipe_id = "tea"
	state.stoves[0].ready = 3
	assert_eq(GameLoop.throw_away(state, state.stoves[0].piece_uid, data), GameLoop.OK, "marked")
	GameLoop.advance(state, 1, data)
	assert_eq(state.stoves[0].ready, 0, "batch gone")
	assert_true(state.stoves[0].is_idle(), "the stove can cook again")


func test_throw_away_errors() -> void:
	var data := _data({"start_bins": 0})
	var state := GameState.new_game(1, data)
	var counter := _first(state, "counter")
	assert_eq(GameLoop.throw_away(state, "nope", data), GameLoop.UNKNOWN_PLACED, "unknown piece")
	assert_eq(GameLoop.throw_away(state, counter.uid, data), GameLoop.NOTHING_TO_THROW, "empty counter")
	assert_eq(GameLoop.throw_away(state, state.stoves[0].piece_uid, data), GameLoop.NOTHING_TO_THROW, "idle stove")
	Counters.put(state, counter.uid, "tea", 1)
	assert_eq(GameLoop.throw_away(state, counter.uid, data), GameLoop.NO_BIN, "needs a bin")
	state.stoves[0].recipe_id = "tea"
	state.stoves[0].ready = 3
	state.stoves[0].carrier = state.synths[0].id
	assert_eq(GameLoop.throw_away(state, state.stoves[0].piece_uid, data), GameLoop.BATCH_ON_THE_WAY, "being carried")
	assert_true(state.discard.is_empty(), "nothing marked")


func test_bin_is_bought_and_starter_cafe_has_one() -> void:
	var real := GameData.load_default()
	var state := GameState.new_game(1, real)
	assert_eq(Layout.count_placed(state, Piece.BIN, real), 1, "starter bin")
	var data := _data({"start_bins": 0})
	state = GameState.new_game(1, data)
	state.phase = GameState.Phase.NIGHT
	assert_eq(GameLoop.buy_piece(state, "bin", data), GameLoop.OK, "bought")
	assert_eq(state.storage.get("bin", 0), 1, "in storage to place")


func test_marks_survive_save_and_removal_clears_them() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	var counter := _first(state, "counter")
	Counters.put(state, counter.uid, "tea", 2)
	state.phase = GameState.Phase.NIGHT
	GameLoop.throw_away(state, counter.uid, data)
	var loaded := SaveSystem.from_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_dict(state))))
	assert_true(loaded.discard.has(counter.uid), "saved")
	assert_true(SaveSystem.validate(loaded, data).is_empty(), "valid after loading")
	state.counter_count.erase(counter.uid)
	state.counter_dish.erase(counter.uid)
	state.counter.clear()
	assert_eq(GameLoop.pick_up_piece(state, counter.uid, data), GameLoop.OK, "picked up")
	assert_true(state.discard.is_empty(), "mark cleared with the piece")


func test_version_8_cafe_gets_a_bin() -> void:
	var data := GameData.load_default()
	var path := "user://test_saves/no_bin.json"
	var state := GameState.new_game(1, data)
	var bin := _first(state, "bin")
	Layout.pick_up(state, bin.uid, data)
	state.storage.erase("bin")
	var raw := SaveSystem.to_dict(state)
	raw.erase("discard")
	raw.erase("auto_night")
	raw["version"] = 8
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(Layout.count_placed(loaded, Piece.BIN, data), 1, "a bin placed on the floor")
		assert_eq(loaded.synths[0].battery_max, state.synths[0].battery_max, "battery kept")
