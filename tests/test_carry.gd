extends TestCase
## Servers carry finished batches from the stoves to the closest free counter
## (each 1x1 counter holds one dish) and serve customers from the counters.
## Data from TestFixtures with 2 counters (first free spots: (4, 0) and (5, 0)),
## carrying 3 s and delivering 4 s at speed 1; the starter is the only server.


func _data(overrides := {}) -> GameData:
	var settings := {"start_counters": 2, "carry_seconds": 3}
	settings.merge(overrides, true)
	return TestFixtures.data(settings)


func _counters(state: GameState) -> Array:
	return state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "counter")


func test_batch_waits_on_the_stove_then_is_carried_and_served() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	GameLoop.start_cooking(state, 0, "tea", data)
	GameLoop.advance(state, 10, data)
	assert_eq(state.stoves[0].ready, 3, "the batch waits on the stove")
	assert_eq(state.counter.get("tea", 0), 0, "nothing on the counters yet")
	assert_true(state.synths[0].is_carrying(), "the server picked it up")
	assert_eq(GameLoop.start_cooking(state, 0, "tea", data), GameLoop.STOVE_BUSY, "the stove is blocked until it's carried")
	GameLoop.advance(state, 3, data)
	assert_eq(state.stoves[0].ready, 0, "carried away")
	assert_true(state.stoves[0].is_idle(), "the stove is free again")
	var counter: PlacedPiece = _counters(state)[0]
	assert_eq(state.counter_dish[counter.uid], "tea", "on the nearest counter")
	assert_eq(state.counter_count[counter.uid], 3, "all three servings")
	# Delivery 4 s, then eating 5 s.
	var events := GameLoop.advance(state, 10, data)
	assert_eq(events.served.size(), 1, "the waiting customer was served from the counter")
	assert_eq(state.counter_count[counter.uid], 2, "one serving taken")


func test_one_dish_per_counter_and_a_full_kitchen_blocks_the_stove() -> void:
	var data := _data({"arrival_min_seconds": 1000, "arrival_max_seconds": 1000, "first_arrival_seconds": 1000})
	var state := GameState.new_game(1, data)
	state.synths[0].battery = 100.0
	var counters := _counters(state)
	Counters.put(state, counters[0].uid, "tea", 2)
	Counters.put(state, counters[1].uid, "jelly", 1)
	GameLoop.start_cooking(state, 0, "tea", data)
	GameLoop.advance(state, 14, data)
	assert_eq(state.counter_count[counters[0].uid], 5, "tea stacks on the tea counter")
	# No free counter for a third dish: an alien unlocks jelly; clear the jelly counter's rival first.
	state.add_synth("alien", "", data).role = Synth.REST
	Counters.take_nearest(state, counters[1].uid, data)
	assert_eq(Counters.dish_on(state, counters[1].uid), "", "the jelly counter is empty again")
	Counters.put(state, counters[1].uid, "tea", 1)
	GameLoop.start_cooking(state, 0, "jelly", data)
	GameLoop.advance(state, 20, data)
	assert_eq(state.stoves[0].ready, 1, "no free counter: the jelly stays on the stove")
	assert_eq(GameLoop.start_cooking(state, 0, "tea", data), GameLoop.STOVE_BUSY, "and the stove can't cook again")


func test_a_counter_with_dishes_stays() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	var counters := _counters(state)
	Counters.put(state, counters[0].uid, "tea", 1)
	assert_eq(GameLoop.pick_up_piece(state, counters[0].uid, data), GameLoop.COUNTER_BUSY, "dishes on it")
	assert_eq(GameLoop.pick_up_piece(state, counters[1].uid, data), GameLoop.OK, "the empty one can go")


func test_carrying_survives_saving() -> void:
	var data := _data()
	var path := "user://test_saves/carry.json"
	var state := GameState.new_game(1, data)
	GameLoop.start_cooking(state, 0, "tea", data)
	GameLoop.advance(state, 11, data)
	assert_true(state.synths[0].is_carrying(), "setup: carrying")
	SaveSystem.save(state, path)
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(SaveSystem.to_dict(loaded), SaveSystem.to_dict(state), "same state")
		GameLoop.advance(loaded, 3, data)
		assert_eq(loaded.stoves[0].ready, 0, "the trip finished after loading")
		var on_the_way := 1 if loaded.synths[0].is_delivering() else 0
		assert_eq(loaded.counter.get("tea", 0) + on_the_way, 3, "all 3 servings reached the counter (one already on its way to the customer)")


