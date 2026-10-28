extends TestCase
## Synth XP and levels. Data from TestFixtures: level n -> n + 1 costs 100 * n,
## max level 3, +50% of base per level.


func test_xp_levels_up_with_carry_over() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var synth := state.synths[0]
	var ups: Dictionary[String, int] = {}
	Leveling.add_xp(synth, 130, data.balance, ups)
	assert_eq(synth.level, 2, "level 2 at 100")
	assert_eq(synth.xp, 30, "30 carried over")
	assert_eq(ups, {synth.id: 2} as Dictionary[String, int], "reported")
	Leveling.add_xp(synth, 1000, data.balance, ups)
	assert_eq(synth.level, 3, "capped at max level")
	assert_eq(synth.xp, 0, "no XP kept at max")
	assert_eq(ups[synth.id], 3, "last level reported")


func test_levels_grow_work_and_combat_stats_only() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var owl := state.add_synth("worker", "owl", data)
	owl.level = 3
	assert_eq(SynthStats.stat(owl, "speed", data), 4.0, "speed 2 x (1 + 2 x 0.5)")
	assert_eq(SynthStats.stat(owl, "power", data), 25.0, "power 10 x 2 + 5 from the trait (not grown)")
	assert_eq(SynthStats.stat(owl, "drain", data), 0.5, "drain does not grow")
	assert_eq(SynthStats.stat(owl, "battery_max", data), 50.0, "battery does not grow")


func test_server_earns_xp_per_delivery() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 3
	GameLoop.advance(state, 8, data)
	assert_eq(state.synths[0].xp, 2, "one dish delivered")


func test_the_chef_at_the_stove_gets_batch_xp() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.synths[0].role = Synth.REST
	var a := state.add_synth("chef", "", data)
	var b := state.add_synth("chef", "", data)
	assert_eq(GameLoop.assign_to(state, a.id, state.stoves[0].piece_uid, data), GameLoop.OK, "a at stove 1")
	assert_eq(GameLoop.assign_to(state, b.id, state.stoves[1].piece_uid, data), GameLoop.OK, "b at stove 2")
	GameLoop.start_cooking(state, 0, "tea", data)
	var events := GameLoop.advance(state, 5, data)
	assert_eq(events.dishes_ready.size(), 1, "setup: batch done (speed 1 + cook 1)")
	assert_eq(a.xp, 6, "the stove's own Chef")
	assert_eq(b.xp, 0, "not the other Chef")


func test_cashiers_earn_xp_per_arrival() -> void:
	var data := TestFixtures.data({"start_registers": 1, "start_layout": [{"piece": "seat", "cell": [6, 0]},
		{"piece": "seat", "cell": [7, 0]}, {"piece": "table", "cell": [6, 1]}, {"piece": "table", "cell": [7, 1]}]})
	var state := GameState.new_game(1, data)
	var cashier := state.add_synth("worker", "", data)
	cashier.role = Synth.CASHIER
	GameLoop.advance(state, 4, data)
	assert_eq(cashier.station_uid, state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "register")[0].uid,
		"took the free register")
	assert_eq(cashier.xp, 1, "one arrival")


func test_night_ops_xp() -> void:
	var data := TestFixtures.data({"defense_base_chance": 1.0})
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, 100, data)
	var winner := state.add_synth("worker", "", data)
	var home := state.add_synth("worker", "", data)
	GameLoop.plan_raid(state, "weak", [winner.id] as Array[String], data)
	var report := GameLoop.end_night(state, data)
	assert_true(report.raid.attackers_won and report.defense != null, "setup: raid and defense")
	assert_eq(winner.xp, 30, "won raid")
	assert_eq(home.xp, 20, "defended")
	assert_eq(state.synths[0].xp, 0, "a drained Synth does not fight or earn")
	GameLoop.advance(state, 100, data)
	winner.battery = 50.0
	GameLoop.plan_raid(state, "fort", [winner.id] as Array[String], data)
	GameLoop.end_night(state, data)
	assert_eq(winner.xp, 30 + 15, "lost raid still earns 15")


func test_levels_survive_saving_and_bad_levels_are_refused() -> void:
	var data := TestFixtures.data()
	var path := "user://test_saves/levels.json"
	var state := GameState.new_game(1, data)
	state.synths[0].level = 2
	state.synths[0].xp = 150
	SaveSystem.save(state, path)
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.synths[0].level, 2, "level")
		assert_eq(loaded.synths[0].xp, 150, "xp")
	state.synths[0].level = 9
	SaveSystem.save(state, path)
	SaveSystem.save(state, path)
	errors.clear()
	assert_true(SaveSystem.load_file(path, data, errors) == null, "level above max refused")
	SaveSystem.delete_save(path)
