extends TestCase
## Playtest 9: nothing can be placed so it cuts a piece off from the door; the
## pay line holds pay_line_max per register, and when it's full finished
## customers wait at their table, then leave without paying.


func test_a_piece_cannot_cut_another_off_from_the_door() -> void:
	var data := TestFixtures.data({"start_registers": 1, "start_layout": [{"piece": "register", "cell": [0, 3]}]})
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	state.coins = 1000
	assert_eq(GameLoop.buy_piece(state, "fern", data), GameLoop.OK, "bought")
	assert_eq(GameLoop.place_piece(state, "fern", Vector2i(1, 3), false, data), GameLoop.OK, "one side of the register")
	assert_eq(GameLoop.buy_piece(state, "fern", data), GameLoop.OK, "bought another")
	assert_eq(GameLoop.place_piece(state, "fern", Vector2i(0, 2), false, data), GameLoop.OK, "another side")
	assert_eq(GameLoop.buy_piece(state, "fern", data), GameLoop.OK, "and a third")
	assert_eq(GameLoop.place_piece(state, "fern", Vector2i(0, 4), false, data), GameLoop.BLOCKS_WAY,
		"not the last way to it")
	assert_eq(GameLoop.place_piece(state, "fern", Vector2i(3, 3), false, data), GameLoop.OK, "fine elsewhere")


func test_a_full_pay_line_keeps_customers_at_their_table() -> void:
	var data := TestFixtures.data({"start_registers": 1, "pay_line_max": 1, "pay_wait_seconds": 5,
		"queue_patience_seconds": 1000, "start_layout": [{"piece": "seat", "cell": [6, 0]}, {"piece": "seat", "cell": [7, 0]},
			{"piece": "table", "cell": [6, 1]}, {"piece": "table", "cell": [7, 1]}, {"piece": "register", "cell": [0, 4]}]})
	var state := GameState.new_game(1, data)
	for customer_id: String in ["a", "b"]:
		var customer := Customer.new()
		customer.id = customer_id
		customer.type_id = data.customer_types.keys()[0]
		customer.recipe_id = "tea"
		customer.stage = Customer.Stage.EATING
		customer.timer = 1
		customer.seat_uid = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "seat")[state.customers.size()].uid
		state.customers.append(customer)
	GameLoop.advance(state, 1, data)
	var stages := state.customers.map(func(c: Customer) -> int: return c.stage)
	assert_true(stages.has(Customer.Stage.PAYING) and stages.has(Customer.Stage.WAITING_PAY), "one in line, one at its table")
	var waiting: Customer = state.customers.filter(func(c: Customer) -> bool: return c.stage == Customer.Stage.WAITING_PAY)[0]
	assert_true(waiting.is_seated(), "still in its seat")
	var coins := state.coins
	GameLoop.advance(state, 40, data)
	assert_true(not state.customers.has(waiting), "waited too long and left")
	assert_eq(state.coins, coins, "without paying (nobody at the register either)")
