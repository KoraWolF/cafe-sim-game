extends SceneTree
## Plays many days with a simple scripted player and prints how the economy,
## staff, Suspicion and Night Ops develop. For tuning /data, not a test.
## Usage: godot --headless --path . -s res://tools/balance_sim.gd -- [days] [seeds] [--daily]
##
## The bot: keeps a Cashier at the register, cooks whatever waiting customers want,
## converts every star it can
## (and puts each new Synth to work in its best role),
## brews NanoBrew from every core, keeps enough Power for a full recharge, buys
## the cheapest upgrade while keeping a reserve, and raids the strongest rival
## its squad (everyone but one Synth left home) is likely to beat.

const RESERVE: int = 150
## How many of each the bot buys beyond the start (what the old upgrades capped).
const FURNITURE_CAPS: Dictionary[String, int] = {"stove": 4, "counter": 4, "seat_pair": 8}

var decor_spend := 0
## Furniture bought this run, by option.
var bought: Dictionary[String, int] = {}

var data: GameData


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 30
	var seeds := int(args[1]) if args.size() > 1 else 5
	var daily := args.has("--daily")
	data = GameData.load_default()
	var totals := {}
	for seed_value: int in seeds:
		var result := _play(seed_value, days, daily)
		for key: String in result:
			totals[key] = totals.get(key, 0.0) + result[key]
	print("\n== average of %d seeds over %d days ==" % [seeds, days])
	for key: String in totals:
		print("  %-22s %10.1f" % [key, totals[key] / seeds])
	quit()


func _play(seed_value: int, days: int, daily: bool) -> Dictionary:
	var state := GameState.new_game(seed_value, data)
	decor_spend = 0
	bought.clear()
	var stats := {"seated": 0.0, "stars": 0.0, "angry": 0.0, "turned_away": 0.0, "conversions": 0.0,
		"raids": 0.0, "raids_won": 0.0, "defenses": 0.0, "defenses_lost": 0.0, "coins_stolen": 0.0,
		"undercharged_nights": 0.0, "upgrade_spend": 0.0, "max_suspicion": 0.0,
		"audits": 0.0, "audits_lost": 0.0, "closed_shifts": 0.0, "income": 0.0}
	for district_id: String in data.district_order:
		stats["taken_day_" + district_id] = 0.0
	if daily:
		print("\n-- seed %d --" % seed_value)
		print(" day  coins  vibe synths pods seats stoves  stars%  angry  away  susp  raid                      defense")
	for day: int in days:
		var day_stats := {"seated": 0, "stars": 0, "angry": 0, "away": 0}
		while state.phase == GameState.Phase.SHIFT:
			_cook(state)
			var events := GameLoop.advance(state, 1, data)
			day_stats["seated"] += events.served.size() + events.left_angry.size()
			day_stats["stars"] += events.starred.size()
			day_stats["angry"] += events.left_angry.size()
			day_stats["away"] += events.turned_away
			for customer_id: String in events.starred:
				var created: Array[Synth] = []
				if GameLoop.convert_customer(state, customer_id, data, created) == GameLoop.OK:
					stats["conversions"] += 1
					# New Synths start Resting: the bot puts them to work in their best role.
					GameLoop.assign_role(state, created[0].id, data.species[created[0].species_id].best_role)
		_keep_a_cashier(state)
		var raid := _plan_raid(state)
		stats["upgrade_spend"] += _night_shopping(state)
		var report := GameLoop.end_night(state, data)
		stats["seated"] += day_stats["seated"]
		stats["stars"] += day_stats["stars"]
		stats["angry"] += day_stats["angry"]
		stats["turned_away"] += day_stats["away"]
		if report.raid != null:
			stats["raids"] += 1
			stats["raids_won"] += 1 if report.raid.attackers_won else 0
		if report.defense != null and report.audit:
			stats["audits"] += 1
			stats["audits_lost"] += 1 if report.defense.attackers_won else 0
			stats["closed_shifts"] += 1 if report.closed_next_shift else 0
		elif report.defense != null:
			stats["defenses"] += 1
			stats["defenses_lost"] += 1 if report.defense.attackers_won else 0
		if report.district_taken != "":
			stats["taken_day_" + report.district_taken] = day + 1
			if daily:
				print("     >> took %s on day %d" % [report.district_taken, day + 1])
		stats["income"] += report.income
		for amount: int in report.stolen.values():
			stats["coins_stolen"] += amount
		stats["undercharged_nights"] += 1 if not report.undercharged.is_empty() else 0
		stats["max_suspicion"] = maxf(stats["max_suspicion"], state.current_suspicion())
		if daily:
			var raid_text := "-" if report.raid == null else "%s %s" % [raid, "won" if report.raid.attackers_won else "lost"]
			var defense_text := "-" if report.defense == null else ("lost %d" % report.coins_lost if report.defense.attackers_won else "held")
			if report.audit:
				defense_text = "AUDIT " + defense_text
			print(" %3d %6d %5.0f %5d %5d %5d %5d %7.0f %6d %5d %5.0f  %-25s %s" % [day + 1, state.coins, state.vibe, state.synths.size(),
				state.pods, state.seats, state.stoves.size(),
				100.0 * day_stats["stars"] / maxi(day_stats["seated"], 1), day_stats["angry"], day_stats["away"],
				state.current_suspicion(), raid_text, defense_text])
	stats["star_rate_%"] = 100.0 * stats["stars"] / maxf(stats["seated"], 1.0)
	stats["final_coins"] = state.coins
	stats["final_synths"] = state.synths.size()
	stats["final_seats"] = state.seats
	stats["final_stoves"] = state.stoves.size()
	stats["final_pods"] = state.pods
	stats["final_vibe"] = state.vibe
	stats["final_floor_rows"] = state.floor_rows
	stats["decor_spend"] = decor_spend
	var levels := state.synths.map(func(synth: Synth) -> int: return synth.level)
	stats["final_avg_level"] = levels.reduce(func(sum: int, level: int) -> int: return sum + level, 0) / float(levels.size())
	stats["final_max_level"] = levels.max()
	# Untaken districts count as never (shown as 0 in the average; see the count).
	for district_id: String in data.district_order:
		stats["took_" + district_id] = 1.0 if state.owned_districts.has(district_id) else 0.0
	return stats


