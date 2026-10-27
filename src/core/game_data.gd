class_name GameData
extends RefCounted
## All content definitions, looked up by id. Not saved: only GameState is.

const PATHS: Dictionary[String, String] = {
	"balance": "res://data/balance.json",
	"recipes": "res://data/recipes.json",
	"customer_types": "res://data/customer_types.json",
	"species": "res://data/species.json",
	"traits": "res://data/traits.json",
	"districts": "res://data/districts.json",
	"upgrades": "res://data/upgrades.json",
	"pieces": "res://data/pieces.json",
	"adjacency": "res://data/adjacency.json",
}

var balance: BalanceConfig
var recipes: Dictionary[String, Recipe] = {}
var customer_types: Dictionary[String, CustomerType] = {}
var species: Dictionary[String, Species] = {}
var traits: Dictionary[String, SynthTrait] = {}
var districts: Dictionary[String, District] = {}
## District ids in the order they open (the order of districts.json).
var district_order: Array[String] = []
var upgrades: Dictionary[String, Upgrade] = {}
var pieces: Dictionary[String, Piece] = {}
var adjacency: Array[AdjacencyRule] = []


## Loads everything from /data. Returns null (and logs why) if it is invalid.
static func load_default() -> GameData:
	var content := {}
	for key: String in PATHS:
		content[key] = JSON.parse_string(FileAccess.get_file_as_string(PATHS[key]))
	return from_content(content)


## Builds data from parsed JSON: {"balance": {...}, "recipes": [...], ...}.
## Tests pass their own content here.
static func from_content(content: Dictionary) -> GameData:
	var data := GameData.new()
	var balance: Variant = content.get("balance")
	if not balance is Dictionary:
		push_error("GameData: balance must be a JSON object")
		return null
	data.balance = BalanceConfig.from_dict(balance)
	for entry: Dictionary in _objects(content.get("recipes"), "recipes"):
		var recipe := Recipe.from_dict(entry)
		data.recipes[recipe.id] = recipe
	for entry: Dictionary in _objects(content.get("customer_types"), "customer_types"):
		var type := CustomerType.from_dict(entry)
		data.customer_types[type.id] = type
	for entry: Dictionary in _objects(content.get("species"), "species"):
		var one := Species.from_dict(entry)
		data.species[one.id] = one
	for entry: Dictionary in _objects(content.get("traits"), "traits"):
		var synth_trait := SynthTrait.from_dict(entry)
		data.traits[synth_trait.id] = synth_trait
	for entry: Dictionary in _objects(content.get("districts"), "districts"):
		var district := District.from_dict(entry)
		data.districts[district.id] = district
		data.district_order.append(district.id)
	for entry: Dictionary in _objects(content.get("upgrades"), "upgrades"):
		var upgrade := Upgrade.from_dict(entry)
		data.upgrades[upgrade.id] = upgrade
	for entry: Dictionary in _objects(content.get("pieces"), "pieces"):
		var piece := Piece.from_dict(entry)
		data.pieces[piece.id] = piece
	for entry: Dictionary in _objects(content.get("adjacency"), "adjacency"):
		data.adjacency.append(AdjacencyRule.from_dict(entry))
	var errors := data.check()
	if not errors.is_empty():
		push_error("GameData: invalid content: %s" % "; ".join(errors))
		return null
	return data


static func _objects(parsed: Variant, source: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not parsed is Array:
		push_error("GameData: %s must be a JSON array" % source)
		return result
	for entry: Variant in parsed:
		if entry is Dictionary:
			result.append(entry)
		else:
			push_error("GameData: %s has an entry that is not an object" % source)
	return result


## The district that opens after this one, or "" for the last.
func next_district(district_id: String) -> String:
	var index := district_order.find(district_id)
	return district_order[index + 1] if index >= 0 and index + 1 < district_order.size() else ""


## Every broken cross-reference, so systems can trust ids.
func check() -> PackedStringArray:
	var errors: PackedStringArray = []
	if recipes.is_empty():
		errors.append("no recipes")
	if customer_types.is_empty():
		errors.append("no customer types")
	if not species.has(balance.starter_species):
		errors.append("starter species '%s' is unknown" % balance.starter_species)
	if not districts.has(balance.start_district):
		errors.append("start district '%s' is unknown" % balance.start_district)
	for type: CustomerType in customer_types.values():
		if not species.has(type.synth_species):
			errors.append("customer type %s: unknown species '%s'" % [type.id, type.synth_species])
		for trait_id: String in type.trait_pool:
			if not traits.has(trait_id):
				errors.append("customer type %s: unknown trait '%s'" % [type.id, trait_id])
		for recipe_id: String in type.favorites:
			if not recipes.has(recipe_id):
				errors.append("customer type %s: unknown favourite '%s'" % [type.id, recipe_id])
	for one: Species in species.values():
		if not Synth.ROLES.has(one.best_role):
			errors.append("species %s: unknown role '%s'" % [one.id, one.best_role])
	for recipe: Recipe in recipes.values():
		if recipe.unlock_species != "" and not species.has(recipe.unlock_species):
			errors.append("recipe %s: unknown species '%s'" % [recipe.id, recipe.unlock_species])
		if recipe.cook_seconds <= 0 or recipe.servings <= 0:
			errors.append("recipe %s: cook_seconds and servings must be positive" % recipe.id)
	var rival_ids: Dictionary[String, bool] = {}
	for district: District in districts.values():
		if district.flagship == null:
			errors.append("district %s: no flagship" % district.id)
		if district.influence_required <= 0:
			errors.append("district %s: influence_required must be positive" % district.id)
		var cafes := district.rivals.duplicate()
		if district.flagship != null:
			cafes.append(district.flagship)
		for rival: RivalCafe in cafes:
			if rival_ids.has(rival.id) or rival.defenders.is_empty():
				errors.append("rival %s: duplicate id or no defenders" % rival.id)
			rival_ids[rival.id] = true
	# Furniture pieces share their kind's id: the stove upgrade gives a "stove" piece.
	for kind: String in [Piece.SEAT, Piece.TABLE, Piece.STOVE, Piece.COUNTER, Piece.BIN]:
		if not pieces.has(kind) or pieces[kind].kind != kind:
			errors.append("furniture piece '%s' is missing" % kind)
	for piece: Piece in pieces.values():
		if not Piece.KINDS.has(piece.kind):
			errors.append("piece %s: unknown kind '%s'" % [piece.id, piece.kind])
		if piece.size.x < 1 or piece.size.y < 1 or maxi(piece.size.x, piece.size.y) > balance.floor_width:
			errors.append("piece %s: bad size" % piece.id)
		if piece.kind == Piece.DECOR and piece.price <= 0:
			errors.append("piece %s: décor needs a price" % piece.id)
	for rule: AdjacencyRule in adjacency:
		if rule.tag_a == "" or rule.tag_b == "":
			errors.append("adjacency rule needs two tags")
	for upgrade_id: String in Upgrade.IDS:
		if not upgrades.has(upgrade_id):
			errors.append("upgrade '%s' is missing" % upgrade_id)
	for upgrade: Upgrade in upgrades.values():
		if not Upgrade.IDS.has(upgrade.id):
			errors.append("unknown upgrade '%s'" % upgrade.id)
		if upgrade.step <= 0.0 or upgrade.max_level < 0:
			errors.append("upgrade %s: step must be positive, max_level not negative" % upgrade.id)
	return errors