func test_version_7_pool_is_spread_onto_counters() -> void:
	var data := _data()
	var path := "user://test_saves/pool.json"
	var raw := SaveSystem.to_dict(GameState.new_game(1, data))
	raw["counter"] = {"tea": 4, "jelly": 2}
	raw.erase("counter_dish")
	raw.erase("counter_count")
	raw["version"] = 7
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.counter, {"tea": 4, "jelly": 2} as Dictionary[String, int], "both dishes kept")
		assert_eq(loaded.counter_dish.values().size(), 2, "one counter each")


func test_a_trip_takes_as_long_as_the_walk() -> void:
	# Walking 1 tile a second: from the kitchen (2 tiles) to the stove, then on
	# to the counter (the gap between them + 1 tile), plus 3 s handling.
	var data := _data({"walk_tiles_per_second": 1.0, "arrival_min_seconds": 1000, "arrival_max_seconds": 1000,
		"first_arrival_seconds": 1000})
	var state := GameState.new_game(1, data)
	state.synths[0].battery = 100.0
	GameLoop.start_cooking(state, 0, "tea", data)
	GameLoop.advance(state, 10, data)
	var server := state.synths[0]
	assert_true(server.is_carrying(), "setup: carrying")
	var stove := Layout.placed_by_uid(state, server.task_stove_uid)
	var counter := Layout.placed_by_uid(state, server.task_counter_uid)
	var walked := 2.0 + Layout.distance(stove, counter, data) + 1.0
	assert_true(walked >= 4.0, "setup: a real walk (%d tiles)" % walked)
	assert_eq(server.task_total, walked + 3.0, "tiles walked + 3 s")
	GameLoop.advance(state, roundi(server.task_total), data)
	assert_eq(server.spot_uid, _counters(state)[0].uid, "stands at the counter after")


func test_a_counter_holds_at_most_999() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	var counters := _counters(state)
	Counters.put(state, counters[0].uid, "tea", 998)
	assert_eq(Counters.free_counter(state, "tea", "", data), counters[1].uid, "a batch of 3 won't fit: the next counter")
	Counters.put(state, counters[1].uid, "tea", 997)
	assert_eq(Counters.free_counter(state, "tea", "", data), "", "both full")


func test_a_chef_carries_its_batch_and_walks_back() -> void:
	# A normal stove (it cooks only with its Chef); walking 1 tile a second.
	var data := _data({"walk_tiles_per_second": 1.0, "arrival_min_seconds": 1000, "arrival_max_seconds": 1000,
		"first_arrival_seconds": 1000})
	var state := GameState.new_game(1, data)
	var stove_piece: PlacedPiece = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "stove")[0]
	stove_piece.piece_id = "chef_stove"
	state.synths[0].role = Synth.REST  # the Server stays out of it
	var chef := state.add_synth("chef", "", data)
	chef.battery = 100.0
	GameLoop.assign_to(state, chef.id, stove_piece.uid, data)
	var index := state.stoves.find(Layout.stove_of(state, stove_piece.uid))
	GameLoop.start_cooking(state, index, "tea", data)
	for second: int in 30:
		GameLoop.advance(state, 1, data)
		if chef.is_carrying():
			break
	assert_true(chef.is_carrying(), "the Chef picked up its batch")
	var counter := chef.task_counter_uid
	while chef.is_carrying():
		GameLoop.advance(state, 1, data)
	assert_eq(state.counter_count.get(counter, 0), 3, "put on the counter")
	assert_true(chef.is_returning(), "then walks back")
	GameLoop.start_cooking(state, index, "tea", data)
	var left := state.stoves[index].remaining
	GameLoop.advance(state, 1, data)
	assert_eq(state.stoves[index].remaining, left, "the stove waits while the Chef is away")
	while chef.is_returning():
		GameLoop.advance(state, 1, data)
	GameLoop.advance(state, 1, data)
	assert_true(state.stoves[index].remaining < left, "back at the stove: cooking again")
