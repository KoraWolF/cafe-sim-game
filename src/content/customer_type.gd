class_name CustomerType
extends RefCounted
## A kind of customer and the Synth species they become when converted.

var id: String = ""
## Relative spawn chance.
var weight: float = 0.0
var synth_species: String = ""
## Higher = waits longer and loses satisfaction more slowly.
var patience: float = 1.0
## Tip multiplier.
var tip: float = 1.0
## Trait ids a converted Synth of this type can roll.
var trait_pool: Array[String] = []
## Recipe ids this type orders more often and enjoys more (see favorite_weight).
var favorites: Array[String] = []


static func from_dict(values: Dictionary) -> CustomerType:
	var type := CustomerType.new()
	type.id = values.get("id", "")
	type.weight = float(values.get("weight", 0.0))
	type.synth_species = values.get("synth_species", "")
	type.patience = float(values.get("patience", 1.0))
	type.tip = float(values.get("tip", 1.0))
	type.trait_pool.assign(values.get("trait_pool", []))
	type.favorites.assign(values.get("favorites", []))
	return type
