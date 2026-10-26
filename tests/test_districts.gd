extends TestCase
## District takeover (Influence, flagship, income, next district) and the Corporate Audit.
## Data from TestFixtures: "town" needs 3 Influence, then "city" needs 2.


## A game whose first shift just closed, with a charged worker (10 power, 30 hp).
func _night(data: GameData) -> Array:
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	var raider := state.add_synth("worker", "", data)
	return [state, raider]


func _ids(synth: Synth) -> Array[String]:
	return [synth.id] as Array[String]


func test_won_raid_earns_influence() -> void:
	var data := TestFixtures.data()
	var setup := _night(data)
	var state: GameState = setup[0]
	GameLoop.plan_raid(state, "weak", _ids(setup[1]), data)
	var report := GameLoop.end_night(state, data)
	assert_eq(report.influence_gained, 1, "reported")
	assert_eq(state.current_influence(), 1, "town Influence")


func test_flagship_is_locked_until_enough_influence() -> void:
	var data := TestFixtures.data()
	var setup := _night(data)
	var state: GameState = setup[0]
	assert_eq(GameLoop.plan_raid(state, "hq", _ids(setup[1]), data), GameLoop.FLAGSHIP_LOCKED, "locked at 0")
	assert_true(not NightOps.raid_targets(state, data).any(func(r: RivalCafe) -> bool: return r.id == "hq"), "not listed")
	state.influence["town"] = 3
	assert_true(NightOps.raid_targets(state, data).any(func(r: RivalCafe) -> bool: return r.id == "hq"), "listed at 3")
	assert_eq(GameLoop.plan_raid(state, "hq", _ids(setup[1]), data), GameLoop.OK, "unlocked")


func test_beating_the_flagship_takes_the_district() -> void:
	var data := TestFixtures.data()
	var setup := _night(data)
	var state: GameState = setup[0]
	state.influence["town"] = 3
	state.add_suspicion(30.0)
	GameLoop.plan_raid(state, "hq", _ids(setup[1]), data)
	var coins := state.coins
	var report := GameLoop.end_night(state, data)
	assert_true(report.raid.attackers_won, "flagship beaten")
	assert_eq(report.district_taken, "town", "town taken")
	assert_eq(report.next_district, "city", "city opens")
	assert_eq(state.owned_districts, ["town"] as Array[String], "owned")
	assert_eq(state.district_id, "city", "now contesting the city")
	assert_eq(state.district_started_day, state.day, "city opened today")
	assert_eq(state.current_suspicion(), 0.0, "fresh Suspicion in the city")
	assert_eq(report.income, 50, "town pays from the first night")
	assert_eq(state.coins, coins + 100 + 50, "flagship loot + income")
	assert_eq(GameLoop.plan_raid(state, "weak", _ids(setup[1]), data), GameLoop.WRONG_PHASE, "day")


func test_owned_districts_pay_every_night() -> void:
	var data := TestFixtures.data()
	var state: GameState = _night(data)[0]
	state.owned_districts.append("town")
	var coins := state.coins
	var report := GameLoop.end_night(state, data)
	assert_eq(report.income, 50, "income")
	assert_eq(state.coins, coins + 50, "paid")


func test_taking_the_last_district_wins_the_city() -> void:
	var data := TestFixtures.data()
	var setup := _night(data)
	var state: GameState = setup[0]
	state.owned_districts.append("town")
	state.district_id = "city"
	state.influence["city"] = 2
	assert_true(not state.owns_city(data), "not yet")
	GameLoop.plan_raid(state, "tower", _ids(setup[1]), data)
	var report := GameLoop.end_night(state, data)
	assert_eq(report.district_taken, "city", "city taken")
	assert_eq(report.next_district, "", "nothing left")
	assert_true(state.owns_city(data), "whole city owned")
	assert_eq(state.district_id, "city", "stays in the last district")
	assert_eq(report.income, 150, "both districts pay")
	GameLoop.advance(state, data.balance.shift_seconds, data)
	assert_eq(GameLoop.plan_raid(state, "tower", _ids(setup[1]), data), GameLoop.FLAGSHIP_LOCKED, "no boss to fight again")


