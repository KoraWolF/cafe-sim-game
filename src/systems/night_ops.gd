class_name NightOps
extends RefCounted
## Resolves a night, in order: the planned raid (if any: a win earns loot and
## Influence, a won flagship raid takes the district over and opens the next),
## then either a Corporate Audit (Suspicion at audit_suspicion or more) or a
## possible MegaBean raid on the café (defended by Synths who stayed home),
## Kleptomaniacs pocketing coins, every Synth recharging in its Pod for Power,
## owned districts paying income, Suspicion falling, and the next shift opening
## (shut if the Audit was lost).


class Report:
	extends RefCounted
	var raid_target: String = ""
	## null when there was no raid.
	var raid: Battle.Report = null
	var loot_coins: int = 0
	var loot_cores: int = 0
	var influence_gained: int = 0
	## District taken over tonight ("" = none) and the district that opens next
	## ("" = none: the whole city is yours).
	var district_taken: String = ""
	var next_district: String = ""
	## null when MegaBean did not come.
	var defense: Battle.Report = null
	## True when tonight's raid on the café was a Corporate Audit.
	var audit: bool = false
	var coins_lost: int = 0
	var cores_lost: int = 0
	## Synth taken by a lost Audit ("" = none).
	var synth_lost: String = ""
	## True when the next shift is shut (lost Audit).
	var closed_next_shift: bool = false
	## Synth id -> coins pocketed.
	var stolen: Dictionary[String, int] = {}
	var power_used: float = 0.0
	## Synths whose battery is not full after recharging (Power ran out).
	var undercharged: Array[String] = []
	## Synths that were not in their Pod at closing: no recharge.
	var not_in_pod: Array[String] = []
	## Coins from owned districts.
	var income: int = 0
	## Synth id -> level reached (raiders and defenders earn XP).
	var level_ups: Dictionary[String, int] = {}
	## Won raid: Scrap and Chips, new equipment uids, an EXP bottle id ("" = none).
	var loot_scrap: int = 0
	var loot_chips: int = 0
	var loot_items: Array[String] = []
	var loot_bottle: String = ""
	## A dish unlocked tonight by a won raid or a held defense ("" = none).
	var new_dish: String = ""


## Cafés in the current district that can be raided tonight: rivals off
## cooldown, plus the flagship once Influence is high enough.
static func raid_targets(state: GameState, data: GameData) -> Array[RivalCafe]:
	var district := data.districts[state.district_id]
	var result: Array[RivalCafe] = []
	for rival: RivalCafe in district.rivals:
		if state.raid_cooldowns.get(rival.id, 0) <= state.day:
			result.append(rival)
	if flagship_unlocked(state, data) and state.raid_cooldowns.get(district.flagship.id, 0) <= state.day:
		result.append(district.flagship)
	return result


## True when the current district's flagship can be challenged.
static func flagship_unlocked(state: GameState, data: GameData) -> bool:
	var district := data.districts[state.district_id]
	return not state.owned_districts.has(district.id) and state.current_influence() >= district.influence_required


## Chance MegaBean raids the café tonight (ignoring the Audit).
static func defense_chance(state: GameState, b: BalanceConfig) -> float:
	return minf(b.defense_base_chance + state.current_suspicion() * b.defense_chance_per_suspicion, b.defense_max_chance)


## Power a full recharge of every Synth would cost now.
static func recharge_cost(state: GameState, data: GameData) -> float:
	var total := 0.0
	for synth: Synth in state.synths:
		total += _missing_battery(synth, data) * _power_per_point(synth, data)
	return total


## Coins owned districts pay each night.
static func daily_income(state: GameState, data: GameData) -> int:
	var total := 0
	for district_id: String in state.owned_districts:
		total += data.districts[district_id].income
	return total


