class_name CombatConfig
extends RefCounted
## How grid battles work (see Battle), from /data/combat.json. Every key has a
## default here, so content without a "combat" section still fights.
##
## Classes: range (tiles, Chebyshev), attack_interval (seconds between attacks),
## move_speed (tiles per second), armor (share of damage taken away). A fragile
## unit goes for the weakest enemy; the others for the nearest.
## Skills: mana (to cast), and per skill: slam (power x, stun seconds) hits and
## stuns every enemy next to the caster; fortify (shield x max HP); overtime
## (haste x attack speed for seconds); chain (power x on the target and `jumps`
## enemies nearest it); cheer (heal x max HP on the most hurt ally); beam
## (power x on the target).

const TANK: String = "tank"
const FIGHTER: String = "fighter"
const RANGED: String = "ranged"
const FRAGILE: String = "fragile"
const CLASSES: Array[String] = [TANK, FIGHTER, RANGED, FRAGILE]
const SKILLS: Array[String] = ["slam", "fortify", "overtime", "chain", "cheer", "beam"]

## Tiles across, and deep (each side owns half the rows).
var board: Vector2i = Vector2i(8, 6)
var tick_seconds: float = 0.1
## A battle still going after this long is won by the defenders.
var max_seconds: float = 45.0
var mana_per_attack: float = 10.0
var mana_per_hit: float = 5.0
var classes: Dictionary[String, Dictionary] = {
	TANK: {"range": 1, "attack_interval": 1.3, "move_speed": 1.6, "armor": 0.3},
	FIGHTER: {"range": 1, "attack_interval": 1.0, "move_speed": 2.0, "armor": 0.15},
	RANGED: {"range": 3, "attack_interval": 1.1, "move_speed": 1.8, "armor": 0.0},
	FRAGILE: {"range": 1, "attack_interval": 0.7, "move_speed": 2.8, "armor": 0.0},
}
var skills: Dictionary[String, Dictionary] = {
	"slam": {"mana": 80, "power": 1.2, "stun": 1.0},
	"fortify": {"mana": 70, "shield": 0.3},
	"overtime": {"mana": 60, "haste": 1.6, "seconds": 4.0},
	"chain": {"mana": 50, "power": 1.0, "jumps": 2},
	"cheer": {"mana": 60, "heal": 0.3},
	"beam": {"mana": 70, "power": 2.5},
}
## MegaBean raiders on the player's café take these classes in turn.
var megabean_classes: Array[String] = [FIGHTER, RANGED, TANK, FRAGILE]


static func from_dict(values: Dictionary) -> CombatConfig:
	var config := CombatConfig.new()
	var size: Variant = values.get("board", [])
	if size is Array and size.size() == 2:
		config.board = Vector2i(int(size[0]), int(size[1]))
	config.tick_seconds = float(values.get("tick_seconds", config.tick_seconds))
	config.max_seconds = float(values.get("max_seconds", config.max_seconds))
	config.mana_per_attack = float(values.get("mana_per_attack", config.mana_per_attack))
	config.mana_per_hit = float(values.get("mana_per_hit", config.mana_per_hit))
	for key: String in ["classes", "skills"]:
		var given: Variant = values.get(key, {})
		if given is Dictionary:
			var target: Dictionary = config.classes if key == "classes" else config.skills
			for id: String in given:
				if given[id] is Dictionary:
					target[id] = given[id]
	var order: Variant = values.get("megabean_classes", [])
	if order is Array and not order.is_empty():
		config.megabean_classes.assign(order)
	return config


## The rows each side owns: half the board.
func half() -> int:
	return board.y / 2


func value(class_id: String, key: String) -> float:
	return float(classes.get(class_id, classes[FIGHTER]).get(key, classes[FIGHTER][key]))


func check() -> Array[String]:
	var errors: Array[String] = []
	if board.x < 2 or board.y < 2 or board.y % 2 != 0:
		errors.append("combat board must be at least 2 x 2 with an even depth")
	for class_id: String in CLASSES:
		if not classes.has(class_id):
			errors.append("combat class '%s' is missing" % class_id)
	for class_id: String in megabean_classes:
		if not classes.has(class_id):
			errors.append("MegaBean class '%s' is unknown" % class_id)
	if tick_seconds <= 0.0 or max_seconds <= 0.0:
		errors.append("combat tick and length must be positive")
	return errors
