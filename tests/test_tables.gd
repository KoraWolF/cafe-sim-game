extends TestCase
## Tables: a seat works only right beside a table (not diagonally), one seat
## per table. Seats without a table seat nobody. Fixture floor 8 x 6: stoves on
## (0..3, 0), seats (6, 0) and (7, 0) with tables (6, 1) and (7, 1).


func _night(data: GameData) -> GameState:
	var state := GameState.new_game(1, data)
	state.phase = GameState.Phase.NIGHT
	state.coins = 1000
	return state


func _put(state: GameState, piece_id: String, cell: Vector2i, data: GameData) -> String:
	state.storage[piece_id] = state.storage.get(piece_id, 0) + 1
	assert_eq(GameLoop.place_piece(state, piece_id, cell, false, data), GameLoop.OK, "placed %s at %s" % [piece_id, cell])
	return Layout.piece_at(state, cell, data).uid


func test_seat_needs_a_table_beside_it() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	assert_eq(state.seats, 2, "the start seats face their tables")
	var lone := _put(state, "seat", Vector2i(2, 3), data)
	assert_eq(state.seats, 2, "a seat alone does not work")
	assert_true(not state.seat_table.has(lone), "no table for it")
	assert_true(not state.seat_vibe.has(lone), "and no Vibe counted for it")
	_put(state, "table", Vector2i(3, 4), data)
	assert_eq(state.seats, 2, "a diagonal table does not count")
	var table := _put(state, "table", Vector2i(2, 4), data)
	assert_eq(state.seats, 3, "a table right below it does")
	assert_eq(state.seat_table[lone], table, "they are paired")


func test_one_seat_per_table() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var table := _put(state, "table", Vector2i(3, 3), data)
	var left := _put(state, "seat", Vector2i(2, 3), data)
	var right := _put(state, "seat", Vector2i(4, 3), data)
	assert_eq(state.seats, 3, "only one of the two seats gets the table")
	assert_true(state.seat_table.has(left) != state.seat_table.has(right), "exactly one of them")
	_put(state, "table", Vector2i(4, 4), data)
	assert_eq(state.seats, 4, "a second table makes both work")
	assert_true(state.seat_table.values().has(table), "the first table is still used")


func test_customers_only_take_working_seats() -> void:
	var data := TestFixtures.data({"arrival_min_seconds": 2, "arrival_max_seconds": 2, "max_queue": 10})
	var state := GameState.new_game(1, data)
	state.storage["seat"] = 1
	GameLoop.place_piece(state, "seat", Vector2i(2, 3), false, data)
	GameLoop.advance(state, 30, data)
	for customer: Customer in state.customers:
		if customer.is_seated():
			assert_true(state.seat_table.has(customer.seat_uid), "seated at a seat with a table")
	assert_true(Shift.seated_count(state) <= 2, "the lone seat stays empty")


func test_table_of_a_seated_customer_stays() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, 6, data)
	var seated: Customer = null
	for customer: Customer in state.customers:
		if customer.is_seated():
			seated = customer
	assert_true(seated != null, "setup: someone is seated")
	assert_eq(GameLoop.pick_up_piece(state, state.seat_table[seated.seat_uid], data), GameLoop.SEAT_BUSY, "their table stays")


func test_new_furniture_goes_beside_a_partner() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var seat := _put(state, "seat", Vector2i(2, 3), data)
	var spot := Layout.find_spot(state, "table", data)
	assert_eq(Layout.distance(Layout.placed_by_uid(state, seat), _fake(spot), data), 1, "a new table goes beside the lone seat")


func _fake(spot: Dictionary) -> PlacedPiece:
	var placed := PlacedPiece.new()
	placed.piece_id = "table"
	placed.cell = spot["cell"]
	return placed


func test_real_starter_cafe_is_6_by_6_with_three_tables() -> void:
	var data := GameData.load_default()
	var state := GameState.new_game(1, data)
	assert_eq(Vector2i(state.floor_width, state.floor_rows), Vector2i(6, 6), "6 x 6")
	assert_eq(Layout.count_placed(state, Piece.STOVE, data), 1, "1 stove")
	assert_eq(Layout.count_placed(state, Piece.COUNTER, data), 3, "3 counters")
	assert_eq(Layout.count_placed(state, Piece.REGISTER, data), 1, "1 register")
	assert_eq(Layout.count_placed(state, Piece.TABLE, data), 3, "3 tables")
	assert_eq(Layout.count_placed(state, Piece.SEAT, data), 3, "3 seats")
	assert_eq(state.seats, 3, "all working")
	assert_eq(Layout.count_placed(state, Piece.BIN, data), 1, "1 bin")


func test_version_9_seats_get_tables() -> void:
	var data := TestFixtures.data()
	var path := "user://test_saves/no_tables.json"
	var state := GameState.new_game(1, data)
	for table: PlacedPiece in state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "table"):
		Layout.pick_up(state, table.uid, data)
	state.storage.clear()
	var raw := SaveSystem.to_dict(state)
	raw["version"] = 9
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.seats, 2, "both seats got a table and work again")
