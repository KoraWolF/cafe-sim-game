extends TestCase
## The daily menu: picking dishes at night, ordering from it, favourites and menu slots.
## Data from TestFixtures: 2 slots; jelly needs an alien Synth; tourists love jelly.


func _night(data: GameData) -> GameState:
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	return state


func test_new_game_menu_has_the_unlocked_dishes() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	assert_eq(state.menu_slots, 2, "2 slots")
	assert_eq(state.menu, ["tea"] as Array[String], "only tea is unlocked")


func test_set_menu_at_night() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.set_menu(state, ["tea"] as Array[String], data), GameLoop.WRONG_PHASE, "not mid-shift")
	state = _night(data)
	assert_eq(GameLoop.set_menu(state, [] as Array[String], data), GameLoop.EMPTY_MENU, "empty")
	assert_eq(GameLoop.set_menu(state, ["cake"] as Array[String], data), GameLoop.UNKNOWN_RECIPE, "unknown")
	assert_eq(GameLoop.set_menu(state, ["jelly"] as Array[String], data), GameLoop.RECIPE_LOCKED, "locked")
	state.add_synth("alien", "", data)
	assert_eq(GameLoop.set_menu(state, ["jelly", "tea", "jelly"] as Array[String], data), GameLoop.OK, "set")
	assert_eq(state.menu, ["jelly", "tea"] as Array[String], "duplicates dropped")
	state.menu_slots = 1
	assert_eq(GameLoop.set_menu(state, ["jelly", "tea"] as Array[String], data), GameLoop.MENU_TOO_LONG, "1 slot")


func test_customers_order_only_from_the_menu() -> void:
	var data := TestFixtures.data({"arrival_min_seconds": 3, "arrival_max_seconds": 3, "start_seats": 20})
	var state := _night(data)
	state.add_synth("alien", "", data)
	GameLoop.set_menu(state, ["jelly"] as Array[String], data)
	GameLoop.end_night(state, data)
	GameLoop.advance(state, 40, data)
	assert_true(state.customers.size() >= 5, "setup: several customers")
	for customer: Customer in state.customers:
		if customer.stage != Customer.Stage.QUEUED:
			assert_eq(customer.recipe_id, "jelly", "ordered from the menu")


func test_favourites_are_ordered_more_often() -> void:
	var data := TestFixtures.data()
	var menu: Array[Recipe] = [data.recipes["tea"], data.recipes["jelly"]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var jelly := 0
	for i: int in 4000:
		if Shift._pick_order(data.customer_types["tourist"], menu, data.balance, rng) == "jelly":
			jelly += 1
	# Weights 3 : 1, so 75%.
	assert_true(jelly > 2850 and jelly < 3150, "about 75%% jelly, got %d / 4000" % jelly)
	var regular := 0
	for i: int in 4000:
		if Shift._pick_order(data.customer_types["regular"], menu, data.balance, rng) == "jelly":
			regular += 1
	assert_true(regular > 1850 and regular < 2150, "no favourite: about 50%%, got %d / 4000" % regular)


func test_serving_a_favourite_raises_satisfaction() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.add_synth("alien", "", data).role = Synth.REST
	state.counter["jelly"] = 1
	var tourist := Customer.new()
	tourist.id = "fan"
	tourist.type_id = "tourist"
	tourist.stage = Customer.Stage.WAITING_FOOD
	tourist.recipe_id = "jelly"
	tourist.satisfaction = 50.0
	state.customers.append(tourist)
	GameLoop.advance(state, 5, data)
	assert_eq(tourist.stage, Customer.Stage.EATING, "served")
	assert_eq(tourist.satisfaction, 60.0, "+10 for a favourite")


func test_menu_slot_upgrade() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	state.coins = 100
	assert_eq(GameLoop.buy_upgrade(state, "menu_slot", data), GameLoop.OK, "bought")
	assert_eq(state.menu_slots, 3, "one more slot")


func test_menu_survives_saving_and_old_saves_order_anything() -> void:
	var data := TestFixtures.data()
	var path := "user://test_saves/menu.json"
	var state := _night(data)
	state.add_synth("alien", "", data)
	GameLoop.set_menu(state, ["jelly"] as Array[String], data)
	SaveSystem.save(state, path)
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.menu, ["jelly"] as Array[String], "menu saved")
	var raw := SaveSystem.to_dict(state)
	raw.erase("menu")
	raw.erase("menu_slots")
	raw["seats"] = 2
	raw["pods"] = 2  # 2 Synths: starter + alien
	for key: String in ["floor_rows", "placed", "storage"]:
		raw.erase(key)
	raw["version"] = 3
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	errors.clear()
	loaded = SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "v3 loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.menu_slots, 2, "default slots")
		assert_eq(Shift.order_menu(loaded, data).size(), 2, "empty menu: any unlocked dish")
