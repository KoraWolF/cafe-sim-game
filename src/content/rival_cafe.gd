class_name RivalCafe
extends RefCounted
## A MegaBean café the player can raid at night.

var id: String = ""
## Each defender: {"power": float, "hp": float, "class": combat class, "level": int}
## (its level at the district's start; guards grow with the days, see NightOps).
var defenders: Array[Dictionary] = []
var loot_coins: int = 0
var loot_cores: int = 0
## Influence a won raid earns in the rival's district (flagships give none).
var influence: int = 0
## A hand-made layout (see RaidField): rows deep (0 = generated) and its pieces
## [{"piece_id", "cell": Vector2i, "rotated"}].
var layout_rows: int = 0
var layout_pieces: Array[Dictionary] = []


static func from_dict(values: Dictionary) -> RivalCafe:
	var rival := RivalCafe.new()
	rival.id = values.get("id", "")
	for entry: Variant in values.get("defenders", []):
		if entry is Dictionary:
			rival.defenders.append({"power": float(entry.get("power", 0.0)), "hp": float(entry.get("hp", 1.0)),
				"class": str(entry.get("class", CombatConfig.FIGHTER)), "level": int(entry.get("level", 1))})
	rival.loot_coins = int(values.get("loot_coins", 0))
	rival.loot_cores = int(values.get("loot_cores", 0))
	rival.influence = int(values.get("influence", 0))
	var layout: Variant = values.get("layout", {})
	if layout is Dictionary and int(layout.get("rows", 0)) > 0:
		rival.layout_rows = int(layout["rows"])
		for entry: Variant in layout.get("pieces", []):
			if entry is Dictionary and entry.get("cell", []) is Array and (entry["cell"] as Array).size() == 2:
				rival.layout_pieces.append({"piece_id": str(entry.get("piece", "")),
					"cell": Vector2i(int(entry["cell"][0]), int(entry["cell"][1])), "rotated": bool(entry.get("rotated", false))})
	return rival
