class_name Stove
extends Resource
## One cooking spot: the cooking state of a placed stove piece. Idle when
## recipe_id is "". A finished batch waits on the stove (ready > 0) until a
## server carries it to a counter; the stove can't cook again until then.

## The PlacedPiece this stove stands on.
@export var piece_uid: String = ""
@export var recipe_id: String = ""
## Cooking work left (cook_seconds at kitchen speed 1.0).
@export var remaining: float = 0.0
## Servings of a finished batch waiting to be carried to a counter.
@export var ready: int = 0
## The server on the way with this batch ("" = nobody yet).
@export var carrier: String = ""


func is_idle() -> bool:
	return recipe_id == ""


func has_batch() -> bool:
	return ready > 0


func to_dict() -> Dictionary:
	return {"piece_uid": piece_uid, "recipe_id": recipe_id, "remaining": remaining, "ready": ready, "carrier": carrier}


static func from_dict(values: Dictionary) -> Stove:
	var stove := Stove.new()
	stove.piece_uid = str(values.get("piece_uid", ""))
	stove.recipe_id = str(values.get("recipe_id", ""))
	stove.remaining = float(values.get("remaining", 0.0))
	stove.ready = int(values.get("ready", 0))
	stove.carrier = str(values.get("carrier", ""))
	return stove
