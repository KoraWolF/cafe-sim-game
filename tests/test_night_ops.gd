extends TestCase
## Night Ops: raids, MegaBean defense, Kleptomaniacs, recharging and the next day.


## A game whose first shift just closed.
func _night(data: GameData) -> GameState:
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	assert_eq(state.phase, GameState.Phase.NIGHT, "setup: night")
	return state


func test_battle_strong_beats_weak() -> void:
	var data := TestFixtures.data()
	var rng := RandomNumberGenerator.new()
	var strong: Array[Battle.Fighter] = [Battle.Fighter.make("a", 10.0, 30.0)]
	var weak: Array[Battle.Fighter] = [Battle.Fighter.make("", 1.0, 5.0)]
	var report := Battle.run(strong, weak, rng, data.balance)
	assert_true(report.attackers_won, "strong wins")
	assert_eq(report.rounds, 1, "one hit is enough")
	assert_eq(report.hits.size(), 1, "the knocked-out defender does not hit back")
	assert_true(report.hits[0].knocked_out, "knock-out recorded")


func test_battle_timeout_goes_to_defenders() -> void:
	var data := TestFixtures.data()
	var rng := RandomNumberGenerator.new()
	var a: Array[Battle.Fighter] = [Battle.Fighter.make("a", 1.0, 1000.0)]
	var d: Array[Battle.Fighter] = [Battle.Fighter.make("", 1.0, 1000.0)]
	var report := Battle.run(a, d, rng, data.balance)
	assert_eq(report.rounds, 10, "max rounds")
	assert_true(not report.attackers_won, "defenders hold")


func test_night_recharges_with_power_and_opens_next_day() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var starter := state.synths[0]
	assert_eq(starter.battery, 0.0, "drained 100 over the shift")
	starter.charging = true  # as if it rested in its Pod at closing
	var report := GameLoop.end_night(state, data)
	# 100 points * 0.1 Power = 10 Power: exactly the starting 10.
	assert_eq(starter.battery, 100.0, "recharged")
	assert_eq(report.power_used, 10.0, "power used")
	assert_eq(state.day, 2, "next day")
	assert_eq(state.phase, GameState.Phase.SHIFT, "shift open")
	assert_eq(state.shift_time, 0, "clock reset")
	assert_true(GameLoop.end_night(state, data) == null, "cannot end a night during a shift")


func test_partial_recharge_without_power() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	state.power = 4.0
	state.synths[0].charging = true
	var report := GameLoop.end_night(state, data)
	assert_eq(state.synths[0].battery, 40.0, "only 40 points for 4 Power")
	assert_eq(state.power, 0.0, "power gone")
	assert_eq(report.undercharged, [state.synths[0].id] as Array[String], "reported")


func test_only_synths_resting_at_closing_recharge() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var resting := state.add_synth("worker", "", data)
	resting.role = Synth.REST
	resting.battery = 10.0
	GameLoop.advance(state, data.balance.shift_seconds, data)
	var worker := state.synths[0]
	assert_true(not worker.charging and resting.charging, "setup: only the resting one charges")
	var report := GameLoop.end_night(state, data)
	assert_eq(worker.battery, 0.0, "worked until closing: not recharged")
	assert_eq(report.not_in_pod, [worker.id] as Array[String], "reported")
	assert_true(resting.battery > 10.0, "the resting one recharged")
	assert_true(worker.charging, "next night it can charge again")


func test_buy_power() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.buy_power(state, 10, data), GameLoop.OK, "bought")
	assert_eq(state.coins, 80, "2 coins each")
	assert_eq(state.power, 20.0, "power")
	assert_eq(GameLoop.buy_power(state, 0, data), GameLoop.BAD_AMOUNT, "zero")
	assert_eq(GameLoop.buy_power(state, 1000, data), GameLoop.NOT_ENOUGH_COINS, "too much")


func test_raid_win_gives_loot_suspicion_and_cooldown() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var raider := state.add_synth("worker", "klepto", data)
	state.power = 100.0
	assert_eq(GameLoop.plan_raid(state, "weak", [raider.id] as Array[String], data), GameLoop.OK, "planned")
	var coins := state.coins
	var report := GameLoop.end_night(state, data)
	assert_true(report.raid.attackers_won, "won")
	assert_eq(report.loot_coins, 60, "40 coins +50% klepto bonus")
	assert_eq(report.loot_cores, 1, "core")
	assert_eq(state.cores, 1, "core kept")
	assert_eq(report.stolen.get(raider.id, 0), 10, "klepto pockets coins")
	assert_eq(state.coins, coins + 60 - 10, "coins after loot and theft")
	assert_eq(state.current_suspicion(), 15.0, "+20 for the raid, -5 overnight")
	assert_eq(raider.battery, 50.0, "raid cost recharged overnight")
	assert_true(state.raid_target == "" and state.raid_squad.is_empty(), "plan cleared")
	assert_true(not NightOps.raid_targets(state, data).any(func(r: RivalCafe) -> bool: return r.id == "weak"),
		"weak is on cooldown")