func _cook(state: GameState) -> void:
	# Keep enough food coming for everyone seated or queued: the best coins per
	# second of cooking among the dishes it can afford.
	var hungry := state.customers.filter(func(c: Customer) -> bool:
		return c.stage == Customer.Stage.WAITING_FOOD or c.stage == Customer.Stage.QUEUED).size()
	var food := 0
	for count: int in state.counter.values():
		food += count
	for stove: Stove in state.stoves:
		if not stove.is_idle():
			food += data.recipes[stove.recipe_id].servings
	for i: int in state.stoves.size():
		if not state.stoves[i].is_idle() or food >= hungry:
			continue
		var pick: Recipe = null
		for recipe: Recipe in Shift.unlocked_recipes(state, data):
			var rate := float(recipe.price * recipe.servings - recipe.cost) / recipe.cook_seconds
			if state.coins >= recipe.cost and (pick == null \
					or rate > float(pick.price * pick.servings - pick.cost) / pick.cook_seconds):
				pick = recipe
		if pick != null and GameLoop.start_cooking(state, i, pick.id, data) == GameLoop.OK:
			food += pick.servings


## Brews, buys Power for a full recharge, then upgrades. Returns coins spent on upgrades.
## Someone has to take payments: if the Cashier is gone (an Audit), the fastest
## server takes the register.
func _keep_a_cashier(state: GameState) -> void:
	if state.synths.any(func(synth: Synth) -> bool: return synth.role == Synth.CASHIER):
		return
	var best: Synth = null
	for synth: Synth in state.synths:
		if synth.role == Synth.SERVER and (best == null or SynthStats.speed(synth, data) > SynthStats.speed(best, data)):
			best = synth
	if best != null:
		GameLoop.assign_role(state, best.id, Synth.CASHIER)


func _night_shopping(state: GameState) -> int:
	while GameLoop.brew_nanobrew(state, data) == GameLoop.OK:
		pass
	# Raiders come back with raid_battery_cost less battery.
	var raid_cost := 0.0
	for synth_id: String in state.raid_squad:
		var synth := state.synth_by_id(synth_id)
		raid_cost += data.balance.raid_battery_cost * data.balance.power_per_battery \
			* SynthStats.stat(synth, "recharge_multiplier", data)
	var shortfall := NightOps.recharge_cost(state, data) + raid_cost - state.power
	if shortfall > 0.0:
		GameLoop.buy_power(state, ceili(shortfall), data)
	var spent := 0
	var refused: Array[String] = []
	while true:
		# The cheapest of: an upgrade, or a piece of furniture (a seat comes with its
		# table) up to what the old furniture upgrades allowed.
		var best := ""
		var best_cost := 1 << 30
		for option: String in Upgrade.IDS + FURNITURE_CAPS.keys():
			# More pods only help when NanoBrew is waiting for them.
			if refused.has(option) or (option == Upgrade.POD and state.synths.size() < state.pods):
				continue
			var cost := _option_cost(state, option)
			if cost > 0 and state.coins - cost >= RESERVE and cost < best_cost:
				best = option
				best_cost = cost
		if best == "":
			break
		if _buy_option(state, best):
			spent += best_cost
			_place_stored_furniture(state)
		else:
			refused.append(best)  # e.g. no room for more furniture
	decor_spend += _buy_decor(state)
	return spent


## Coins for an upgrade or a furniture option (-1 = not available).
func _option_cost(state: GameState, option: String) -> int:
	if not FURNITURE_CAPS.has(option):
		return GameLoop.upgrade_cost(state, option, data)
	var piece_id: String = Piece.SEAT if option == "seat_pair" else option
	if bought.get(option, 0) >= FURNITURE_CAPS[option]:
		return -1
	var cost := data.pieces[piece_id].price
	return cost + data.pieces[Piece.TABLE].price if option == "seat_pair" else cost


