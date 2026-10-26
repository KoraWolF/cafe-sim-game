extends TestCase
## Arranging the floor at night: Layout previews and the FloorEditor's hold /
## preview / drop / store / sell flow. Data from TestFixtures (light next to plant +3).


func _night(data: GameData) -> GameState:
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	state.coins = 1000
	return state


func _place(state: GameState, piece_id: String, cell: Vector2i, data: GameData) -> String:
	GameLoop.buy_decor(state, piece_id, data)
	GameLoop.place_piece(state, piece_id, cell, false, data)
	return state.placed[-1].uid


func test_vibe_if_and_neighbours_leave_the_floor_unchanged() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var fern := _place(state, "fern", Vector2i(7, 5), data)
	var count := state.placed.size()
	assert_eq(Layout.vibe_if(state, "lamp", Vector2i(6, 5), false, data), 18.0, "10 + 5 + 3 if a lamp stood beside it")
	assert_eq(Layout.vibe_if(state, "lamp", Vector2i(4, 5), false, data), 15.0, "no bonus apart")
	assert_eq(Layout.matching_neighbours(state, "lamp", Vector2i(6, 5), false, data), [fern] as Array[String], "the fern")
	assert_eq(state.placed.size(), count, "trial piece removed")
	assert_eq(Layout.vibe_if(state, "fern", Vector2i(0, 5), false, data, fern), 10.0, "moving the fern alone")
	assert_eq(Layout.placed_by_uid(state, fern).cell, Vector2i(7, 5), "moved back after the trial")
	assert_eq(Layout.piece_at(state, Vector2i(7, 5), data).uid, fern, "piece under a tile")


func test_hold_from_storage_preview_and_drop() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	_place(state, "fern", Vector2i(7, 5), data)
	var editor := FloorEditor.new()
	assert_eq(editor.hold_stored(state, "lamp"), GameLoop.NONE_STORED, "nothing stored")
	GameLoop.buy_decor(state, "lamp", data)
	GameLoop.buy_decor(state, "lamp", data)
	assert_eq(editor.hold_stored(state, "lamp"), GameLoop.OK, "holding a lamp")
	var bad := editor.preview(state, Vector2i(7, 5), data)
	assert_eq(bad["error"], GameLoop.OVERLAP, "on the fern")
	var good := editor.preview(state, Vector2i(6, 5), data)
	assert_eq(good["error"], GameLoop.OK, "free")
	assert_eq(good["delta"], 8.0, "+5 lamp +3 next to the fern")
	assert_eq(editor.drop(state, Vector2i(6, 5), data), GameLoop.OK, "placed")
	assert_true(editor.is_holding(), "still holding: a second lamp is stored")
	assert_eq(editor.drop(state, Vector2i(5, 5), data), GameLoop.OK, "placed the second")
	assert_true(not editor.is_holding(), "hands empty")
	assert_eq(state.vibe, 23.0, "10 + 5 + 5 + 3")


func test_move_rotate_store_and_sell() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var editor := FloorEditor.new()
	var pod := state.placed[2].uid
	assert_eq(editor.hold_placed(state, pod), GameLoop.OK, "holding a pod")
	assert_eq(editor.preview(state, Vector2i(6, 5), data)["error"], GameLoop.OUT_OF_BOUNDS, "upright: too deep")
	editor.rotate()
	assert_eq(editor.drop(state, Vector2i(6, 5), data), GameLoop.OK, "rotated into the last row")
	assert_eq(Layout.placed_by_uid(state, pod).rotated, true, "rotated")
	editor.hold_placed(state, pod)
	assert_eq(editor.store(state, data), GameLoop.OK, "2 Pods for 1 Synth: one can go")
	editor.hold_placed(state, state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "pod")[0].uid)
	assert_eq(editor.store(state, data), GameLoop.POD_IN_USE, "the starter needs the last Pod")
	assert_true(editor.is_holding(), "still holding after a refusal")
	editor.cancel()
	var fern := _place(state, "fern", Vector2i(0, 5), data)
	editor.hold_placed(state, fern)
	var coins := state.coins
	assert_eq(editor.sell(state, data), GameLoop.OK, "sold")
	assert_eq(state.coins, coins + 25, "half back")
	assert_true(not editor.is_holding(), "hands empty")
	var seat := state.placed[4].uid
	editor.hold_placed(state, seat)
	assert_eq(editor.sell(state, data), GameLoop.NOT_FOR_SALE, "seats are not sold")
	assert_eq(editor.store(state, data), GameLoop.OK, "seat stored")
	assert_eq(state.storage.get("seat", 0), 1, "in storage")
