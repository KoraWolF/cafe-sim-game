class_name RivalCafe
extends RefCounted
## A MegaBean café the player can raid at night.

var id: String = ""
## Each defender: {"power": float, "hp": float}.
var defenders: Array[Dictionary] = []
var loot_coins: int = 0
var loot_cores: int = 0


static func from_dict(values: Dictionary) -> RivalCafe:
	var rival := RivalCafe.new()
	rival.id = values.get("id", "")
	for entry: Variant in values.get("defenders", []):
		if entry is Dictionary:
			rival.defenders.append({"power": float(entry.get("power", 0.0)), "hp": float(entry.get("hp", 1.0))})
	rival.loot_coins = int(values.get("loot_coins", 0))
	rival.loot_cores = int(values.get("loot_cores", 0))
	return rival
