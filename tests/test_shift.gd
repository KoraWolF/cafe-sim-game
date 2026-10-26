extends TestCase
## The day shift: cooking, customers, serving, satisfaction, battery and closing.
## Data from TestFixtures: one customer every 50 s from second 3.


func _data(overrides := {}) -> GameData:
	return TestFixtures.data(overrides)


func test_new_game() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	assert_eq(state.day, 1, "day")
	assert_eq(state.phase, GameState.Phase.SHIFT, "starts in a shift")
	assert_eq(state.synths.size(), 1, "one starter")
	assert_eq(state.synths[0].species_id, "steady", "starter species")
	assert_eq(state.synths[0].role, Synth.SERVER, "starter serves")
	assert_eq(state.synths[0].battery, 100.0, "full battery")
	assert_eq(state.nanobrew, 1, "one NanoBrew for the first conversion")
	assert_eq(state.stoves.size(), 2, "stoves")


func test_cooking_fills_the_counter() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	state.synths[0].role = Synth.REST
	assert_eq(GameLoop.start_cooking(state, 0, "tea", data), GameLoop.OK, "start tea")
	assert_eq(state.coins, 90, "batch cost paid")
	assert_eq(GameLoop.start_cooking(state, 0, "tea", data), GameLoop.STOVE_BUSY, "stove busy")
	var events := GameLoop.advance(state, 9, data)
	assert_eq(state.counter.get("tea", 0), 0, "not done after 9 s")
	events = GameLoop.advance(state, 1, data)
	assert_eq(state.counter.get("tea", 0), 3, "3 servings after 10 s")
	assert_eq(events.dishes_ready, ["tea"] as Array[String], "batch reported")
	assert_true(state.stoves[0].is_idle(), "stove free again")


func test_chef_speeds_up_cooking() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	state.synths[0].role = Synth.REST
	state.add_synth("chef", "", data)
	GameLoop.start_cooking(state, 0, "tea", data)
	GameLoop.advance(state, 5, data)
	assert_eq(state.counter.get("tea", 0), 3, "cook 1.0 doubles kitchen speed")


func test_cooking_errors() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.start_cooking(state, 5, "tea", data), GameLoop.UNKNOWN_STOVE, "bad stove")
	assert_eq(GameLoop.start_cooking(state, 0, "cake", data), GameLoop.UNKNOWN_RECIPE, "bad recipe")
	assert_eq(GameLoop.start_cooking(state, 0, "jelly", data), GameLoop.RECIPE_LOCKED, "needs an alien")
	state.coins = 5
	assert_eq(GameLoop.start_cooking(state, 0, "tea", data), GameLoop.NOT_ENOUGH_COINS, "too poor")


func test_customer_is_served_pays_tips_and_stars() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 3
	# Arrives and sits at 3, served 3..7 (4 s at speed 1), eats until 11.
	var events := GameLoop.advance(state, 12, data)
	assert_eq(events.arrived.size(), 1, "one arrival")
	assert_eq(events.served.size(), 1, "served")
	assert_eq(events.coins_earned, 10, "full price at 100 satisfaction")
	assert_eq(events.tips_earned, 5, "tip = 10 * 0.5")
	assert_eq(state.coins, 115, "coins")
	assert_eq(state.counter["tea"], 2, "one serving used")
	assert_eq(events.starred.size(), 1, "starred")
	var customer := state.customer_by_id(events.starred[0])
	assert_eq(customer.stage, Customer.Stage.STAR, "waits with a star")
	events = GameLoop.advance(state, 10, data)
	assert_eq(events.star_expired.size(), 1, "star window ends")
	assert_true(state.customers.is_empty(), "gone")


func test_customer_without_food_loses_satisfaction_and_leaves() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	# Seated at 3, no food: 5 s grace then -2/s -> 0 after 55 s at the table.
	var events := GameLoop.advance(state, 30, data)
	var customer := state.customers[0]
	assert_eq(customer.stage, Customer.Stage.WAITING_FOOD, "still waiting")
	assert_true(customer.satisfaction < 100.0, "satisfaction dropped")
	events = GameLoop.advance(state, 30, data)
	assert_eq(events.left_angry.size(), 1, "left angry")
	assert_eq(events.coins_earned, 0, "paid nothing")


func test_unhappy_customer_pays_less_and_gets_no_star() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, 20, data)
	state.counter["tea"] = 1
	var events := GameLoop.advance(state, 15, data)
	assert_eq(events.served.size(), 1, "served late")
	assert_true(events.coins_earned < 10, "paid less than full price")
	assert_eq(events.starred.size(), 0, "no star")
	assert_eq(events.tips_earned, 0, "no tip")


func test_full_queue_turns_customers_away() -> void:
	var data := _data({"arrival_min_seconds": 1, "arrival_max_seconds": 1, "start_seats": 0})
	var state := GameState.new_game(1, data)
	var events := GameLoop.advance(state, 6, data)
	assert_eq(events.arrived.size(), 2, "queue holds 2")
	assert_eq(events.turned_away, 1, "third turned away")


func test_battery_drains_and_empty_synth_stops_working() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	var starter := state.synths[0]
	GameLoop.advance(state, 10, data)
	assert_eq(starter.battery, 90.0, "drain 1/s on duty")
	GameLoop.assign_role(state, starter.id, Synth.REST)
	GameLoop.advance(state, 10, data)
	assert_eq(starter.battery, 90.0, "no drain at rest")
	GameLoop.assign_role(state, starter.id, Synth.SERVER)
	starter.battery = 0.0
	state.counter["tea"] = 3
	GameLoop.advance(state, 20, data)
	assert_eq(state.counter["tea"], 3, "an empty server delivers nothing")


func test_late_shift_and_low_battery_factors() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	var owl := state.add_synth("worker", "owl", data)
	assert_eq(SynthStats.work_factor(owl, state, data), 1.0, "normal early")
	state.shift_time = 70
	assert_eq(SynthStats.work_factor(owl, state, data), 1.5, "night owl speeds up late")
	owl.battery = 5.0
	assert_eq(SynthStats.work_factor(owl, state, data), 0.75, "low battery halves it")


func test_shift_closes_into_night() -> void:
	var data := _data()
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 1
	var events := GameLoop.advance(state, 500, data)
	assert_true(events.shift_ended, "closed")
	assert_eq(state.phase, GameState.Phase.NIGHT, "night")
	assert_eq(state.shift_time, 100, "stopped at closing time")
	assert_true(state.customers.is_empty(), "everyone left")
	assert_eq(GameLoop.advance(state, 10, data).arrived.size(), 0, "no time passes at night")


func test_dish_in_hand_returns_at_closing() -> void:
	var data := _data({"shift_seconds": 5})
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 1
	GameLoop.advance(state, 5, data)
	assert_eq(state.counter["tea"], 1, "carried dish back on the counter")
	assert_true(not state.synths[0].is_delivering(), "server free")


func test_same_seed_same_shift() -> void:
	var data := _data({"arrival_min_seconds": 2, "arrival_max_seconds": 9})
	var a := GameState.new_game(7, data)
	var b := GameState.new_game(7, data)
	a.counter["tea"] = 20
	b.counter["tea"] = 20
	assert_eq(GameLoop.advance(a, 100, data).arrived, GameLoop.advance(b, 100, data).arrived, "deterministic")
	assert_eq(a.coins, b.coins, "same coins")
