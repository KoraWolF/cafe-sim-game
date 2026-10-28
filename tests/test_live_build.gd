extends TestCase
## Building at any time: upgrades, décor and arranging the floor work during a
## shift too. Pieces in use (a cooking stove, a counter with food, a seat with
## a customer) can't be picked up, but can always be moved.


func _data() -> GameData:
	return TestFixtures.data({"start_counters": 2})


func _first(state: GameState, piece_id: String) -> PlacedPiece:
	for placed: PlacedPiece in state.placed:
		if placed.piece_id == piece_id:
			return placed
	return null


func test_buying_during_a_shift() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	state.coins = 1000
	assert_eq(state.phase, GameState.Phase.SHIFT, "setup: mid-shift")
	assert_eq(GameLoop.buy_upgrade(state, Upgrade.SECURITY, data), GameLoop.OK, "upgrade in a shift")
	assert_eq(GameLoop.buy_piece(state, "seat", data), GameLoop.OK, "furniture in a shift")
	assert_eq(GameLoop.buy_piece(state, "fern", data), GameLoop.OK, "décor in a shift")
	var spot := Layout.find_spot(state, "fern", data)
	assert_eq(GameLoop.place_piece(state, "fern", spot["cell"], spot["rotated"], data), GameLoop.OK, "placed in a shift")
	assert_eq(GameLoop.buy_power(state, 10, data), GameLoop.OK, "Energy in a shift")


func test_pieces_in_use_stay_but_can_move() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, 6, data)
	var seated: Customer = null
	for customer: Customer in state.customers:
		if customer.is_seated():
			seated = customer
	assert_true(seated != null, "setup: someone is seated")
	assert_eq(GameLoop.pick_up_piece(state, seated.seat_uid, data), GameLoop.SEAT_BUSY, "their seat stays")
	var seat := Layout.placed_by_uid(state, seated.seat_uid)
	var spot := Layout.find_spot(state, "seat", data)
	assert_eq(GameLoop.move_piece(state, seat.uid, spot["cell"], spot["rotated"], data), GameLoop.OK, "but moves")
	GameLoop.start_cooking(state, 0, "tea", data)
	assert_eq(GameLoop.pick_up_piece(state, state.stoves[0].piece_uid, data), GameLoop.STOVE_BUSY, "cooking stove stays")
	var counter := _first(state, "counter")
	Counters.put(state, counter.uid, "tea", 1)
	assert_eq(GameLoop.pick_up_piece(state, counter.uid, data), GameLoop.COUNTER_BUSY, "counter with food stays")
	GameLoop.advance(state, 30, data)
	assert_true(SaveSystem.validate(state, data).is_empty(), "the shift carries on cleanly")