func _buy_option(state: GameState, option: String) -> bool:
	if not FURNITURE_CAPS.has(option):
		return GameLoop.buy_upgrade(state, option, data) == GameLoop.OK
	var pieces: Array[String] = [option]
	if option == "seat_pair":
		pieces = [Piece.SEAT, Piece.TABLE]
	var free := 0
	var bounds := Layout.floor_size(state, data.balance)
	for y: int in bounds.y:
		for x: int in bounds.x:
			if Layout.piece_at(state, Vector2i(x, y), data) == null:
				free += 1
	if free < pieces.size() * 2:
		return false  # no room left
	for piece_id: String in pieces:
		GameLoop.buy_piece(state, piece_id, data)
	bought[option] = bought.get(option, 0) + 1
	return true


func _place_stored_furniture(state: GameState) -> void:
	for piece_id: String in [Piece.STOVE, Piece.COUNTER, Piece.TABLE, Piece.SEAT]:
		while state.storage.get(piece_id, 0) > 0:
			var spot := Layout.find_spot(state, piece_id, data)
			if spot.is_empty():
				break
			GameLoop.place_piece(state, piece_id, spot["cell"], spot["rotated"], data)


## Buys and places the décor piece with the most Vibe gained per coin at its
## best spot, while coins stay above the reserve. Leaves two free rows' worth
## of tiles for future furniture. Returns coins spent.
func _buy_decor(state: GameState) -> int:
	var spent := 0
	while true:
		var free_tiles := data.balance.floor_width * state.floor_rows
		for placed: PlacedPiece in state.placed:
			free_tiles -= Layout.cells(placed, data).size()
		var best_value := 0.0
		var best: Dictionary = {}
		for piece: Piece in data.pieces.values():
			if piece.kind != Piece.DECOR or state.coins - piece.price < RESERVE:
				continue
			if free_tiles - piece.size.x * piece.size.y < 2 * data.balance.floor_width:
				continue
			var spot := _best_spot(state, piece)
			if not spot.is_empty() and spot["gain"] / piece.price > best_value:
				best_value = spot["gain"] / piece.price
				best = spot
				best["piece_id"] = piece.id
		if best.is_empty():
			return spent
		spent += data.pieces[best["piece_id"]].price
		GameLoop.buy_piece(state, best["piece_id"], data)
		GameLoop.place_piece(state, best["piece_id"], best["cell"], best["rotated"], data)
	return spent


## The free spot where this piece adds the most Vibe: {"cell", "rotated", "gain"}.
func _best_spot(state: GameState, piece: Piece) -> Dictionary:
	var before := state.vibe
	var best: Dictionary = {}
	var trial := PlacedPiece.new()
	trial.piece_id = piece.id
	trial.uid = "trial"
	for y: int in state.floor_rows:
		for x: int in data.balance.floor_width:
			for rotated: bool in [false, true]:
				if Layout.check_spot(state, piece.id, Vector2i(x, y), rotated, data) != GameLoop.OK:
					continue
				trial.cell = Vector2i(x, y)
				trial.rotated = rotated
				state.placed.append(trial)
				var gain := -before
				for value: float in Layout.seat_vibes(state, data).values():
					gain += value
				state.placed.pop_back()
				if best.is_empty() or gain > best["gain"]:
					best = {"cell": trial.cell, "rotated": rotated, "gain": gain}
	return best


## Raids the rival with the most loot whose guards the squad outmatches. Returns its id or "".
func _plan_raid(state: GameState) -> String:
	if state.synths.size() < 2:
		return ""
	var squad: Array[String] = []
	var power := 0.0
	var hp := 0.0
	var ready := state.synths.filter(func(synth: Synth) -> bool: return synth.battery > data.balance.raid_battery_cost)
	ready.sort_custom(func(a: Synth, b: Synth) -> bool:
		return SynthStats.stat(a, "power", data) > SynthStats.stat(b, "power", data))
	for synth: Synth in ready.slice(0, mini(ready.size() - 1, data.balance.raid_squad_max)):
		squad.append(synth.id)
		power += SynthStats.stat(synth, "power", data)
		hp += SynthStats.stat(synth, "hp", data)
	if squad.is_empty():
		return ""
	var best: RivalCafe = null
	for rival: RivalCafe in NightOps.raid_targets(state, data):
		var guard_power := 0.0
		var guard_hp := 0.0
		for guard: Battle.Fighter in NightOps.guards_for(state, rival, data):
			guard_power += guard.power
			guard_hp += guard.hp
		# Rounds each side needs to knock the other out; attackers hit first.
		# The flagship is worth a riskier try.
		var margin := 1.25 if data.districts[state.district_id].is_flagship(rival.id) else 1.0
		if guard_hp / power <= margin * hp / guard_power and (best == null or rival.loot_cores > best.loot_cores):
			best = rival
	if best == null:
		return ""
	GameLoop.plan_raid(state, best.id, squad, data)
	return best.id
