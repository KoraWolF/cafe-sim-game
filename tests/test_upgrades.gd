extends TestCase
## Buying café upgrades at night: costs grow, caps hold, effects apply.


func _night(data: GameData) -> GameState:
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	state.coins = 1000
	return state


func test_stove_cost_grows_and_caps() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	assert_eq(GameLoop.upgrade_cost(state, "stove", data), 50, "first stove")
	assert_eq(GameLoop.buy_upgrade(state, "stove", data), GameLoop.OK, "bought")
	assert_eq(state.stoves.size(), 3, "one more stove")
	assert_eq(GameLoop.upgrade_cost(state, "stove", data), 100, "doubles")
	assert_eq(GameLoop.buy_upgrade(state, "stove", data), GameLoop.OK, "bought again")
	assert_eq(state.coins, 850, "paid 50 + 100")
	assert_eq(GameLoop.upgrade_cost(state, "stove", data), -1, "maxed")
	assert_eq(GameLoop.buy_upgrade(state, "stove", data), GameLoop.MAXED, "cap holds")


func test_each_upgrade_applies() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	for upgrade_id: String in ["seat", "pod", "security"]:
		assert_eq(GameLoop.buy_upgrade(state, upgrade_id, data), GameLoop.OK, upgrade_id)
	assert_eq(state.seats, 4, "2 + 2 seats")
	assert_eq(state.pods, 3, "2 + 1 pods")
	assert_eq(state.security, 10.0, "+10 security")
	assert_eq(state.upgrades, {"seat": 1, "pod": 1, "security": 1} as Dictionary[String, int], "levels")


func test_upgrade_errors() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.buy_upgrade(state, "seat", data), GameLoop.WRONG_PHASE, "not during a shift")
	state = _night(data)
	assert_eq(GameLoop.buy_upgrade(state, "jacuzzi", data), GameLoop.UNKNOWN_UPGRADE, "unknown")
	state.coins = 10
	assert_eq(GameLoop.buy_upgrade(state, "seat", data), GameLoop.NOT_ENOUGH_COINS, "too poor")
	assert_eq(state.seats, 2, "nothing changed")


func test_new_stove_cooks_and_upgrades_survive_saving() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	GameLoop.buy_upgrade(state, "stove", data)
	assert_eq(GameLoop.start_cooking(state, 2, "tea", data), GameLoop.OK, "third stove usable")
	var errors: PackedStringArray = []
	var path := "user://test_saves/upgrades.json"
	SaveSystem.save(state, path)
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.upgrades.get("stove", 0), 1, "level saved")
		assert_eq(loaded.stoves.size(), 3, "stoves saved")


func test_missing_upgrade_data_is_rejected() -> void:
	var content := TestFixtures.content()
	content["upgrades"].pop_back()
	expected_errors = 1
	assert_true(GameData.from_content(content) == null, "security upgrade required")
