class_name ItemCatalog
extends RefCounted
## Item content from /data/items.json: equipment tiers and kinds, fashion
## pieces, EXP bottles, crafting recipes and raid loot. Every number lives
## here so tiers and drops are easy to change.

## Tier id -> {"sell": int, "bonus": {stat: amount}}, in order (common first).
var tiers: Dictionary[String, Dictionary] = {}
var tier_order: Array[String] = []
## Equipment kind id -> {"slot", "stat"}.
var equipment: Dictionary[String, Dictionary] = {}
## Fashion id -> {"slot", "color"}.
var fashion: Dictionary[String, Dictionary] = {}
var starter_fashion: Array[String] = []
## Bottle id -> {"xp", "weight", "min_day"}.
var bottles: Dictionary[String, Dictionary] = {}
## Craft id -> {"scrap", "chips", "tiers": {tier: weight}}.
var crafts: Dictionary[String, Dictionary] = {}
var raid_loot: Dictionary = {}


static func from_dict(values: Dictionary) -> ItemCatalog:
	var catalog := ItemCatalog.new()
	for entry: Variant in values.get("tiers", []):
		catalog.tiers[str(entry["id"])] = {"sell": int(entry.get("sell", 0)), "bonus": entry.get("bonus", {})}
		catalog.tier_order.append(str(entry["id"]))
	for entry: Variant in values.get("equipment", []):
		catalog.equipment[str(entry["id"])] = {"slot": str(entry["slot"]), "stat": str(entry["stat"])}
	for entry: Variant in values.get("fashion", []):
		catalog.fashion[str(entry["id"])] = {"slot": str(entry["slot"]), "color": str(entry.get("color", "ffffff"))}
	catalog.starter_fashion.assign(values.get("starter_fashion", []))
	for entry: Variant in values.get("bottles", []):
		catalog.bottles[str(entry["id"])] = {"xp": int(entry["xp"]), "weight": float(entry.get("weight", 1.0)),
			"min_day": int(entry.get("min_day", 1))}
	for entry: Variant in values.get("crafts", []):
		catalog.crafts[str(entry["id"])] = {"scrap": int(entry.get("scrap", 0)), "chips": int(entry.get("chips", 0)),
			"tiers": entry.get("tiers", {})}
	catalog.raid_loot = values.get("raid_loot", {})
	return catalog


## Every broken reference inside the catalog.
func check() -> PackedStringArray:
	var errors: PackedStringArray = []
	for kind: Dictionary in equipment.values():
		if not Item.EQUIPMENT_SLOTS.has(kind["slot"]):
			errors.append("equipment slot '%s' unknown" % kind["slot"])
	for piece: Dictionary in fashion.values():
		if not Item.FASHION_SLOTS.has(piece["slot"]):
			errors.append("fashion slot '%s' unknown" % piece["slot"])
	for fashion_id: String in starter_fashion:
		if not fashion.has(fashion_id):
			errors.append("starter fashion '%s' unknown" % fashion_id)
	var weighted: Array = [raid_loot.get("tiers", {}), raid_loot.get("flagship_tiers", {})]
	for craft: Dictionary in crafts.values():
		weighted.append(craft["tiers"])
	for weights: Dictionary in weighted:
		for tier: String in weights:
			if not tiers.has(tier):
				errors.append("unknown tier '%s'" % tier)
	return errors
