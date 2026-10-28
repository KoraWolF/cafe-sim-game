extends TestCase
## Grid battles (auto-chess style): placement by formation or class, walking to
## the target, range, armor, skills from mana, the time limit, and the playback
## rebuilding every moment from the events.
## Combat data: the defaults in CombatConfig (8 x 6 board; fighter range 1,
## 1 attack/s, 2 tiles/s, armor 0.15; ranged range 3; tank armor 0.3).


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng


func test_placement_by_formation_and_by_class() -> void:
	var data := TestFixtures.data()
	var tank := Battle.Fighter.make("a", 5.0, 50.0, CombatConfig.TANK)
	var ranged := Battle.Fighter.make("b", 5.0, 20.0, CombatConfig.RANGED)
	var placed := Battle.Fighter.make("c", 5.0, 20.0)
	placed.cell = Vector2i(0, 1)
	var guard := Battle.Fighter.make("", 1.0, 5.0)
	var report := Battle.run([tank, ranged, placed] as Array[Battle.Fighter], [guard] as Array[Battle.Fighter], _rng(), data)
	assert_eq(report.attackers[0].cell, Vector2i(3, 3), "a tank: attackers' front row (row 3), middle column")
	assert_eq(report.attackers[1].cell, Vector2i(3, 5), "ranged: the back row")
	assert_eq(report.attackers[2].cell, Vector2i(0, 4), "its own spot: column 0, second row")
	assert_eq(report.defenders[0].cell, Vector2i(3, 2), "a defender: the defenders' front row, facing them")


func test_units_walk_into_range_then_attack() -> void:
	var data := TestFixtures.data({"battle_damage_variance": 0.0})
	var a := Battle.Fighter.make("a", 10.0, 100.0)
	var d := Battle.Fighter.make("", 1.0, 10.0)
	d.cell = Vector2i(3, 2)  # the defenders' back row
	var report := Battle.run([a] as Array[Battle.Fighter], [d] as Array[Battle.Fighter], _rng(), data)
	var kinds := report.events.map(func(event: Battle.Event) -> String: return event.kind)
	assert_true(kinds.find(Battle.Event.MOVE) >= 0 and kinds.find(Battle.Event.MOVE) < kinds.find(Battle.Event.ATTACK),
		"walks first, then attacks")
	var first_hit: Battle.Event = report.events.filter(func(e: Battle.Event) -> bool: return e.kind == Battle.Event.HIT)[0]
	assert_true(is_equal_approx(first_hit.amount, 10.0 * (1.0 - 0.15)), "power less the fighter's 15% armor")
	assert_true(report.attackers_won, "won")
	assert_eq(report.events[-1].kind, Battle.Event.DOWN, "ends when the last defender is down")


func test_ranged_attacks_from_afar() -> void:
	var data := TestFixtures.data()
	var shooter := Battle.Fighter.make("a", 5.0, 100.0, CombatConfig.RANGED)
	var dummy := Battle.Fighter.make("", 0.0, 1000.0)
	var report := Battle.run([shooter] as Array[Battle.Fighter], [dummy] as Array[Battle.Fighter], _rng(), data)
	var attack: Battle.Event = report.events.filter(func(e: Battle.Event) -> bool:
		return e.kind == Battle.Event.ATTACK and e.side)[0]
	var playback := BattlePlayback.new(report)
	var at := playback.unit_position(true, 0, attack.time)
	var target := playback.unit_position(false, 0, attack.time)
	assert_true(maxf(absf(at.x - target.x), absf(at.y - target.y)) > 1.5, "shoots from more than a tile away")


