extends TestCase
## The café floor: placing, moving, picking up and selling pieces, Vibe from
## décor and adjacency, and what Vibe does to customers. Data from TestFixtures.


func _night(data: GameData) -> GameState:
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	state.coins = 1000
	return state


## Buys a décor piece and places it; returns its uid.
func _put(state: GameState, piece_id: String, cell: Vector2i, data: GameData, rotated := false) -> String:
	assert_eq(GameLoop.buy_decor(state, piece_id, data), GameLoop.OK, "bought %s" % piece_id)
	assert_eq(GameLoop.place_piece(state, piece_id, cell, rotated, data), GameLoop.OK, "placed %s" % piece_id)
	return state.placed[-1].uid


func test_new_game_lays_out_the_starting_furniture() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	assert_eq(state.placed.size(), 4, "2 stoves, 2 seats (Pods are in the Pod bay, not on the floor)")
	assert_eq(state.stoves.size(), 2, "a stove state for each stove piece")
	assert_eq(state.seats, 2, "seats")
	assert_eq(state.pods, 2, "2 Pods in the bay")
	assert_eq(state.placed[0].cell, Vector2i(0, 0), "first stove top-left")
	assert_eq(state.placed[1].cell, Vector2i(2, 0), "second stove beside it")
	assert_eq(state.vibe, 0.0, "no décor yet")


func test_buying_and_placing_rules() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.buy_decor(state, "fern", data), GameLoop.WRONG_PHASE, "not mid-shift")
	state = _night(data)
	assert_eq(GameLoop.buy_decor(state, "seat", data), GameLoop.NOT_FOR_SALE, "furniture comes from upgrades")
	assert_eq(GameLoop.buy_decor(state, "throne", data), GameLoop.UNKNOWN_PIECE, "unknown")
	assert_eq(GameLoop.buy_decor(state, "tank", data), GameLoop.OK, "bought")
	assert_eq(state.coins, 800, "paid 200")
	assert_eq(GameLoop.place_piece(state, "fern", Vector2i(7, 5), false, data), GameLoop.NONE_STORED, "no fern owned")
	assert_eq(GameLoop.place_piece(state, "tank", Vector2i(7, 5), false, data), GameLoop.OUT_OF_BOUNDS, "2x2 off the edge")
	assert_eq(GameLoop.place_piece(state, "tank", Vector2i(0, 0), false, data), GameLoop.OVERLAP, "on the stoves")
	assert_eq(GameLoop.place_piece(state, "tank", Vector2i(6, 4), false, data), GameLoop.OK, "fits the corner")
	assert_true(state.storage.is_empty(), "storage used")
	state.coins = 10
	assert_eq(GameLoop.buy_decor(state, "fern", data), GameLoop.NOT_ENOUGH_COINS, "too poor")


func test_rotation_swaps_the_footprint() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	# A 2x1 stove rotated is 1x2: fits the last column only when rotated.
	state.storage["stove"] = 1
	assert_eq(GameLoop.place_piece(state, "stove", Vector2i(7, 4), false, data), GameLoop.OUT_OF_BOUNDS, "lengthwise: too wide")
	assert_eq(GameLoop.place_piece(state, "stove", Vector2i(7, 4), true, data), GameLoop.OK, "rotated")
	assert_eq(state.stoves.size(), 3, "counts once placed")


## The fixture's two seats stand at (6, 0) and (7, 0); décor reaches 2 tiles.
func test_vibe_reaches_seats_in_range() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var fern := _put(state, "fern", Vector2i(7, 3), data)
	assert_eq(state.vibe, 0.0, "3 tiles from both seats: out of range")
	assert_eq(GameLoop.move_piece(state, fern, Vector2i(7, 2), false, data), GameLoop.OK, "closer")
	assert_eq(state.vibe, 20.0, "2 tiles: 10 at each of the two seats")
	var lamp := _put(state, "lamp", Vector2i(6, 2), data)
	# Light next to plant +3, split between them: fern 11.5, lamp 6.5, both reach both seats.
	assert_eq(state.vibe, 36.0, "18 at each seat")
	var seat: PlacedPiece = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "seat")[0]
	assert_eq(state.seat_vibe[seat.uid], 18.0, "per seat")
	assert_eq(GameLoop.move_piece(state, lamp, Vector2i(5, 4), false, data), GameLoop.OK, "lamp away")
	assert_eq(state.vibe, 20.0, "lamp out of range and no longer touching")
	assert_eq(GameLoop.move_piece(state, lamp, Vector2i(7, 2), false, data), GameLoop.OVERLAP, "onto the fern")


func test_seats_in_range_and_distance() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var seats := Layout.seats_in_range(state, "fern", Vector2i(7, 2), false, data)
	assert_eq(seats.size(), 2, "both seats within 2 tiles")
	assert_eq(Layout.seats_in_range(state, "fern", Vector2i(3, 5), false, data).size(), 0, "none from far away")


func test_vibe_slows_satisfaction_loss() -> void:
	var data := TestFixtures.data()
	var plain := GameState.new_game(1, data)
	var cozy := GameState.new_game(1, data)
	for seat_uid: String in cozy.seat_vibe:
		cozy.seat_vibe[seat_uid] = 100.0
	# No food: seated at 3, 5 s free, then 2/s (halved by 100 Vibe at their seat).
	GameLoop.advance(plain, 23, data)
	GameLoop.advance(cozy, 23, data)
	assert_eq(plain.customers[0].satisfaction, 70.0, "lost 30")
	assert_eq(cozy.customers[0].satisfaction, 85.0, "lost 15")


