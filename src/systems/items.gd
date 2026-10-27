class_name Items
extends RefCounted
## Items: equipping and unequipping (a piece is in the inventory or worn by one
## Synth, never both), selling equipment, crafting from raid Scrap and Chips,
## EXP bottles, and the loot a won raid brings. Content in data.items.


static func make(state: GameState, kind: String, type_id: String, tier := "") -> Item:
	var item := Item.new()
	item.uid = state.new_id("item")
	item.kind = kind
	item.type_id = type_id
	item.tier = tier
	return item


static func in_inventory(state: GameState, uid: String) -> Item:
	for item: Item in state.inventory:
		if item.uid == uid:
			return item
	return null


## The piece a Synth wears in a slot, or null.
static func worn(synth: Synth, slot: String, data: GameData) -> Item:
	for item: Item in synth.items:
		if item.slot(data.items) == slot:
			return item
	return null


## Puts an inventory piece on a Synth; whatever it wore in that slot goes back.
static func equip(state: GameState, synth_id: String, uid: String, data: GameData) -> String:
	var synth := state.synth_by_id(synth_id)
	if synth == null:
		return GameLoop.UNKNOWN_SYNTH
	var item := in_inventory(state, uid)
	if item == null:
		return GameLoop.UNKNOWN_ITEM
	var old := worn(synth, item.slot(data.items), data)
	if old != null:
		synth.items.erase(old)
		state.inventory.append(old)
	state.inventory.erase(item)
	synth.items.append(item)
	return GameLoop.OK


static func unequip(state: GameState, synth_id: String, slot: String, data: GameData) -> String:
	var synth := state.synth_by_id(synth_id)
	if synth == null:
		return GameLoop.UNKNOWN_SYNTH
	var item := worn(synth, slot, data)
	if item == null:
		return GameLoop.NOTHING_WORN
	synth.items.erase(item)
	state.inventory.append(item)
	return GameLoop.OK


## A Synth leaving the café (taken in an Audit) leaves its pieces behind.
static func return_all(state: GameState, synth: Synth) -> void:
	state.inventory.append_array(synth.items)
	synth.items.clear()


## Sells an inventory equipment piece for its tier's price. Fashion is kept.
static func sell(state: GameState, uid: String, data: GameData) -> String:
	var item := in_inventory(state, uid)
	if item == null:
		return GameLoop.UNKNOWN_ITEM
	if item.kind != Item.EQUIPMENT:
		return GameLoop.NOT_FOR_SALE
	state.inventory.erase(item)
	state.coins += int(data.items.tiers[item.tier]["sell"])
	return GameLoop.OK


## Makes a random piece from Scrap (and Chips); out_item gets it.
static func craft(state: GameState, craft_id: String, data: GameData, out_item: Array[Item] = []) -> String:
	var recipe: Dictionary = data.items.crafts.get(craft_id, {})
	if recipe.is_empty():
		return GameLoop.UNKNOWN_CRAFT
	if state.scrap < recipe["scrap"] or state.chips < recipe["chips"]:
		return GameLoop.NOT_ENOUGH_MATERIALS
	state.scrap -= recipe["scrap"]
	state.chips -= recipe["chips"]
	var rng := state.rng()
	var item := _random_equipment(state, recipe["tiers"], data, rng)
	state.store_rng(rng)
	state.inventory.append(item)
	out_item.append(item)
	return GameLoop.OK


## Drinks an EXP bottle: its XP goes to the Synth.
static func use_bottle(state: GameState, synth_id: String, bottle_id: String, data: GameData,
		level_ups: Dictionary[String, int] = {}) -> String:
	var synth := state.synth_by_id(synth_id)
	if synth == null:
		return GameLoop.UNKNOWN_SYNTH
	if state.bottles.get(bottle_id, 0) <= 0 or not data.items.bottles.has(bottle_id):
		return GameLoop.NONE_LEFT
	if synth.level >= data.balance.max_synth_level:
		return GameLoop.MAXED
	state.bottles[bottle_id] -= 1
	if state.bottles[bottle_id] <= 0:
		state.bottles.erase(bottle_id)
	Leveling.add_xp(synth, data.items.bottles[bottle_id]["xp"], data.balance, level_ups)
	return GameLoop.OK


## What a won raid brings besides coins and cores: Scrap, Chips from a
## flagship, maybe a piece of equipment, maybe an EXP bottle (rarer as days
## pass and Synths level up; big ones only from their min_day).
static func raid_loot(state: GameState, flagship: bool, data: GameData, rng: RandomNumberGenerator,
		report: NightOps.Report) -> void:
	var loot := data.items.raid_loot
	if loot.is_empty():
		return
	report.loot_scrap = rng.randi_range(int(loot.get("scrap_min", 0)), int(loot.get("scrap_max", 0)))
	report.loot_chips = int(loot.get("flagship_chips", 0)) if flagship else 0
	state.scrap += report.loot_scrap
	state.chips += report.loot_chips
	var chance := float(loot.get("flagship_item_chance" if flagship else "item_chance", 0.0))
	if rng.randf() < chance:
		var item := _random_equipment(state, loot.get("flagship_tiers" if flagship else "tiers", {}), data, rng)
		state.inventory.append(item)
		report.loot_items.append(item.uid)
	if rng.randf() < bottle_chance(state, data):
		var weights: Dictionary = {}
		for bottle_id: String in data.items.bottles:
			if state.day >= data.items.bottles[bottle_id]["min_day"]:
				weights[bottle_id] = data.items.bottles[bottle_id]["weight"]
		if not weights.is_empty():
			report.loot_bottle = _pick(weights, rng)
			state.bottles[report.loot_bottle] = state.bottles.get(report.loot_bottle, 0) + 1


## Chance a won raid brings an EXP bottle: falls with the day and the staff's average level.
static func bottle_chance(state: GameState, data: GameData) -> float:
	var loot := data.items.raid_loot
	var levels := 0.0
	for synth: Synth in state.synths:
		levels += synth.level
	var average := levels / maxf(state.synths.size(), 1.0)
	return maxf(float(loot.get("bottle_chance", 0.0)) + float(loot.get("bottle_chance_per_day", 0.0)) * (state.day - 1)
		+ float(loot.get("bottle_chance_per_level", 0.0)) * (average - 1.0), float(loot.get("bottle_chance_min", 0.0)))


static func _random_equipment(state: GameState, tier_weights: Dictionary, data: GameData, rng: RandomNumberGenerator) -> Item:
	var kinds := data.items.equipment.keys()
	return make(state, Item.EQUIPMENT, kinds[rng.randi_range(0, kinds.size() - 1)], _pick(tier_weights, rng))


static func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for key: String in weights:
		total += float(weights[key])
	var roll := rng.randf() * total
	var last := ""
	for key: String in weights:
		last = key
		roll -= float(weights[key])
		if roll < 0.0:
			return key
	return last