static func resolve(state: GameState, data: GameData) -> Report:
	var b := data.balance
	var report := Report.new()
	var rng := state.rng()
	if state.raid_target != "":
		_raid(state, data, rng, report)
	if state.current_suspicion() >= b.audit_suspicion:
		_audit(state, data, rng, report)
	elif rng.randf() < defense_chance(state, b):
		_defend(state, data, rng, report)
	_steal(state, data, rng, report)
	_recharge(state, data, report)
	report.income = daily_income(state, data)
	state.coins += report.income
	if report.audit:
		state.suspicion[state.district_id] = b.audit_reset_suspicion
	else:
		state.add_suspicion(-b.suspicion_decay)
	state.store_rng(rng)
	state.raid_target = ""
	state.raid_squad.clear()
	state.day += 1
	state.phase = GameState.Phase.SHIFT
	state.shift_time = 0
	state.next_arrival = b.first_arrival_seconds
	state.closed = report.closed_next_shift
	return report


## A rival's guards after the district has been open this many days.
static func rival_guards(rival: RivalCafe, days_open: int, b: BalanceConfig) -> Array[Battle.Fighter]:
	var growth := 1.0 + b.rival_growth_per_day * maxi(days_open, 0)
	var guards: Array[Battle.Fighter] = []
	for defender: Dictionary in rival.defenders:
		guards.append(Battle.Fighter.make("", defender["power"] * growth, defender["hp"] * growth,
			defender.get("class", CombatConfig.FIGHTER)))
	return guards


## Tonight's guards of a café in the current district: rivals grow with the
## days the district has been open, the flagship keeps its fixed strength.
static func guards_for(state: GameState, rival: RivalCafe, data: GameData) -> Array[Battle.Fighter]:
	var district := data.districts[state.district_id]
	return rival_guards(rival, 0 if district.is_flagship(rival.id) else days_open(state), data.balance)


## Days the current district has been open (what rival guards grow with).
static func days_open(state: GameState) -> int:
	return state.day - state.district_started_day


static func synth_fighter(synth: Synth, extra_hp: float, data: GameData, state: GameState = null) -> Battle.Fighter:
	# Low battery fights at the same reduced strength as it works.
	var power := SynthStats.stat(synth, "power", data) * SynthStats.battery_factor(synth, data)
	var species := data.species[synth.species_id]
	var fighter := Battle.Fighter.make(synth.id, power, SynthStats.stat(synth, "hp", data) + extra_hp,
		species.combat_class, species.skill)
	if state != null:
		fighter.cell = state.formation.get(synth.id, Vector2i(-1, -1))
	return fighter


static func _raid(state: GameState, data: GameData, rng: RandomNumberGenerator, report: Report) -> void:
	var b := data.balance
	var district := data.districts[state.district_id]
	var rival := district.rival_by_id(state.raid_target)
	report.raid_target = rival.id
	var squad: Array[Battle.Fighter] = []
	var raiders: Array[Synth] = []
	var loot_bonus := 0.0
	for synth_id: String in state.raid_squad:
		var synth := state.synth_by_id(synth_id)
		raiders.append(synth)
		squad.append(synth_fighter(synth, 0.0, data, state))
		loot_bonus += SynthStats.stat(synth, "raid_loot", data)
		synth.battery = maxf(synth.battery - b.raid_battery_cost, 0.0)
	report.raid = Battle.run(squad, guards_for(state, rival, data), rng, data)
	state.raid_cooldowns[rival.id] = state.day + b.raid_cooldown_days
	for synth: Synth in raiders:
		Leveling.add_xp(synth, b.xp_raid_win if report.raid.attackers_won else b.xp_raid_loss, b, report.level_ups)
	if not report.raid.attackers_won:
		return
	report.loot_coins = roundi(rival.loot_coins * (1.0 + maxf(loot_bonus, 0.0)))
	report.loot_cores = rival.loot_cores
	report.influence_gained = rival.influence
	state.coins += report.loot_coins
	state.cores += report.loot_cores
	state.influence[district.id] = state.current_influence() + rival.influence
	state.add_suspicion(b.raid_suspicion)
	Items.raid_loot(state, district.is_flagship(rival.id), data, rng, report)
	_drop_dish(state, "raid", data, rng, report)
	if district.is_flagship(rival.id):
		_take_over(state, data, report)