func test_vibe_adds_to_every_meal() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 1
	var customer := Customer.new()
	customer.id = "guest"
	customer.type_id = "regular"
	customer.seat_uid = state.seat_vibe.keys()[0]
	state.seat_vibe[customer.seat_uid] = 300.0
	customer.stage = Customer.Stage.WAITING_FOOD
	customer.recipe_id = "tea"
	customer.satisfaction = 50.0
	state.customers.append(customer)
	GameLoop.advance(state, 5, data)
	assert_eq(customer.stage, Customer.Stage.EATING, "served")
	assert_eq(customer.satisfaction, 60.0, "+10: 0.1 x 300 capped at 10")


func test_pick_up_rules() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var stove := state.placed[0].uid
	GameLoop.start_cooking(state, 0, "tea", data)
	assert_eq(GameLoop.pick_up_piece(state, stove, data), GameLoop.STOVE_BUSY, "cooking")
	var seat := state.placed[2].uid
	assert_eq(GameLoop.pick_up_piece(state, seat, data), GameLoop.OK, "seat stored")
	assert_eq(state.seats, 1, "one seat left")
	assert_eq(state.storage, {"seat": 1} as Dictionary[String, int], "in storage")
	var idle := state.placed[1].uid
	assert_eq(GameLoop.pick_up_piece(state, idle, data), GameLoop.OK, "idle stove stored")
	assert_eq(state.stoves.size(), 1, "its stove state went with it")
	assert_eq(GameLoop.start_cooking(state, 0, "tea", data), GameLoop.STOVE_BUSY, "the remaining stove is the cooking one")


func test_selling_decor_refunds_half() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var fern := _put(state, "fern", Vector2i(7, 5), data)
	assert_eq(GameLoop.sell_piece(state, fern, data), GameLoop.OK, "sold")
	assert_eq(state.coins, 1000 - 50 + 25, "half back")
	assert_eq(state.vibe, 0.0, "gone")
	assert_eq(GameLoop.sell_piece(state, state.placed[2].uid, data), GameLoop.NOT_FOR_SALE, "seats are not sold")
	GameLoop.buy_decor(state, "lamp", data)
	assert_eq(GameLoop.sell_stored_piece(state, "lamp", data), GameLoop.OK, "sold from storage")
	assert_eq(GameLoop.sell_stored_piece(state, "lamp", data), GameLoop.NONE_STORED, "none left")
	assert_eq(state.coins, 1000 - 50 + 25 - 30 + 15, "coins")


func test_floor_survives_saving_and_bad_layouts_are_refused() -> void:
	var data := TestFixtures.data()
	var path := "user://test_saves/floor.json"
	var state := _night(data)
	_put(state, "fern", Vector2i(7, 2), data)
	_put(state, "lamp", Vector2i(6, 2), data)
	GameLoop.buy_decor(state, "tank", data)
	SaveSystem.save(state, path)
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(SaveSystem.to_dict(loaded), SaveSystem.to_dict(state), "same floor")
		assert_eq(loaded.vibe, 36.0, "Vibe recomputed")
		assert_eq(loaded.storage, {"tank": 1} as Dictionary[String, int], "storage")
	state.placed[-1].cell = Vector2i(7, 2)
	SaveSystem.save(state, path)
	SaveSystem.save(state, path)
	errors.clear()
	assert_true(SaveSystem.load_file(path, data, errors) == null, "overlap refused")
	assert_true(", ".join(errors).contains("overlap"), "says why: %s" % ", ".join(errors))
	SaveSystem.delete_save(path)


func test_pre_floor_save_is_laid_out_and_keeps_cooking() -> void:
	var data := TestFixtures.data()
	var path := "user://test_saves/old_floor.json"
	var state := _night(data)
	GameLoop.start_cooking(state, 1, "tea", data)
	var raw := SaveSystem.to_dict(state)
	raw["seats"] = 5
	raw["pods"] = 3
	for key: String in ["floor_rows", "placed", "storage"]:
		raw.erase(key)
	for stove: Dictionary in raw["stoves"]:
		stove.erase("piece_uid")
	raw["stoves"].append({"recipe_id": "", "remaining": 0.0})
	raw["version"] = 4
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded == null:
		return
	assert_eq(loaded.stoves.size(), 3, "3 stoves laid out")
	assert_eq(loaded.stoves[1].recipe_id, "tea", "the cooking stove kept its dish")
	assert_eq(loaded.seats, 5, "5 seats laid out")
	assert_eq(loaded.pods, 3, "3 Pods laid out")
	assert_eq(loaded.floor_rows, 6, "it all fits the 6 starting rows")


func test_customers_get_their_own_seats() -> void:
	var data := TestFixtures.data({"arrival_min_seconds": 1, "arrival_max_seconds": 1})
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, 6, data)
	var seated := state.customers.filter(func(c: Customer) -> bool: return c.is_seated())
	assert_eq(seated.size(), 2, "both seats taken")
	assert_true(seated[0].seat_uid != "" and seated[0].seat_uid != seated[1].seat_uid, "each has their own seat")
