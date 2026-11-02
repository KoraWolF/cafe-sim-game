extends TestCase
## Playtest 8: a stove stacks dishes (one cooking, the rest waiting), and
## staff work only once they have walked to their station.


func test_a_stove_queues_the_next_dish() -> void:
	var content := TestFixtures.content({"first_arrival_seconds": 1000, "arrival_min_seconds": 1000, "arrival_max_seconds": 1000})
	for piece: Dictionary in content["pieces"]:
		if piece["id"] == "stove":
			piece["stack"] = 2
	var data := GameData.from_content(content)
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.start_cooking(state, 0, "tea", data), GameLoop.OK, "cooking")
	assert_eq(GameLoop.start_cooking(state, 0, "tea", data), GameLoop.OK, "and one waiting")
	assert_eq(state.coins, 80, "both paid")
	assert_eq(GameLoop.start_cooking(state, 0, "tea", data), GameLoop.STOVE_BUSY, "a stack of 2 is full")
	assert_eq(GameLoop.cancel_queued(state, 0, data), GameLoop.OK, "taken off the queue")
	assert_eq(state.coins, 90, "refunded")
	GameLoop.start_cooking(state, 0, "tea", data)
	GameLoop.advance(state, 11, data)  # (no counters here: a done batch goes straight out)
	assert_eq(state.counter.get("tea", 0), 3, "the first is done")
	assert_eq(state.stoves[0].recipe_id, "tea", "the waiting dish started by itself")
	assert_true(state.stoves[0].queue.is_empty(), "the queue is empty")


func test_a_cashier_takes_payments_only_once_at_the_register() -> void:
	var data := TestFixtures.data({"walk_tiles_per_second": 1.0, "start_registers": 1,
		"start_layout": [{"piece": "seat", "cell": [6, 0]}, {"piece": "seat", "cell": [7, 0]}, {"piece": "table", "cell": [6, 1]},
			{"piece": "table", "cell": [7, 1]}, {"piece": "register", "cell": [0, 4]}]})
	var state := GameState.new_game(1, data)
	var register: PlacedPiece = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "register")[0]
	var cashier := state.add_synth("worker", "", data)
	cashier.role = Synth.REST
	GameLoop.assign_to(state, cashier.id, register.uid, data)
	assert_true(cashier.arrive_left > 0.0, "walking from its Pod")
	assert_true(Shift.active_cashiers(state, data).is_empty(), "not taking payments on the way")
	GameLoop.advance(state, roundi(cashier.arrive_left), data)
	assert_eq(Shift.active_cashiers(state, data), [cashier] as Array[Synth], "at the register: working")