## The district becomes the player's; the next one (if any) opens tomorrow
## with no Suspicion. The last district stays current once taken.
static func _take_over(state: GameState, data: GameData, report: Report) -> void:
	report.district_taken = state.district_id
	state.owned_districts.append(state.district_id)
	report.next_district = data.next_district(state.district_id)
	if report.next_district == "":
		return
	state.district_id = report.next_district
	state.district_started_day = state.day + 1
	state.suspicion[report.next_district] = 0.0


## Synths who stayed home (and have battery) as defenders, with security HP.
static func _home_defenders(state: GameState, data: GameData) -> Array[Battle.Fighter]:
	var home: Array[Battle.Fighter] = []
	for synth: Synth in state.synths:
		if not state.raid_squad.has(synth.id) and synth.battery > 0.0:
			home.append(synth_fighter(synth, state.security, data, state))
	return home


## size MegaBean raiders, each strength times the day's normal raider.
static func _megabean_squad(state: GameState, size: int, strength: float, data: GameData) -> Array[Battle.Fighter]:
	var b := data.balance
	var order := data.combat.megabean_classes
	var raiders: Array[Battle.Fighter] = []
	for i: int in size:
		raiders.append(Battle.Fighter.make("", (b.defense_power_base + b.defense_power_per_day * state.day) * strength,
			(b.defense_hp_base + b.defense_hp_per_day * state.day) * strength, order[i % order.size()]))
	return raiders


## Maybe unlocks a dish from this source (dish_drop_chance) the player lacks.
static func _drop_dish(state: GameState, source: String, data: GameData, rng: RandomNumberGenerator, report: Report) -> void:
	var missing: Array[String] = []
	for recipe: Recipe in data.recipes.values():
		if recipe.source == source and not state.dishes.has(recipe.id):
			missing.append(recipe.id)
	if missing.is_empty() or rng.randf() >= data.balance.dish_drop_chance:
		return
	report.new_dish = missing[rng.randi_range(0, missing.size() - 1)]
	state.dishes.append(report.new_dish)


static func _defend(state: GameState, data: GameData, rng: RandomNumberGenerator, report: Report) -> void:
	var b := data.balance
	var size := mini(1 + int(state.current_suspicion() / maxf(b.defense_size_step, 1.0)), b.defense_max_size)
	report.defense = Battle.run(_megabean_squad(state, size, 1.0, data), _home_defenders(state, data), rng, data)
	_defender_xp(state, report, b)
	if not report.defense.attackers_won:
		_drop_dish(state, "defense", data, rng, report)
		return
	report.coins_lost = int(state.coins * b.defense_coin_loss)
	report.cores_lost = mini(state.cores, b.defense_core_loss)
	state.coins -= report.coins_lost
	state.cores -= report.cores_lost


static func _audit(state: GameState, data: GameData, rng: RandomNumberGenerator, report: Report) -> void:
	var b := data.balance
	report.audit = true
	report.defense = Battle.run(_megabean_squad(state, b.audit_size, b.audit_strength, data), _home_defenders(state, data),
		rng, data)
	_defender_xp(state, report, b)
	if not report.defense.attackers_won:
		return
	report.coins_lost = int(state.coins * b.audit_coin_loss)
	state.coins -= report.coins_lost
	report.closed_next_shift = true
	if state.synths.size() > 1:
		var taken := state.synths[rng.randi_range(0, state.synths.size() - 1)]
		Items.return_all(state, taken)
		state.synths.erase(taken)
		report.synth_lost = taken.id


## Every Synth who fought for the café earns xp_defense, win or lose.
static func _defender_xp(state: GameState, report: Report, b: BalanceConfig) -> void:
	for fighter: Battle.Fighter in report.defense.defenders:
		Leveling.add_xp(state.synth_by_id(fighter.synth_id), b.xp_defense, b, report.level_ups)


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


## Fills the batteries of Synths that were resting in their Pod at closing, in
## Synth order while Power lasts.
static func _recharge(state: GameState, data: GameData, report: Report) -> void:
	for synth: Synth in state.synths:
		if not synth.charging:
			if _missing_battery(synth, data) > 0.0:
				report.not_in_pod.append(synth.id)
			synth.charging = true
			continue
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
