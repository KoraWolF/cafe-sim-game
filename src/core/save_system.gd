class_name SaveSystem
extends RefCounted
## Saves a GameState as plain JSON in user://saves/ (never as a Resource: a
## shared .tres could run a script on load). Writes go to a temp file that is
## renamed over the save, keeping the previous save as .bak; loading falls back
## to the .bak if the save is missing or broken. A save that is not valid is
## refused whole, never loaded halfway.
##
## Autosave on safe boundaries: when a shift closes (Shift.Events.shift_ended)
## and after GameLoop.end_night. The autosave has its own file, so it never
## overwrites a manual slot.

## 2: district takeover (influence, owned districts, district start day, closed shift).
## 3: Synth level and XP.
## 4: daily menu and menu slots.
## 5: the café floor (placed pieces, storage, floor rows); seats and Pods are no
##    longer saved, they come from the floor.
## 6: the counter piece (older saves get one placed on load).
## 7: Sync Pods leave the floor for the Pod bay: saved as a count again.
## 8: 1x1 counters holding one dish each; batches wait on stoves to be carried.
## 9: each unit's own max battery, bins and throw-away marks, Auto. Older
##    cafés get a bin (placed if there is room, else in storage).
## 10: tables: a seat works only beside one. Older cafés get a table beside
##     each seat (or in storage when there is no room).
## 11: registers and Cashiers: customers pay on the way out. Older cafés get
##     a register and a Clerkbot Cashier (with a Pod of its own).
## 12: items: inventory, EXP bottles, Scrap and Chips, worn pieces. Older
##     games get the starter fashion.
## 13: quests: lifetime counters, daily quests and their date, story step,
##     achievements. Older games start them from zero.
## 14: furniture is bought by the piece, not as upgrades: old furniture
##     upgrade levels are dropped (the pieces stay).
## 15: jobs by place (Chef at a stove, Cashier at a register), no Greeter,
##     the starred list. Greeters become Servers; stations are bound on load.
## 16: no daily menu: nobody orders, a server brings the nearest dish. The
##     menu and menu slots are dropped; seated customers forget their order.
## 17: the floor's width is saved (it grows with the floor upgrade); older
##     cafés were 8 across.
const VERSION: int = 17
const SAVE_DIR: String = "user://saves"
const SLOTS: int = 3


static func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


static func autosave_path() -> String:
	return "%s/autosave.json" % SAVE_DIR


static func to_dict(state: GameState) -> Dictionary:
	return {
		"version": VERSION,
		"day": state.day,
		"phase": state.phase,
		"shift_time": state.shift_time,
		"next_arrival": state.next_arrival,
		"speed": state.speed,
		"coins": state.coins,
		"nanobrew": state.nanobrew,
		"cores": state.cores,
		"power": state.power,
		"security": state.security,
		"pods": state.pods,
		"floor_width": state.floor_width,
		"floor_rows": state.floor_rows,
		"placed": state.placed.map(func(placed: PlacedPiece) -> Dictionary: return placed.to_dict()),
		"storage": state.storage,
		"upgrades": state.upgrades,
		"stoves": state.stoves.map(func(stove: Stove) -> Dictionary: return stove.to_dict()),
		"counter": state.counter,
		"discard": state.discard,
		"auto_night": state.auto_night,
		"star_list": state.star_list.map(func(customer: Customer) -> Dictionary: return customer.to_dict()),
		"inventory": state.inventory.map(func(item: Item) -> Dictionary: return item.to_dict()),
		"bottles": state.bottles,
		"scrap": state.scrap,
		"chips": state.chips,
		"stats": state.stats,
		"daily_quests": state.daily_quests,
		"daily_date": state.daily_date,
		"story_index": state.story_index,
		"achievements": state.achievements,
		"counter_dish": state.counter_dish,
		"counter_count": state.counter_count,
		"customers": state.customers.map(func(customer: Customer) -> Dictionary: return customer.to_dict()),
		"synths": state.synths.map(func(synth: Synth) -> Dictionary: return synth.to_dict()),
		"district_id": state.district_id,
		"district_started_day": state.district_started_day,
		"owned_districts": state.owned_districts,
		"influence": state.influence,
		"closed": state.closed,
		"suspicion": state.suspicion,
		"raid_cooldowns": state.raid_cooldowns,
		"raid_target": state.raid_target,
		"raid_squad": state.raid_squad,
		"next_id": state.next_id,
		# Stored as strings: JSON numbers lose precision above 2^53.
		"rng_seed": str(state.rng_seed),
		"rng_state": str(state.rng_state),
	}


