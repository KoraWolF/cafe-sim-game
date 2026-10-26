class_name Stove
extends Resource
## One cooking spot. Idle when recipe_id is "".

@export var recipe_id: String = ""
## Cooking work left (cook_seconds at kitchen speed 1.0).
@export var remaining: float = 0.0


func is_idle() -> bool:
	return recipe_id == ""


func to_dict() -> Dictionary:
	return {"recipe_id": recipe_id, "remaining": remaining}


static func from_dict(values: Dictionary) -> Stove:
	var stove := Stove.new()
	stove.recipe_id = str(values.get("recipe_id", ""))
	stove.remaining = float(values.get("remaining", 0.0))
	return stove
