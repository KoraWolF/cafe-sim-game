class_name Recipe
extends RefCounted
## A dish: one cook on a stove makes a batch of servings for the counter.

var id: String = ""
## Seconds on one stove at base kitchen speed.
var cook_seconds: int = 0
var servings: int = 0
## Coins to start one batch.
var cost: int = 0
## Coins a fully satisfied customer pays for one serving.
var price: int = 0
## Customers order it only once the player has a Synth of this species ("" = always).
var unlock_species: String = ""


static func from_dict(values: Dictionary) -> Recipe:
	var recipe := Recipe.new()
	recipe.id = values.get("id", "")
	recipe.cook_seconds = int(values.get("cook_seconds", 0))
	recipe.servings = int(values.get("servings", 0))
	recipe.cost = int(values.get("cost", 0))
	recipe.price = int(values.get("price", 0))
	recipe.unlock_species = values.get("unlock_species", "")
	return recipe