func test_raid_loss_gives_nothing_but_costs_battery() -> void:
	var data := TestFixtures.data({"start_power": 0.0})
	var state := _night(data)
	var raider := state.add_synth("worker", "", data)
	GameLoop.plan_raid(state, "fort", [raider.id] as Array[String], data)
	var report := GameLoop.end_night(state, data)
	assert_true(not report.raid.attackers_won, "lost")
	assert_eq(report.loot_coins, 0, "no loot")
	assert_eq(raider.battery, 25.0, "spent 25 battery, no Power to recharge")
	assert_eq(state.current_suspicion(), 0.0, "no suspicion for a failed raid")


func test_plan_raid_errors() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var starter := state.synths[0].id
	assert_eq(GameLoop.plan_raid(state, "weak", [starter] as Array[String], data), GameLoop.WRONG_PHASE, "day")
	state = _night(data)
	starter = state.synths[0].id
	assert_eq(GameLoop.plan_raid(state, "moon", [starter] as Array[String], data), GameLoop.UNKNOWN_TARGET, "target")
	assert_eq(GameLoop.plan_raid(state, "weak", [] as Array[String], data), GameLoop.EMPTY_SQUAD, "empty")
	assert_eq(GameLoop.plan_raid(state, "weak", [starter] as Array[String], data), GameLoop.NO_BATTERY, "drained")
	var a := state.add_synth("worker", "", data).id
	var b := state.add_synth("worker", "", data).id
	assert_eq(GameLoop.plan_raid(state, "weak", [a, b, starter] as Array[String], data), GameLoop.SQUAD_TOO_BIG, "max 2")
	state.raid_cooldowns["weak"] = state.day + 1
	assert_eq(GameLoop.plan_raid(state, "weak", [a] as Array[String], data), GameLoop.TARGET_COOLDOWN, "cooldown")


func test_lost_defense_costs_coins_and_a_core() -> void:
	var data := TestFixtures.data({"defense_base_chance": 1.0})
	var state := _night(data)
	state.cores = 2
	var coins := state.coins
	# The only Synth is drained, so nobody defends.
	var report := GameLoop.end_night(state, data)
	assert_true(report.defense != null, "MegaBean came")
	assert_true(report.defense.defenders.is_empty(), "nobody home with battery")
	assert_true(report.defense.attackers_won, "lost")
	assert_eq(report.coins_lost, coins / 2, "half the coins")
	assert_eq(state.cores, 1, "one core taken")


func test_home_synths_defend() -> void:
	var data := TestFixtures.data({"defense_base_chance": 1.0, "start_security": 100.0})
	var state := _night(data)
	state.add_synth("worker", "owl", data)
	var coins := state.coins
	var report := GameLoop.end_night(state, data)
	assert_eq(report.defense.defenders.size(), 1, "the charged Synth defends")
	assert_eq(report.defense.defenders[0].max_hp, 130.0, "30 hp + 100 security")
	assert_true(not report.defense.attackers_won, "held")
	assert_eq(state.coins, coins, "nothing lost")


func test_defense_chance_grows_with_suspicion() -> void:
	var data := TestFixtures.data({"defense_base_chance": 0.1, "defense_chance_per_suspicion": 0.01,
		"defense_max_chance": 0.5})
	var state := GameState.new_game(1, data)
	assert_eq(NightOps.defense_chance(state, data.balance), 0.1, "base")
	state.add_suspicion(20.0)
	assert_true(is_equal_approx(NightOps.defense_chance(state, data.balance), 0.3), "+0.01 per point")
	state.add_suspicion(100.0)
	assert_eq(state.current_suspicion(), 100.0, "capped at 100")
	assert_eq(NightOps.defense_chance(state, data.balance), 0.5, "capped chance")


func test_rival_guards_grow_every_day() -> void:
	var data := TestFixtures.data({"rival_growth_per_day": 0.5})
	var weak := data.districts["town"].rival_by_id("weak")
	var guards := NightOps.rival_guards(weak, 2, data.balance)
	assert_eq(guards[0].power, 2.0, "power x2 on day 2")
	assert_eq(guards[0].max_hp, 10.0, "hp x2 on day 2")
