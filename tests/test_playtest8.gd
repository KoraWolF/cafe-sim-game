extends TestCase
## Playtest 8: a stove stacks dishes (one cooking, the rest waiting), staff
## work only once they have walked to their station, and battles are fought at
## cafés with one door (the defenders walk out; the fight is on the street).


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


func test_workers_above_70_percent_are_ticked_and_fighters_recharge_half() -> void:
	var data := TestFixtures.data({"defense_base_chance": 1.0, "start_security": 1000.0})
	var state := GameState.new_game(1, data)
	var strong := state.add_synth("worker", "", data)
	var weak := state.add_synth("worker", "", data)
	strong.role = Synth.REST
	weak.battery = 10.0
	weak.role = Synth.SERVER
	GameLoop.advance(state, data.balance.shift_seconds, data)
	assert_true(state.defenders.has(strong.id), "above 70%: ticked")
	assert_true(not state.defenders.has(weak.id), "below it: not ticked")
	state.defenders = [strong.id] as Array[String]
	strong.battery = 50.0
	state.power = 1000.0
	var missing := SynthStats.stat(strong, "battery_max", data) - strong.battery
	var report := GameLoop.end_night(state, data)
	assert_eq(report.defense.defenders.size(), 1, "it defended")
	assert_true(is_equal_approx(strong.battery, 50.0 + missing * 0.5), "and got back half its missing battery")


func test_defenders_wait_inside_tanks_nearest_the_door() -> void:
	var data := TestFixtures.data()
	var field := Battle.Field.bare(data.combat)
	field.wall_off(4, 1)
	var shooter := Battle.Fighter.make("", 1.0, 10.0, CombatConfig.RANGED)
	var tank := Battle.Fighter.make("", 1.0, 10.0, CombatConfig.TANK)
	Battle.setup([] as Array[Battle.Fighter], [shooter, tank] as Array[Battle.Fighter], data, field)
	assert_true(tank.cell.y < field.door.y and maxi(absi(tank.cell.x - 4), absi(tank.cell.y - field.door.y)) == 1,
		"the tank right inside the door")
	assert_true(shooter.cell.y < field.door.y and shooter.cell != tank.cell, "the shooter inside too")


func test_defenders_walk_out_and_the_fight_is_on_the_street() -> void:
	var data := TestFixtures.data({"battle_damage_variance": 0.0})
	var field := Battle.Field.bare(data.combat)
	field.wall_off(0, 1)  # the café is row 0, the street rows 2 on
	var raider := Battle.Fighter.make("a", 5.0, 100.0, CombatConfig.FIGHTER)
	raider.cell = Vector2i(7, 2)  # the far corner of the attackers' rows
	var guard := Battle.Fighter.make("", 5.0, 100.0, CombatConfig.FIGHTER)
	var report := Battle.run([raider] as Array[Battle.Fighter], [guard] as Array[Battle.Fighter], RandomNumberGenerator.new(),
		data, field)
	assert_true(report.engaged_at > 0.0, "the fight waited for the guard to come out")
	var first_attack: Battle.Event = report.events.filter(func(e: Battle.Event) -> bool: return e.kind == Battle.Event.ATTACK)[0]
	assert_true(first_attack.time >= report.engaged_at, "nobody struck before that")
	for event: Battle.Event in report.events:
		if event.kind == Battle.Event.MOVE:
			assert_true(not field.walls.has(event.to), "nobody walks through the wall")
			if event.side:
				assert_true(field.outside(event.to), "the raider never goes in")


func test_a_megabean_raid_is_fought_in_the_players_cafe() -> void:
	var data := TestFixtures.data({"defense_base_chance": 1.0, "start_security": 0.0})
	var state := GameState.new_game(1, data)
	var home := state.add_synth("worker", "", data)
	home.battery = 50.0
	GameLoop.advance(state, data.balance.shift_seconds, data)
	var report := GameLoop.end_night(state, data)
	var field := report.defense.field
	assert_eq(field.board.x, state.floor_width, "as wide as the café")
	assert_eq(field.door.y, state.floor_rows, "its floor, then the front wall")
	assert_eq(field.split, state.floor_rows + 1 + RaidField.STREET_ROWS, "then the street")
	assert_eq(field.door.x, Layout.door_cell(state).x, "the café's own door")
	assert_eq(field.pieces.size(), state.placed.size(), "its own furniture")
