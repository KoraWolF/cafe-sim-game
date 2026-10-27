class_name Item
extends Resource
## One owned piece: equipment (a stat bonus by tier) or fashion (looks only).
## Each piece is unique: it is in the inventory or worn by one Synth.

const EQUIPMENT: String = "equipment"
const FASHION: String = "fashion"
const EQUIPMENT_SLOTS: Array[String] = ["ring", "boots", "amulet"]
const FASHION_SLOTS: Array[String] = ["hat", "outfit"]

@export var uid: String = ""
@export var kind: String = EQUIPMENT
## Equipment kind id or fashion id (see ItemCatalog).
@export var type_id: String = ""
## Equipment only.
@export var tier: String = ""


func slot(catalog: ItemCatalog) -> String:
	return catalog.equipment[type_id]["slot"] if kind == EQUIPMENT else catalog.fashion[type_id]["slot"]


## {stat: bonus} this piece gives (empty for fashion).
func bonus(catalog: ItemCatalog) -> Dictionary:
	if kind != EQUIPMENT:
		return {}
	var stat: String = catalog.equipment[type_id]["stat"]
	return {stat: float(catalog.tiers[tier]["bonus"].get(stat, 0.0))}


func to_dict() -> Dictionary:
	return {"uid": uid, "kind": kind, "type_id": type_id, "tier": tier}


static func from_dict(values: Dictionary) -> Item:
	var item := Item.new()
	item.uid = str(values.get("uid", ""))
	item.kind = str(values.get("kind", EQUIPMENT))
	item.type_id = str(values.get("type_id", ""))
	item.tier = str(values.get("tier", ""))
	return item
