extends TestCase
## Café upgrades (café level, security) and Pods: costs grow, caps hold,
## effects apply. Furniture is not an upgrade: it is bought by the piece, as
## many as fit on the floor, and sells back for half.


func _night(data: GameData) -> GameState:
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	state.coins = 1000
	return state


func test_pods_are_bought_up_to_the_cafe_side() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	assert_eq(GameLoop.pod_cap(state), 8, "8 wide: 8 Pods")
	assert_eq(GameLoop.buy_pod(state, data), GameLoop.OK, "bought")
	assert_eq([state.pods, state.coins], [3, 900], "straight to the Pod bay, 100 coins")
	state.pods = 8
	assert_eq(GameLoop.buy_pod(state, data), GameLoop.MAXED, "cap holds")
	GameLoop.buy_upgrade(state, "floor", data)
	assert_eq(GameLoop.pod_cap(state), 8, "8 x 8: still 8")
	GameLoop.buy_upgrade(state, "floor", data)
	assert_eq(GameLoop.buy_pod(state, data), GameLoop.OK, "10 x 10: room for more")


func test_each_upgrade_applies() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	for upgrade_id: String in ["security", "floor"]:
		assert_eq(GameLoop.buy_upgrade(state, upgrade_id, data), GameLoop.OK, upgrade_id)
	assert_eq(Vector2i(state.floor_width, state.floor_rows), Vector2i(8, 8), "8 x 8")
	assert_eq(state.security, 10.0, "+10 security")
	assert_eq(state.upgrades, {"security": 1, "floor": 1} as Dictionary[String, int], "levels")
	assert_eq(GameLoop.buy_upgrade(state, "stove", data), GameLoop.UNKNOWN_UPGRADE, "furniture is not an upgrade")


func test_upgrade_errors() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	assert_eq(GameLoop.buy_upgrade(state, "jacuzzi", data), GameLoop.UNKNOWN_UPGRADE, "unknown")
	state.coins = 10
	assert_eq(GameLoop.buy_upgrade(state, "security", data), GameLoop.NOT_ENOUGH_COINS, "too poor")


func test_furniture_has_no_limit_but_the_floor() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	state.coins = 100000
	for i: int in 12:
		assert_eq(GameLoop.buy_piece(state, "seat", data), GameLoop.OK, "seat %d" % (i + 1))
	assert_eq(state.storage["seat"], 12, "as many as you like")
	assert_eq(state.coins, 100000 - 12 * 20, "flat price, 20 each")
	var placed := 0
	while not Layout.find_spot(state, "seat", data).is_empty() and state.storage.get("seat", 0) > 0:
		var spot := Layout.find_spot(state, "seat", data)
		GameLoop.place_piece(state, "seat", spot["cell"], spot["rotated"], data)
		placed += 1
	assert_eq(placed, 12, "they all fit for now")
	state.coins = 0
	assert_eq(GameLoop.buy_piece(state, "stove", data), GameLoop.NOT_ENOUGH_COINS, "coins are the price")


func test_new_stove_cooks_and_survives_saving() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	assert_eq(GameLoop.buy_piece(state, "stove", data), GameLoop.OK, "bought a stove")
	var spot := Layout.find_spot(state, "stove", data)
	GameLoop.place_piece(state, "stove", spot["cell"], spot["rotated"], data)
	assert_eq(GameLoop.start_cooking(state, 2, "tea", data), GameLoop.OK, "third stove usable")
	var errors: PackedStringArray = []
	var path := "user://test_saves/upgrades.json"
	SaveSystem.save(state, path)
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.stoves.size(), 3, "stoves saved")
		assert_eq(loaded.stoves[2].recipe_id, "tea", "still cooking")


func test_selling_furniture() -> void:
	var data := TestFixtures.data({"start_counters": 1, "start_registers": 1})
	var state := _night(data)
	var seat: PlacedPiece = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "seat")[0]
	var coins := state.coins
	assert_eq(GameLoop.sell_piece(state, seat.uid, data), GameLoop.OK, "a seat sells")
	assert_eq(state.coins, coins + 10, "half its price")
	var counter: PlacedPiece = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "counter")[0]
	assert_eq(GameLoop.sell_piece(state, counter.uid, data), GameLoop.COUNTER_NEEDED, "not the last counter")
	var register: PlacedPiece = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "register")[0]
	assert_eq(GameLoop.sell_piece(state, register.uid, data), GameLoop.REGISTER_NEEDED, "not the last register")
	GameLoop.start_cooking(state, 0, "tea", data)
	assert_eq(GameLoop.sell_piece(state, state.stoves[0].piece_uid, data), GameLoop.STOVE_BUSY, "not a busy stove")


func test_version_13_drops_furniture_upgrade_levels() -> void:
	var data := TestFixtures.data()
	var path := "user://test_saves/old_upgrades.json"
	var state := _night(data)
	var raw := SaveSystem.to_dict(state)
	raw["upgrades"] = {"stove": 2, "seat": 3, "pod": 1}
	raw["version"] = 13
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.upgrades, {} as Dictionary[String, int], "no furniture or Pod levels left (Pods are bought by the piece)")


func test_missing_upgrade_data_is_rejected() -> void:
	var content := TestFixtures.content()
	content["upgrades"].pop_back()
	expected_errors = 1
	assert_true(GameData.from_content(content) == null, "security upgrade required")
