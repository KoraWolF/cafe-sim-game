extends TestCase
## No daily menu: customers sit down without ordering, a server brings them the
## dish on the counter nearest their seat and they pay that dish's price. A
## batch still cooking can be cancelled for a refund.
## Data from TestFixtures with 2 counters at (4, 0) and (5, 0); seats at (6, 0) and (7, 0).


func _data(overrides := {}) -> GameData:
	var settings := {"start_counters": 2, "carry_seconds": 3}
	settings.merge(overrides, true)
	return TestFixtures.data(settings)


func _counters(state: GameState) -> Array:
	return state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "counter")


func test_customers_sit_without_an_order() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, 4, data)
	assert_eq(state.customers.size(), 1, "setup: one customer")
	assert_eq(state.customers[0].stage, Customer.Stage.WAITING_FOOD, "seated")
	assert_eq(state.customers[0].recipe_id, "", "no order")


func test_the_nearest_counter_dish_is_served_and_paid_for() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	state.add_synth("alien", "", data).role = Synth.REST
	var counters := _counters(state)
	Counters.put(state, counters[0].uid, "tea", 2)  # (4, 0): farther from the seats
	Counters.put(state, counters[1].uid, "jelly", 1)  # (5, 0): nearest
	GameLoop.advance(state, 4, data)
	var customer := state.customers[0]
	assert_eq(state.synth_by_id(customer.served_by).task_recipe_id, "jelly", "the nearest dish")
	assert_eq(state.counter_count.get(counters[1].uid, 0), 0, "taken from the nearest counter")
	var coins := state.coins
	var events := GameLoop.advance(state, 12, data)
	assert_eq(events.served.size(), 1, "served and paid")
	assert_true(state.coins - coins >= 25, "paid for jelly (price 50), got %d" % (state.coins - coins))


func test_nothing_on_the_counters_means_waiting() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, 10, data)
	assert_eq(state.customers[0].served_by, "", "nobody brings anything")


func test_cancel_cooking_refunds() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.cancel_cooking(state, 0, data), GameLoop.NOT_COOKING, "idle")
	assert_eq(GameLoop.cancel_cooking(state, 9, data), GameLoop.UNKNOWN_STOVE, "no such stove")
	GameLoop.start_cooking(state, 0, "tea", data)
	assert_eq(state.coins, 90, "paid 10")
	GameLoop.advance(state, 3, data)
	assert_eq(GameLoop.cancel_cooking(state, 0, data), GameLoop.OK, "cancelled")
	assert_eq(state.coins, 100, "refunded")
	assert_true(state.stoves[0].is_idle(), "free for another dish")
	GameLoop.start_cooking(state, 0, "tea", data)
	GameLoop.advance(state, 10, data)
	assert_true(state.stoves[0].has_batch(), "setup: done")
	assert_eq(GameLoop.cancel_cooking(state, 0, data), GameLoop.NOT_COOKING, "a finished batch can't be cancelled")


func test_old_saves_drop_the_menu() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, 4, data)
	var raw := SaveSystem.to_dict(state)
	raw["version"] = 15
	raw["menu"] = ["tea"]
	raw["menu_slots"] = 2
	raw["upgrades"] = {"menu_slot": 1}
	raw["customers"][0]["recipe_id"] = "tea"
	var path := "user://test_saves/free_menu.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "v15 loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.upgrades, {} as Dictionary[String, int], "menu slot upgrade dropped")
		assert_eq(loaded.customers[0].recipe_id, "", "the old order is forgotten")


func test_the_dish_goes_on_the_table() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	Counters.put(state, _counters(state)[0].uid, "tea", 2)
	GameLoop.advance(state, 4, data)
	var customer := state.customers[0]
	var server := state.synth_by_id(customer.served_by)
	assert_true(server != null, "setup: a dish on its way")
	GameLoop.advance(state, roundi(server.task_total) + 1, data)
	assert_eq(customer.stage, Customer.Stage.EATING, "served")
	assert_eq(server.spot_uid, state.seat_table[customer.seat_uid], "the server stopped at the table, not the seat")