func test_rival_guards_grow_from_when_the_district_opened() -> void:
	var data := TestFixtures.data({"rival_growth_per_day": 0.5})
	var state := GameState.new_game(1, data)
	state.day = 10
	state.district_started_day = 8
	var guards := NightOps.rival_guards(data.districts["city"].rival_by_id("shop"), NightOps.days_open(state), data.balance)
	assert_eq(guards[0].power, 2.0, "2 days open: x2")


func test_lost_audit_costs_coins_a_synth_and_a_day() -> void:
	var data := TestFixtures.data()
	var setup := _night(data)
	var state: GameState = setup[0]
	setup[1].battery = 0.0
	state.add_suspicion(95.0)
	state.coins = 200
	var report := GameLoop.end_night(state, data)
	assert_true(report.audit, "Corporate Audit")
	assert_eq(report.defense.attackers.size(), 2, "audit squad")
	assert_eq(report.defense.attackers[0].power, 10.0, "x2 strength")
	assert_true(report.defense.attackers_won, "nobody could defend")
	assert_eq(report.coins_lost, 100, "half the coins")
	assert_eq(state.synths.size(), 1, "one Synth taken")
	assert_true(report.synth_lost != "" and state.synth_by_id(report.synth_lost) == null, "reported")
	assert_eq(state.current_suspicion(), 40.0, "Suspicion reset")
	assert_true(report.closed_next_shift and state.closed, "shut tomorrow")
	var events := GameLoop.advance(state, 1, data)
	assert_true(events.closed and events.shift_ended, "the shut shift ends at once")
	assert_eq(state.phase, GameState.Phase.NIGHT, "straight to night")
	assert_true(not state.closed, "open again after")


func test_audit_never_takes_the_last_synth() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	state.add_suspicion(95.0)
	var report := GameLoop.end_night(state, data)
	assert_true(report.audit and report.defense.attackers_won, "lost")
	assert_eq(report.synth_lost, "", "kept the only Synth")
	assert_eq(state.synths.size(), 1, "still one")


func test_survived_audit_costs_nothing() -> void:
	var data := TestFixtures.data({"start_security": 500.0})
	var setup := _night(data)
	var state: GameState = setup[0]
	state.add_suspicion(95.0)
	var coins := state.coins
	var report := GameLoop.end_night(state, data)
	assert_true(report.audit and not report.defense.attackers_won, "held")
	assert_eq(state.coins, coins, "nothing lost")
	assert_eq(state.synths.size(), 2, "everyone stays")
	assert_true(not state.closed, "open tomorrow")
	assert_eq(state.current_suspicion(), 40.0, "Suspicion reset anyway")


func test_district_progress_survives_saving() -> void:
	var data := TestFixtures.data()
	var path := "user://test_saves/districts.json"
	var state := GameState.new_game(1, data)
	state.owned_districts.append("town")
	state.district_id = "city"
	state.district_started_day = 1
	state.influence = {"town": 3, "city": 1} as Dictionary[String, int]
	state.closed = true
	SaveSystem.save(state, path)
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(SaveSystem.to_dict(loaded), SaveSystem.to_dict(state), "same data")


func test_version_1_save_is_migrated() -> void:
	var data := TestFixtures.data()
	var path := "user://test_saves/old.json"
	var raw := SaveSystem.to_dict(GameState.new_game(1, data))
	for key: String in ["district_started_day", "owned_districts", "influence", "closed"]:
		raw.erase(key)
	for synth: Dictionary in raw["synths"]:
		synth.erase("level")
		synth.erase("xp")
	raw["seats"] = 2
	raw["pods"] = 2
	for key: String in ["floor_rows", "placed", "storage"]:
		raw.erase(key)
	raw["version"] = 1
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.district_started_day, 1, "default start day")
		assert_true(loaded.owned_districts.is_empty() and loaded.influence.is_empty(), "nothing owned")
		assert_eq(loaded.synths[0].level, 1, "v1 -> v2 -> v3: level 1")
