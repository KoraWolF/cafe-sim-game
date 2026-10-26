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

const VERSION: int = 1
const SAVE_DIR: String = "user://saves"
const SLOTS: int = 3
## Old version -> function turning that save's dictionary into the next version's.
## Add an entry every time VERSION goes up.
const MIGRATIONS: Dictionary[int, Callable] = {}


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
		"seats": state.seats,
		"pods": state.pods,
		"security": state.security,
		"upgrades": state.upgrades,
		"stoves": state.stoves.map(func(stove: Stove) -> Dictionary: return stove.to_dict()),
		"counter": state.counter,
		"customers": state.customers.map(func(customer: Customer) -> Dictionary: return customer.to_dict()),
		"synths": state.synths.map(func(synth: Synth) -> Dictionary: return synth.to_dict()),
		"district_id": state.district_id,
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
	state.seats = int(raw.get("seats", 0))
	state.pods = int(raw.get("pods", 0))
	state.security = float(raw.get("security", 0.0))
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
	for entry: Dictionary in _objects(raw, "customers"):
		state.customers.append(Customer.from_dict(entry))
	for entry: Dictionary in _objects(raw, "synths"):
		state.synths.append(Synth.from_dict(entry))
	state.district_id = str(raw.get("district_id", ""))
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
		if not MIGRATIONS.has(version):
			errors.append("unsupported save version %d" % version)
			return {}
		raw = MIGRATIONS[version].call(raw)
		version += 1
		raw["version"] = version
	return raw


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
	if state.seats < 0 or state.pods < state.synths.size():
		errors.append("%d seats, %d pods for %d Synths" % [state.seats, state.pods, state.synths.size()])
	for upgrade_id: String in state.upgrades:
		var upgrade: Upgrade = data.upgrades.get(upgrade_id)
		if upgrade == null or state.upgrades[upgrade_id] < 0 or state.upgrades[upgrade_id] > upgrade.max_level:
			errors.append("bad upgrade level '%s'" % upgrade_id)
	if not data.districts.has(state.district_id):
		errors.append("unknown district '%s'" % state.district_id)
	for district_id: String in state.suspicion:
		if not data.districts.has(district_id):
			errors.append("suspicion for unknown district '%s'" % district_id)
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
	for customer: Customer in state.customers:
		if ids.has(customer.id) or customer.id == "":
			errors.append("duplicate or empty customer id '%s'" % customer.id)
		ids[customer.id] = true
		if not data.customer_types.has(customer.type_id):
			errors.append("customer '%s': unknown type '%s'" % [customer.id, customer.type_id])
		if not Customer.Stage.values().has(customer.stage):
			errors.append("customer '%s': unknown stage %d" % [customer.id, customer.stage])
		if customer.stage != Customer.Stage.QUEUED and not data.recipes.has(customer.recipe_id):
			errors.append("customer '%s': unknown recipe '%s'" % [customer.id, customer.recipe_id])
		if customer.served_by != "" and state.synth_by_id(customer.served_by) == null:
			errors.append("customer '%s': served by unknown Synth" % customer.id)
	if state.phase == GameState.Phase.NIGHT and not state.customers.is_empty():
		errors.append("customers in the café at night")
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
	errors.append_array(validate(state, data))
	return null if not errors.is_empty() else state
