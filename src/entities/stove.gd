class_name Stove
extends Resource
## One cooking spot. Idle when recipe_id is "".

@export var recipe_id: String = ""
## Cooking work left (cook_seconds at kitchen speed 1.0).
@export var remaining: float = 0.0


func is_idle() -> bool:
	return recipe_id == ""