func test_full_mana_casts_the_skill() -> void:
	var data := TestFixtures.data()
	var healer := Battle.Fighter.make("a", 1.0, 100.0, CombatConfig.RANGED, "cheer")
	var tank := Battle.Fighter.make("b", 1.0, 200.0, CombatConfig.TANK, "slam")
	var guards: Array[Battle.Fighter] = [Battle.Fighter.make("", 6.0, 400.0), Battle.Fighter.make("", 6.0, 400.0)]
	var report := Battle.run([healer, tank] as Array[Battle.Fighter], guards, _rng(), data)
	var casts := report.events.filter(func(e: Battle.Event) -> bool: return e.kind == Battle.Event.CAST)
	assert_true(casts.any(func(e: Battle.Event) -> bool: return e.skill == "cheer"), "the healer cheered")
	assert_true(casts.any(func(e: Battle.Event) -> bool: return e.skill == "slam"), "the tank slammed")
	assert_true(report.events.any(func(e: Battle.Event) -> bool: return e.kind == Battle.Event.HEAL), "someone was healed")
	assert_true(report.events.any(func(e: Battle.Event) -> bool: return e.kind == Battle.Event.STUN), "someone was stunned")


func test_time_limit_goes_to_defenders() -> void:
	var data := TestFixtures.data()
	var a := Battle.Fighter.make("a", 1.0, 100000.0)
	var d := Battle.Fighter.make("", 1.0, 100000.0)
	var report := Battle.run([a] as Array[Battle.Fighter], [d] as Array[Battle.Fighter], _rng(), data)
	assert_eq(report.duration, data.combat.max_seconds, "the full time")
	assert_true(not report.attackers_won, "defenders hold")


func test_same_seed_same_battle() -> void:
	var data := TestFixtures.data()
	var make := func() -> Battle.Report:
		var a: Array[Battle.Fighter] = [Battle.Fighter.make("a", 6.0, 30.0, CombatConfig.FRAGILE, "chain"),
			Battle.Fighter.make("b", 9.0, 40.0, CombatConfig.TANK, "slam")]
		var d: Array[Battle.Fighter] = [Battle.Fighter.make("", 7.0, 35.0),
			Battle.Fighter.make("", 5.0, 40.0, CombatConfig.RANGED)]
		return Battle.run(a, d, _rng(), data)
	var one: Battle.Report = make.call()
	var two: Battle.Report = make.call()
	assert_eq(one.events.size(), two.events.size(), "same events")
	assert_eq(one.attackers_won, two.attackers_won, "same winner")


func test_playback_ends_where_the_battle_did() -> void:
	var data := TestFixtures.data({"battle_damage_variance": 0.3})
	for seed_value: int in [1, 2, 3]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var a: Array[Battle.Fighter] = [Battle.Fighter.make("a", 6.0, 30.0, CombatConfig.FIGHTER, "fortify"),
			Battle.Fighter.make("b", 9.0, 20.0, CombatConfig.RANGED, "cheer")]
		var d: Array[Battle.Fighter] = [Battle.Fighter.make("", 7.0, 25.0, CombatConfig.TANK),
			Battle.Fighter.make("", 5.0, 40.0)]
		var report := Battle.run(a, d, rng, data)
		var playback := BattlePlayback.new(report)
		assert_eq(playback.unit_state(true, 0, -0.01)["hp"], 30.0, "starts at full HP (a ranged shot can land at 0 s)")
		for side: bool in [true, false]:
			var fighters := report.attackers if side else report.defenders
			for i: int in fighters.size():
				var end := playback.unit_state(side, i, report.duration)
				assert_true(is_equal_approx(end["hp"], fighters[i].hp), "seed %d: ends as recorded" % seed_value)
				assert_eq(end["anim"] == "down", fighters[i].hp <= 0.0, "down exactly when knocked out")


func test_formation_spots_swap_and_save() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var other := state.add_synth("worker", "", data)
	var first := state.synths[0]
	assert_eq(GameLoop.set_formation(state, first.id, Vector2i(9, 0), data), GameLoop.OUT_OF_BOUNDS, "off the board")
	assert_eq(GameLoop.set_formation(state, first.id, Vector2i(0, 0), data), GameLoop.OK, "placed")
	GameLoop.set_formation(state, other.id, Vector2i(1, 2), data)
	assert_eq(GameLoop.set_formation(state, other.id, Vector2i(0, 0), data), GameLoop.OK, "onto the first one's spot")
	assert_eq(state.formation[first.id], Vector2i(1, 2), "they swapped")
	var path := "user://test_saves/formation.json"
	SaveSystem.save(state, path)
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.formation[other.id], Vector2i(0, 0), "saved")
