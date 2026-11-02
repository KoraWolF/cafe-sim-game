extends TestCase
## Playtest 8: a stove stacks dishes (one cooking, the rest waiting), staff
## work only once they have walked to their station, and battles are fought in
## cafés with one door (attackers walk in; the fight starts at the door).


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


func test_defenders_are_the_most_charged_and_skip_the_recharge() -> void:
	var data := TestFixtures.data({"defense_base_chance": 1.0, "defender_count": 1, "start_security": 1000.0})
	var state := GameState.new_game(1, data)
	var strong := state.add_synth("worker", "", data)
	strong.role = Synth.REST
	strong.battery = 50.0
	GameLoop.advance(state, data.balance.shift_seconds, data)
	assert_eq(state.defenders, [strong.id] as Array[String], "the one with the most battery is ticked")
	state.power = 1000.0
	var before := strong.battery
	var report := GameLoop.end_night(state, data)
	assert_eq(report.defense.defenders.size(), 1, "it defended")
	assert_eq(strong.battery, before, "and was not in its Pod to recharge")
	assert_true(state.synths[0].battery > 0.0, "the rest recharged")


func test_defenders_wait_inside_tanks_nearest_the_door() -> void:
	var data := TestFixtures.data()
	var field := Battle.Field.bare(data.combat)
	field.wall_off(4)
	var shooter := Battle.Fighter.make("", 1.0, 10.0, CombatConfig.RANGED)
	var tank := Battle.Fighter.make("", 1.0, 10.0, CombatConfig.TANK)
	Battle.setup([] as Array[Battle.Fighter], [shooter, tank] as Array[Battle.Fighter], data, field)
	assert_true(tank.cell.y < field.door.y and maxi(absi(tank.cell.x - 4), absi(tank.cell.y - field.door.y)) == 1,
		"the tank right inside the door")
	assert_true(shooter.cell.y < field.door.y and shooter.cell != tank.cell, "the shooter inside too")


func test_attackers_walk_in_and_the_fight_starts_at_the_door() -> void:
	var data := TestFixtures.data({"battle_damage_variance": 0.0})
	var field := Battle.Field.bare(data.combat)
	field.wall_off(0)
	var raider := Battle.Fighter.make("a", 5.0, 100.0, CombatConfig.RANGED)
	raider.cell = Vector2i(7, 2)  # the far corner of the street
	var guard := Battle.Fighter.make("", 5.0, 100.0, CombatConfig.RANGED)
	var report := Battle.run([raider] as Array[Battle.Fighter], [guard] as Array[Battle.Fighter], RandomNumberGenerator.new(),
		data, field)
	assert_true(report.engaged_at > 0.0, "the fight waited for the raider to reach the door")
	var first_attack: Battle.Event = report.events.filter(func(e: Battle.Event) -> bool: return e.kind == Battle.Event.ATTACK)[0]
	assert_true(first_attack.time >= report.engaged_at, "nobody shot before that")
	for event: Battle.Event in report.events:
		if event.kind == Battle.Event.MOVE:
			assert_true(not field.walls.has(event.to), "nobody walks through the wall")


func test_a_megabean_raid_is_fought_in_the_players_cafe() -> void:
	var data := TestFixtures.data({"defense_base_chance": 1.0, "start_security": 0.0})
	var state := GameState.new_game(1, data)
	var home := state.add_synth("worker", "", data)
	home.battery = 50.0
	GameLoop.advance(state, data.balance.shift_seconds, data)
	var report := GameLoop.end_night(state, data)
	var field := report.defense.field
	assert_eq(field.board.x, state.floor_width, "as wide as the café")
	assert_eq(field.split, state.floor_rows + 1, "its floor, then the front wall")
	assert_eq(field.door.x, Layout.door_cell(state).x, "the café's own door")
	assert_eq(field.pieces.size(), state.placed.size(), "its own furniture")
