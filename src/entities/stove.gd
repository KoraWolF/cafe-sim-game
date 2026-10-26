class_name Stove
extends Resource
## One cooking spot: the cooking state of a placed stove piece. Idle when
## recipe_id is "".

## The PlacedPiece this stove stands on.
@export var piece_uid: String = ""
@export var recipe_id: String = ""
## Cooking work left (cook_seconds at kitchen speed 1.0).
@export var remaining: float = 0.0


func is_idle() -> bool:
	return recipe_id == ""


func to_dict() -> Dictionary:
	return {"piece_uid": piece_uid, "recipe_id": recipe_id, "remaining": remaining}


static func from_dict(values: Dictionary) -> Stove:
	var stove := Stove.new()
	stove.piece_uid = str(values.get("piece_uid", ""))
	stove.recipe_id = str(values.get("recipe_id", ""))
	stove.remaining = float(values.get("remaining", 0.0))
	return stove
