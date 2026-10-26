class_name NightOps
extends RefCounted
## Resolves a night, in order: the planned raid (if any), a possible MegaBean
## raid on the café (defended by Synths who stayed home), Kleptomaniacs
## pocketing coins, every Synth recharging in its Pod for Power, Suspicion
## falling, and the next day's shift opening.


class Report:
	extends RefCounted
	var raid_target: String = ""
	## null when there was no raid.
	var raid: Battle.Report = null
	var loot_coins: int = 0
	var loot_cores: int = 0
	## null when MegaBean did not come.
	var defense: Battle.Report = null
	var coins_lost: int = 0
	var cores_lost: int = 0
	## Synth id -> coins pocketed.
	var stolen: Dictionary[String, int] = {}
	var power_used: float = 0.0
	## Synths whose battery is not full after recharging (Power ran out).
	var undercharged: Array[String] = []


## Rivals in the current district that can be raided tonight.
static func raid_targets(state: GameState, data: GameData) -> Array[RivalCafe]:
	var result: Array[RivalCafe] = []
	for rival: RivalCafe in data.districts[state.district_id].rivals:
		if state.raid_cooldowns.get(rival.id, 0) <= state.day:
			result.append(rival)
	return result


## Chance MegaBean raids the café tonight.
static func defense_chance(state: GameState, b: BalanceConfig) -> float:
	return minf(b.defense_base_chance + state.current_suspicion() * b.defense_chance_per_suspicion, b.defense_max_chance)


## Power a full recharge of every Synth would cost now.
static func recharge_cost(state: GameState, data: GameData) -> float:
	var total := 0.0
	for synth: Synth in state.synths:
		total += _missing_battery(synth, data) * _power_per_point(synth, data)
	return total


static func resolve(state: GameState, data: GameData) -> Report:
	var b := data.balance
	var report := Report.new()
	var rng := state.rng()
	if state.raid_target != "":
		_raid(state, data, rng, report)
	if rng.randf() < defense_chance(state, b):
		_defend(state, data, rng, report)
	_steal(state, data, rng, report)
	_recharge(state, data, report)
	state.add_suspicion(-b.suspicion_decay)
	state.store_rng(rng)
	state.raid_target = ""
	state.raid_squad.clear()
	state.day += 1
	state.phase = GameState.Phase.SHIFT
	state.shift_time = 0
	state.next_arrival = b.first_arrival_seconds
	return report


## A rival's guards on this day (they grow stronger every day).
static func rival_guards(rival: RivalCafe, day: int, b: BalanceConfig) -> Array[Battle.Fighter]:
	var growth := 1.0 + b.rival_growth_per_day * day
	var guards: Array[Battle.Fighter] = []
	for defender: Dictionary in rival.defenders:
		guards.append(Battle.Fighter.make("", defender["power"] * growth, defender["hp"] * growth))
	return guards


static func synth_fighter(synth: Synth, extra_hp: float, data: GameData) -> Battle.Fighter:
	# Low battery fights at the same reduced strength as it works.
	var power := SynthStats.stat(synth, "power", data) * SynthStats.battery_factor(synth, data)
	return Battle.Fighter.make(synth.id, power, SynthStats.stat(synth, "hp", data) + extra_hp)


static func _raid(state: GameState, data: GameData, rng: RandomNumberGenerator, report: Report) -> void:
	var b := data.balance
	var rival := data.districts[state.district_id].rival_by_id(state.raid_target)
	report.raid_target = rival.id
	var squad: Array[Battle.Fighter] = []
	var loot_bonus := 0.0
	for synth_id: String in state.raid_squad:
		var synth := state.synth_by_id(synth_id)
		squad.append(synth_fighter(synth, 0.0, data))
		loot_bonus += SynthStats.stat(synth, "raid_loot", data)
		synth.battery = maxf(synth.battery - b.raid_battery_cost, 0.0)
	var guards := rival_guards(rival, state.day, b)
	report.raid = Battle.run(squad, guards, rng, b)
	state.raid_cooldowns[rival.id] = state.day + b.raid_cooldown_days
	if not report.raid.attackers_won:
		return
	report.loot_coins = roundi(rival.loot_coins * (1.0 + maxf(loot_bonus, 0.0)))
	report.loot_cores = rival.loot_cores
	state.coins += report.loot_coins
	state.cores += report.loot_cores
	state.add_suspicion(b.raid_suspicion)


static func _defend(state: GameState, data: GameData, rng: RandomNumberGenerator, report: Report) -> void:
	var b := data.balance
	var size := mini(1 + int(state.current_suspicion() / maxf(b.defense_size_step, 1.0)), b.defense_max_size)
	var raiders: Array[Battle.Fighter] = []
	for i: int in size:
		raiders.append(Battle.Fighter.make("", b.defense_power_base + b.defense_power_per_day * state.day,
			b.defense_hp_base + b.defense_hp_per_day * state.day))
	var home: Array[Battle.Fighter] = []
	for synth: Synth in state.synths:
		if not state.raid_squad.has(synth.id) and synth.battery > 0.0:
			home.append(synth_fighter(synth, state.security, data))
	report.defense = Battle.run(raiders, home, rng, b)
	if not report.defense.attackers_won:
		return
	report.coins_lost = int(state.coins * b.defense_coin_loss)
	report.cores_lost = mini(state.cores, b.defense_core_loss)
	state.coins -= report.coins_lost
	state.cores -= report.cores_lost


static func _steal(state: GameState, data: GameData, rng: RandomNumberGenerator, report: Report) -> void:
	for synth: Synth in state.synths:
		var chance := SynthStats.stat(synth, "steal_chance", data)
		if chance <= 0.0 or rng.randf() >= chance:
			continue
		var amount := mini(data.balance.steal_coins, state.coins)
		if amount <= 0:
			continue
		state.coins -= amount
		report.stolen[synth.id] = amount


## Fills batteries in Synth order while Power lasts.
static func _recharge(state: GameState, data: GameData, report: Report) -> void:
	for synth: Synth in state.synths:
		var missing := _missing_battery(synth, data)
		if missing <= 0.0:
			continue
		var per_point := _power_per_point(synth, data)
		var points := missing if per_point <= 0.0 else minf(missing, state.power / per_point)
		synth.battery += points
		state.power = maxf(state.power - points * per_point, 0.0)
		report.power_used += points * per_point
		if points < missing:
			report.undercharged.append(synth.id)


static func _missing_battery(synth: Synth, data: GameData) -> float:
	return maxf(SynthStats.stat(synth, "battery_max", data) - synth.battery, 0.0)


static func _power_per_point(synth: Synth, data: GameData) -> float:
	return data.balance.power_per_battery * maxf(SynthStats.stat(synth, "recharge_multiplier", data), 0.0)
