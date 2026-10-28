extends TestCase
## Paying at the register: customers who finish eating line up; each working
## Cashier (one per register) takes the next one, 1 s (2 s starred) at speed 1,
## and the coins come in then. No Cashier, no payments. Fixture with one
## register at (5, 3); the starter "steady" server plus a "steady" Cashier
## (speed 1).


func _data(overrides := {}) -> GameData:
	var settings := {"start_registers": 1, "starter_cashier_species": "steady", "starter_cashier_name": "Till",
		"start_pods": 3, "start_layout": [{"piece": "seat", "cell": [6, 0]}, {"piece": "seat", "cell": [7, 0]},
			{"piece": "table", "cell": [6, 1]}, {"piece": "table", "cell": [7, 1]}, {"piece": "register", "cell": [5, 3]}]}
	settings.merge(overrides, true)
	return TestFixtures.data(settings)


## A customer who just finished eating, in the pay line.
func _finished(state: GameState, data: GameData, satisfaction := 50.0) -> Customer:
	var customer := Customer.new()
	customer.id = state.new_id("customer")
	customer.type_id = "regular"
	customer.recipe_id = "tea"
	customer.stage = Customer.Stage.EATING
	customer.timer = 1
	customer.satisfaction = satisfaction
	state.customers.append(customer)
	return customer


func _quiet(state: GameState) -> void:
	state.next_arrival = 100000


func test_new_game_has_a_cashier_and_a_register() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	assert_eq(state.synths.size(), 2, "two staff")
	assert_eq(state.synths[1].role, Synth.CASHIER, "the second works the register")
	assert_eq(state.synths[1].name, "Till", "named")
	assert_eq(state.pods, 3, "a Pod free for the first NanoBrew")
	assert_eq(Layout.count_placed(state, Piece.REGISTER, data), 1, "one register")
	var real := GameData.load_default()
	var game := GameState.new_game(1, real)
	assert_eq(game.synths.size(), 2, "real start: two staff")
	assert_eq(game.synths[1].species_id, "clerkbot", "a Clerkbot Cashier")
	assert_eq(game.pods, 3, "real start: 3 Pods")
	assert_eq(Layout.count_placed(game, Piece.REGISTER, real), 1, "real start: one register")


func test_customers_pay_at_the_register() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	_quiet(state)
	var coins := state.coins
	var first := _finished(state, data)
	var second := _finished(state, data)
	var events := GameLoop.advance(state, 1, data)
	assert_eq(events.served, [first.id] as Array[String], "the first paid (1 s at speed 1)")
	assert_eq(state.coins, coins + first.bill, "coins in at the register")
	assert_eq(second.stage, Customer.Stage.PAYING, "the second is in line")
	assert_true(second.cashier_id == "", "waiting their turn")
	events = GameLoop.advance(state, 1, data)
	assert_eq(events.served, [second.id] as Array[String], "then the second")
	assert_true(state.customers.is_empty(), "both gone")


func test_no_cashier_no_payment() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	_quiet(state)
	state.synths[1].role = Synth.REST
	var coins := state.coins
	var customer := _finished(state, data, 90.0)
	GameLoop.advance(state, 60, data)
	assert_eq(customer.stage, Customer.Stage.PAYING, "still waiting to pay")
	assert_eq(state.coins, coins, "nothing paid")
	assert_eq(customer.tip, 0, "got angry in line: no tip")
	state.synths[1].role = Synth.CASHIER
	GameLoop.advance(state, 3, data)
	assert_eq(state.coins, coins + customer.bill, "pays without the tip once a Cashier is back")


func test_one_cashier_per_register() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	state.synths[0].role = Synth.CASHIER
	assert_eq(Shift.active_cashiers(state, data).size(), 1, "one register, one working Cashier")
	state.storage["register"] = 1
	GameLoop.place_piece(state, "register", Vector2i(5, 5), false, data)
	Roles.bind_free(state, data)
	assert_eq(Shift.active_cashiers(state, data).size(), 2, "a second register puts the second to work")
	assert_eq(GameLoop.pick_up_piece(state, Layout.piece_at(state, Vector2i(5, 5), data).uid, data), GameLoop.OK, "one can go")
	assert_eq(GameLoop.pick_up_piece(state, Layout.piece_at(state, Vector2i(5, 3), data).uid, data),
		GameLoop.REGISTER_NEEDED, "the last register stays")


func test_star_customer_pays_two_seconds_and_converts_anywhere_out() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	_quiet(state)
	state.synths[1].role = Synth.REST
	var customer := _finished(state, data, 100.0)
	var events := GameLoop.advance(state, 1, data)
	assert_eq(events.starred, [customer.id] as Array[String], "starred when they finish eating")
	assert_true(customer.can_convert(), "can be converted in the pay line")
	var coins := state.coins
	assert_eq(GameLoop.convert_customer(state, customer.id, data), GameLoop.OK, "converted in line")
	assert_eq(state.coins, coins + customer.bill + customer.tip, "they paid first")
	var second := _finished(state, data, 100.0)
	state.synths[1].role = Synth.CASHIER
	GameLoop.advance(state, 1, data)
	assert_eq(second.pay_left, 1.0, "2 s at speed 1: half done after a second")
	GameLoop.advance(state, 1, data)
	assert_eq(second.stage, Customer.Stage.STAR, "paid, leaving with a star")
	assert_true(second.can_convert(), "still convertible while leaving")


func test_shift_end_settles_the_line() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	_quiet(state)
	var customer := _finished(state, data)
	state.synths[1].role = Synth.REST
	GameLoop.advance(state, 2, data)
	var coins := state.coins
	state.synths[1].role = Synth.CASHIER
	state.shift_time = data.balance.shift_seconds - 1
	GameLoop.advance(state, 1, data)
	assert_eq(state.phase, GameState.Phase.NIGHT, "closed")
	assert_true(state.coins >= coins + customer.bill, "the line paid at closing")


func test_version_10_cafe_gets_a_register_and_cashier() -> void:
	var data := GameData.load_default()
	var path := "user://test_saves/no_register.json"
	var state := GameState.new_game(1, data)
	var register: PlacedPiece = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "register")[0]
	state.placed.erase(register)
	state.synths.pop_back()
	state.pods = 2
	var raw := SaveSystem.to_dict(state)
	raw["version"] = 10
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(Layout.count_placed(loaded, Piece.REGISTER, data), 1, "a register placed")
		assert_eq(loaded.synths.size(), 2, "a Cashier joined")
		assert_eq(loaded.synths[1].role, Synth.CASHIER, "working the register")
		assert_eq(loaded.pods, 3, "with a Pod of its own")
