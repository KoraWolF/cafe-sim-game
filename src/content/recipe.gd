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
## Cookable only while the player has a Synth of this species ("" = see source).
var unlock_species: String = ""
## How the player gets it: "start", "story" or "achievement" (a quest reward),
## "raid" (a won raid may drop it) or "defense" (holding off MegaBean may drop it).
var source: String = ""


static func from_dict(values: Dictionary) -> Recipe:
	var recipe := Recipe.new()
	recipe.id = values.get("id", "")
	recipe.cook_seconds = int(values.get("cook_seconds", 0))
	recipe.servings = int(values.get("servings", 0))
	recipe.cost = int(values.get("cost", 0))
	recipe.price = int(values.get("price", 0))
	recipe.unlock_species = values.get("unlock_species", "")
	recipe.source = values.get("source", "")
	return recipe
