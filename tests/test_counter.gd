extends TestCase
## The counter piece: placed in a new game, the last one stays, older saves get one.


func test_new_game_has_a_counter_next_to_the_stoves() -> void:
	var data := GameData.load_default()
	var state := GameState.new_game(1, data)
	var counters := state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "counter")
	assert_eq(counters.size(), 1, "one counter")
	assert_eq(counters[0].cell, Vector2i(4, 0), "beside the stoves on the back wall")


func test_the_last_counter_cannot_be_removed() -> void:
	var data := TestFixtures.data({"start_counters": 2})
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	var counters := state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "counter")
	assert_eq(GameLoop.pick_up_piece(state, counters[0].uid, data), GameLoop.OK, "a second counter can go")
	assert_eq(GameLoop.pick_up_piece(state, counters[1].uid, data), GameLoop.COUNTER_NEEDED, "the last one stays")


func test_version_5_save_gets_a_counter() -> void:
	var data := TestFixtures.data()
	var path := "user://test_saves/no_counter.json"
	var raw := SaveSystem.to_dict(GameState.new_game(1, data))
	raw["version"] = 5
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(Layout.count_placed(loaded, Piece.COUNTER, data), 1, "a counter was placed")


func test_version_6_pods_move_to_the_pod_bay() -> void:
	var data := TestFixtures.data()
	var path := "user://test_saves/old_pods.json"
	var raw := SaveSystem.to_dict(GameState.new_game(1, data))
	raw.erase("pods")
	raw["placed"].append({"uid": "old_pod_1", "piece_id": "pod", "cell": [0, 4], "rotated": false})
	raw["placed"].append({"uid": "old_pod_2", "piece_id": "pod", "cell": [1, 4], "rotated": false})
	raw["storage"] = {"pod": 1}
	raw["version"] = 6
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.pods, 3, "2 placed + 1 stored Pod, now in the bay")
		assert_true(loaded.placed.all(func(p: PlacedPiece) -> bool: return p.piece_id != "pod"), "off the floor")
		assert_true(loaded.storage.is_empty(), "not in storage")