static func from_dict(raw: Dictionary) -> GameState:
	var state := GameState.new()
	state.day = int(raw.get("day", 0))
	state.phase = int(raw.get("phase", -1)) as GameState.Phase
	state.shift_time = int(raw.get("shift_time", 0))
	state.next_arrival = int(raw.get("next_arrival", 0))
	state.speed = int(raw.get("speed", 1))
	state.coins = int(raw.get("coins", 0))
	state.nanobrew = int(raw.get("nanobrew", 0))
	state.cores = int(raw.get("cores", 0))
	state.power = float(raw.get("power", 0.0))
	state.security = float(raw.get("security", 0.0))
	state.pods = int(raw.get("pods", 0))
	state.floor_width = int(raw.get("floor_width", 0))
	state.floor_rows = int(raw.get("floor_rows", 0))
	for entry: Dictionary in _objects(raw, "placed"):
		state.placed.append(PlacedPiece.from_dict(entry))
	var storage: Variant = raw.get("storage", {})
	if storage is Dictionary:
		for piece_id: Variant in storage:
			state.storage[str(piece_id)] = int(storage[piece_id])
	var upgrades: Variant = raw.get("upgrades", {})
	if upgrades is Dictionary:
		for upgrade_id: Variant in upgrades:
			state.upgrades[str(upgrade_id)] = int(upgrades[upgrade_id])
	for entry: Dictionary in _objects(raw, "stoves"):
		state.stoves.append(Stove.from_dict(entry))
	var counter: Variant = raw.get("counter", {})
	if counter is Dictionary:
		for recipe_id: Variant in counter:
			state.counter[str(recipe_id)] = int(counter[recipe_id])
	state.auto_night = bool(raw.get("auto_night", false))
	for entry: Dictionary in _objects(raw, "star_list"):
		state.star_list.append(Customer.from_dict(entry))
	# Older saves: starred customers lingering outside go to the starred list.
	for customer: Customer in state.customers.duplicate():
		if customer.stage == Customer.Stage.STAR:
			state.customers.erase(customer)
			state.star_list.append(customer)
	for entry: Dictionary in _objects(raw, "inventory"):
		state.inventory.append(Item.from_dict(entry))
	var bottles: Variant = raw.get("bottles", {})
	if bottles is Dictionary:
		for bottle_id: Variant in bottles:
			state.bottles[str(bottle_id)] = int(bottles[bottle_id])
	state.scrap = int(raw.get("scrap", 0))
	state.chips = int(raw.get("chips", 0))
	var counters: Variant = raw.get("stats", {})
	if counters is Dictionary:
		for stat: Variant in counters:
			state.stats[str(stat)] = int(counters[stat])
	for quest: Dictionary in _objects(raw, "daily_quests"):
		state.daily_quests.append({"id": str(quest.get("id", "")), "target": int(quest.get("target", 1)),
			"start": int(quest.get("start", 0)), "reward": quest.get("reward", {}), "claimed": bool(quest.get("claimed", false))})
	state.daily_date = str(raw.get("daily_date", ""))
	state.story_index = int(raw.get("story_index", 0))
	var claimed: Variant = raw.get("achievements", [])
	if claimed is Array:
		for id: Variant in claimed:
			state.achievements.append(str(id))
	var discard: Variant = raw.get("discard", [])
	if discard is Array:
		for uid: Variant in discard:
			state.discard.append(str(uid))
	var dishes: Variant = raw.get("counter_dish", {})
	if dishes is Dictionary:
		for counter_uid: Variant in dishes:
			state.counter_dish[str(counter_uid)] = str(dishes[counter_uid])
	var counts: Variant = raw.get("counter_count", {})
	if counts is Dictionary:
		for counter_uid: Variant in counts:
			state.counter_count[str(counter_uid)] = int(counts[counter_uid])
	for entry: Dictionary in _objects(raw, "customers"):
		state.customers.append(Customer.from_dict(entry))
	for entry: Dictionary in _objects(raw, "synths"):
		state.synths.append(Synth.from_dict(entry))
	state.district_id = str(raw.get("district_id", ""))
	state.district_started_day = int(raw.get("district_started_day", 0))
	var owned: Variant = raw.get("owned_districts", [])
	if owned is Array:
		for district_id: Variant in owned:
			state.owned_districts.append(str(district_id))
	var influence: Variant = raw.get("influence", {})
	if influence is Dictionary:
		for district_id: Variant in influence:
			state.influence[str(district_id)] = int(influence[district_id])
	state.closed = bool(raw.get("closed", false))
	var suspicion: Variant = raw.get("suspicion", {})
	if suspicion is Dictionary:
		for district_id: Variant in suspicion:
			state.suspicion[str(district_id)] = float(suspicion[district_id])
	var cooldowns: Variant = raw.get("raid_cooldowns", {})
	if cooldowns is Dictionary:
		for rival_id: Variant in cooldowns:
			state.raid_cooldowns[str(rival_id)] = int(cooldowns[rival_id])
	state.raid_target = str(raw.get("raid_target", ""))
	var squad: Variant = raw.get("raid_squad", [])
	if squad is Array:
		for synth_id: Variant in squad:
			state.raid_squad.append(str(synth_id))
	state.next_id = int(raw.get("next_id", 1))
	state.rng_seed = str(raw.get("rng_seed", "0")).to_int()
	state.rng_state = str(raw.get("rng_state", "0")).to_int()
	return state


static func _objects(raw: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var list: Variant = raw.get(key, [])
	if list is Array:
		for entry: Variant in list:
			if entry is Dictionary:
				result.append(entry)
	return result


## Brings an older save up to VERSION. Returns {} if it cannot.
static func migrate(raw: Dictionary, errors: PackedStringArray) -> Dictionary:
	var version := int(raw.get("version", 0))
	if version > VERSION:
		errors.append("save is from a newer version of the game (%d > %d)" % [version, VERSION])
		return {}
	while version < VERSION:
		var next := _migrate_step(version, raw)
		if next.is_empty():
			errors.append("unsupported save version %d" % version)
			return {}
		raw = next
		version += 1
		raw["version"] = version
	return raw


## One save version to the next; {} if there is no migration from this version.
## Add a case every time VERSION goes up.
static func _migrate_step(version: int, raw: Dictionary) -> Dictionary:
	match version:
		1:
			# Before district takeover: still in the first district, nothing owned.
			raw["district_started_day"] = 1
			raw["owned_districts"] = []
			raw["influence"] = {}
			raw["closed"] = false
			return raw
		2:
			# Before Synth levels: everyone starts at level 1.
			for synth: Variant in raw.get("synths", []):
				if synth is Dictionary:
					synth["level"] = 1
					synth["xp"] = 0
			return raw
		3:
			# Before the menu: customers ordered any unlocked recipe (an empty
			# menu still means that); 2 slots was the starting count.
			raw["menu"] = []
			raw["menu_slots"] = 2
			return raw
		4:
			# Before the floor: seats, stoves and Pods were counts. They are laid
			# out on load (needs GameData, see _lay_out_old) on the 6 starting rows.
			raw["needs_layout"] = true
			raw["floor_rows"] = 6
			raw["placed"] = []
			raw["storage"] = {}
			return raw
		5:
			# Before the counter: one is placed on load (needs GameData, see _add_counter).
			raw["needs_counter"] = true
			return raw
		6:
			# Pods move off the floor to the Pod bay: count the placed and stored ones.
			# (Saves from before v5 still carry their old "pods" count.)
			var pods := int(raw.get("pods", 0))
			var placed: Array = []
			for entry: Variant in raw.get("placed", []):
				if entry is Dictionary and str(entry.get("piece_id", "")) == "pod":
					pods += 1
				else:
					placed.append(entry)
			raw["placed"] = placed
			var storage: Variant = raw.get("storage", {})
			if storage is Dictionary and storage.has("pod"):
				pods += int(storage["pod"])
				storage.erase("pod")
			raw["pods"] = pods
			return raw
		7:
			# Counters held a shared pool: spread it over the counters on load (see Counters).
			raw["needs_counter_fill"] = true
			return raw
		8:
			# The starter café now has a bin: older cafés get one in storage to place.
			raw["needs_bin"] = true
			return raw
		9:
			raw["needs_tables"] = true
			return raw
		10:
			raw["needs_register"] = true
			return raw
		11:
			raw["needs_fashion"] = true
			return raw
		12:
			return raw
		14:
			return raw
		16:
			raw["floor_width"] = 8
			return raw
		15:
			raw.erase("menu")
			raw.erase("menu_slots")
			var levels: Variant = raw.get("upgrades", {})
			if levels is Dictionary:
				levels.erase("menu_slot")
			for key: String in ["customers", "star_list"]:
				var list: Variant = raw.get(key, [])
				if list is Array:
					for customer: Variant in list:
						if customer is Dictionary and int(customer.get("stage", -1)) == Customer.Stage.WAITING_FOOD:
							customer["recipe_id"] = ""
			return raw
		13:
			var levels: Variant = raw.get("upgrades", {})
			if levels is Dictionary:
				for upgrade_id: String in ["stove", "counter", "seat", "table", "bin", "register"]:
					levels.erase(upgrade_id)
			return raw
	return {}


## Puts a pre-floor save's seats and stoves (keeping what they cook) on
## the floor, adding rows until everything fits.
static func _lay_out_old(state: GameState, raw: Dictionary, data: GameData) -> void:
	var old_stoves := state.stoves.duplicate()
	state.stoves.clear()
	var wanted: Array[String] = []
	for stove: Stove in old_stoves:
		wanted.append(Piece.STOVE)
	for i: int in int(raw.get("seats", 0)):
		wanted.append(Piece.SEAT)
	for piece_id: String in wanted:
		while not Layout.auto_place(state, piece_id, data):
			state.floor_rows += 2
		if piece_id == Piece.STOVE:
			var old: Stove = old_stoves[state.stoves.size() - 1]
			state.stoves[-1].recipe_id = old.recipe_id
			state.stoves[-1].remaining = old.remaining


## Every problem that makes a loaded state unusable; empty means it is fine.
static func validate(state: GameState, data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if state.day < 1:
		errors.append("day %d" % state.day)
	if not GameState.Phase.values().has(state.phase):
		errors.append("unknown phase %d" % state.phase)
	if state.shift_time < 0 or state.shift_time > data.balance.shift_seconds:
		errors.append("shift time %d" % state.shift_time)
	if not GameState.SPEEDS.has(state.speed):
		errors.append("unknown speed %d" % state.speed)
	if state.coins < 0 or state.nanobrew < 0 or state.cores < 0 or state.power < 0.0:
		errors.append("negative resources")
	if state.pods < state.synths.size():
		errors.append("%d Pods for %d Synths" % [state.pods, state.synths.size()])
	errors.append_array(_check_floor(state, data))
	for upgrade_id: String in state.upgrades:
		var upgrade: Upgrade = data.upgrades.get(upgrade_id)
		if upgrade == null or state.upgrades[upgrade_id] < 0 or state.upgrades[upgrade_id] > upgrade.max_level:
			errors.append("bad upgrade level '%s'" % upgrade_id)
	if not data.districts.has(state.district_id):
		errors.append("unknown district '%s'" % state.district_id)
	for district_id: String in state.suspicion.keys() + state.influence.keys():
		if not data.districts.has(district_id):
			errors.append("suspicion or influence for unknown district '%s'" % district_id)
	for district_id: String in state.influence:
		if state.influence[district_id] < 0:
			errors.append("negative influence in '%s'" % district_id)
	for i: int in state.owned_districts.size():
		var district_id := state.owned_districts[i]
		if not data.districts.has(district_id) or state.owned_districts.find(district_id) != i:
			errors.append("bad owned district '%s'" % district_id)
	if state.district_started_day < 1 or state.district_started_day > state.day + 1:
		errors.append("district started on day %d" % state.district_started_day)
	if state.closed and (state.phase != GameState.Phase.SHIFT or state.shift_time != 0):
		errors.append("closed outside the start of a shift")
	for stove: Stove in state.stoves:
		if not stove.is_idle() and not data.recipes.has(stove.recipe_id):
			errors.append("stove cooks unknown recipe '%s'" % stove.recipe_id)
	for recipe_id: String in state.counter:
		if not data.recipes.has(recipe_id) or state.counter[recipe_id] < 0:
			errors.append("counter: bad entry '%s'" % recipe_id)
	var ids: Dictionary[String, bool] = {}
	for synth: Synth in state.synths:
		if ids.has(synth.id) or synth.id == "":
			errors.append("duplicate or empty Synth id '%s'" % synth.id)
		ids[synth.id] = true
		if not data.species.has(synth.species_id):
			errors.append("Synth '%s': unknown species '%s'" % [synth.id, synth.species_id])
		if synth.trait_id != "" and not data.traits.has(synth.trait_id):
			errors.append("Synth '%s': unknown trait '%s'" % [synth.id, synth.trait_id])
		if not Synth.ROLES.has(synth.role):
			errors.append("Synth '%s': unknown role '%s'" % [synth.id, synth.role])
		if synth.level < 1 or synth.level > data.balance.max_synth_level or synth.xp < 0 \
				or (synth.level < data.balance.max_synth_level and synth.xp >= Leveling.xp_to_next(synth.level, data.balance)):
			errors.append("Synth '%s': level %d with %d XP" % [synth.id, synth.level, synth.xp])
	for customer: Customer in state.customers:
		if ids.has(customer.id) or customer.id == "":
			errors.append("duplicate or empty customer id '%s'" % customer.id)
		ids[customer.id] = true
		if not data.customer_types.has(customer.type_id):
			errors.append("customer '%s': unknown type '%s'" % [customer.id, customer.type_id])
		if not Customer.Stage.values().has(customer.stage):
			errors.append("customer '%s': unknown stage %d" % [customer.id, customer.stage])
		if customer.stage in [Customer.Stage.EATING, Customer.Stage.PAYING, Customer.Stage.STAR] \
				and not data.recipes.has(customer.recipe_id):
			errors.append("customer '%s': unknown recipe '%s'" % [customer.id, customer.recipe_id])
		if customer.trait_id != "" and not data.traits.has(customer.trait_id):
			errors.append("customer '%s': unknown trait '%s'" % [customer.id, customer.trait_id])
		if customer.served_by != "" and state.synth_by_id(customer.served_by) == null:
			errors.append("customer '%s': served by unknown Synth" % customer.id)
	if state.phase == GameState.Phase.NIGHT and not state.customers.is_empty():
		errors.append("customers in the café at night")
	for counter_uid: String in state.counter_count:
		var counter := Layout.placed_by_uid(state, counter_uid)
		if counter == null or data.pieces[counter.piece_id].kind != Piece.COUNTER or state.counter_count[counter_uid] <= 0 \
				or not data.recipes.has(state.counter_dish.get(counter_uid, "")):
			errors.append("bad counter contents on '%s'" % counter_uid)
	for stove: Stove in state.stoves:
		if stove.has_batch() and not data.recipes.has(stove.recipe_id):
			errors.append("stove '%s': ready batch of an unknown dish" % stove.piece_uid)
		if stove.carrier != "":
			var carrier := state.synth_by_id(stove.carrier)
			if carrier == null or carrier.task_stove_uid != stove.piece_uid:
				errors.append("stove '%s': broken carrier" % stove.piece_uid)
	var owned: Array[Item] = state.inventory.duplicate()
	for synth: Synth in state.synths:
		owned.append_array(synth.items)
	for item: Item in owned:
		var known: bool = data.items.equipment.has(item.type_id) and data.items.tiers.has(item.tier) \
			if item.kind == Item.EQUIPMENT else data.items.fashion.has(item.type_id)
		if not known:
			errors.append("unknown item '%s'" % item.type_id)
	for uid: String in state.discard:
		if Layout.placed_by_uid(state, uid) == null:
			errors.append("throw-away mark on missing piece '%s'" % uid)
	for synth: Synth in state.synths:
		if synth.is_carrying():
			var stove := Layout.stove_of(state, synth.task_stove_uid)
			if stove == null or stove.carrier != synth.id or Layout.placed_by_uid(state, synth.task_counter_uid) == null:
				errors.append("Synth '%s': broken carry" % synth.id)
	for synth: Synth in state.synths:
		if synth.is_delivering():
			var customer := state.customer_by_id(synth.task_customer_id)
			if customer == null or customer.served_by != synth.id or not data.recipes.has(synth.task_recipe_id):
				errors.append("Synth '%s': broken delivery" % synth.id)
	if state.raid_target != "":
		if state.phase != GameState.Phase.NIGHT or not data.districts.has(state.district_id) \
				or data.districts[state.district_id].rival_by_id(state.raid_target) == null:
			errors.append("bad raid plan '%s'" % state.raid_target)
		for synth_id: String in state.raid_squad:
			if state.synth_by_id(synth_id) == null:
				errors.append("raid squad: unknown Synth '%s'" % synth_id)
	return errors


## Placed pieces known, unique, on the floor and not overlapping; one stove
## state per placed stove; storage counts positive.
static func _check_floor(state: GameState, data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	if state.floor_rows < 1 or state.floor_width < 1:
		errors.append("floor of %d x %d" % [state.floor_width, state.floor_rows])
		return errors
	var uids: Dictionary[String, bool] = {}
	for placed: PlacedPiece in state.placed:
		if placed.uid == "" or uids.has(placed.uid) or not data.pieces.has(placed.piece_id):
			errors.append("bad placed piece '%s' (%s)" % [placed.uid, placed.piece_id])
			continue
		uids[placed.uid] = true
		var spot := Layout.check_spot(state, placed.piece_id, placed.cell, placed.rotated, data, placed.uid)
		if spot != GameLoop.OK:
			errors.append("placed piece '%s': %s" % [placed.uid, spot])
	if errors.is_empty():
		var stove_pieces := state.placed.filter(func(placed: PlacedPiece) -> bool:
			return data.pieces[placed.piece_id].kind == Piece.STOVE)
		if stove_pieces.size() != state.stoves.size():
			errors.append("%d stoves for %d stove pieces" % [state.stoves.size(), stove_pieces.size()])
		for placed: PlacedPiece in stove_pieces:
			if Layout.stove_of(state, placed.uid) == null:
				errors.append("stove piece '%s' has no stove" % placed.uid)
	for piece_id: String in state.storage:
		if not data.pieces.has(piece_id) or state.storage[piece_id] <= 0:
			errors.append("bad storage entry '%s'" % piece_id)
	return errors


## Writes atomically: temp file, previous save kept as .bak, then rename.
static func save(state: GameState, path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# full precision so battery and satisfaction load back exactly
	if not file.store_string(JSON.stringify(to_dict(state), "\t", true, true)):
		file.close()
		return ERR_FILE_CANT_WRITE
	file.close()
	if FileAccess.file_exists(path):
		var error := DirAccess.rename_absolute(path, path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(temp, path)


static func save_slot(state: GameState, slot: int) -> Error:
	if slot < 0 or slot >= SLOTS:
		return ERR_PARAMETER_RANGE_ERROR
	return save(state, slot_path(slot))


static func autosave(state: GameState) -> Error:
	return save(state, autosave_path())


## Loads a save, or its .bak when the save is missing or unusable. Returns null
## (with the reasons in errors) if neither can be used.
static func load_file(path: String, data: GameData, errors: PackedStringArray) -> GameState:
	var main_errors: PackedStringArray = []
	var state := _load_one(path, data, main_errors)
	if state != null:
		return state
	var backup_errors: PackedStringArray = []
	state = _load_one(path + ".bak", data, backup_errors)
	if state != null:
		return state
	errors.append_array(main_errors)
	for error: String in backup_errors:
		errors.append("backup: " + error)
	return null


## True if the slot or its backup has a file (it may still fail to load).
static func has_save(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


static func delete_save(path: String) -> void:
	for file: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


static func _load_one(path: String, data: GameData, errors: PackedStringArray) -> GameState:
	if not FileAccess.file_exists(path):
		errors.append("no save at %s" % path)
		return null
	# JSON.parse would log an engine error for a broken file; this only reports it.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		errors.append("%s is not valid JSON" % path)
		return null
	var raw: Dictionary = json.data
	var current := migrate(raw, errors)
	if current.is_empty():
		return null
	var state := from_dict(current)
	if current.get("needs_layout", false):
		_lay_out_old(state, current, data)
	if current.get("needs_counter", false) and Layout.count_placed(state, Piece.COUNTER, data) == 0:
		while not Layout.auto_place(state, Piece.COUNTER, data):
			state.floor_rows += 2
	if current.get("needs_bin", false) and Layout.count_placed(state, Piece.BIN, data) == 0 			and data.balance.start_bins > 0 and not Layout.auto_place(state, Piece.BIN, data):
		state.storage[Piece.BIN] = state.storage.get(Piece.BIN, 0) + 1
	Roles.bind_free(state, data)
	if current.get("needs_fashion", false):
		for fashion_id: String in data.items.starter_fashion:
			state.inventory.append(Items.make(state, Item.FASHION, fashion_id))
	if current.get("needs_tables", false):
		Layout.give_tables(state, data)
	if current.get("needs_register", false) and data.balance.start_registers > 0:
		if Layout.count_placed(state, Piece.REGISTER, data) == 0:
			while not Layout.auto_place(state, Piece.REGISTER, data):
				state.floor_rows += 2
		if not state.synths.any(func(synth: Synth) -> bool: return synth.role == Synth.CASHIER) \
				and data.balance.starter_cashier_species != "":
			state.pods += 1
			state.add_starter_cashier(data)
	Layout.refresh(state, data)
	if current.get("needs_counter_fill", false):
		Counters.fill_from_pool(state, data)
	elif Counters.in_use(state, data):
		Counters.recount(state)
	errors.append_array(validate(state, data))
	return null if not errors.is_empty() else state
