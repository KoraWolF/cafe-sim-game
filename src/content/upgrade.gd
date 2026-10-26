class_name Upgrade
extends RefCounted
## A café upgrade bought at night. Its id says what it adds (see IDS); the
## numbers come from /data/upgrades.json.

## Stove, seat and Pod upgrades put a piece in storage, to be placed on the floor.
const STOVE: String = "stove"
const SEAT: String = "seat"
const POD: String = "pod"
## More floor rows.
const FLOOR: String = "floor"
## One more dish on the daily menu.
const MENU_SLOT: String = "menu_slot"
## Extra HP for each home defender.
const SECURITY: String = "security"
const IDS: Array[String] = [STOVE, SEAT, POD, MENU_SLOT, FLOOR, SECURITY]

var id: String = ""
## How much one purchase adds.
var step: float = 1.0
## Level n (0 = none bought yet) costs base_cost * cost_growth^n.
var base_cost: int = 0
var cost_growth: float = 1.0
var max_level: int = 0


static func from_dict(values: Dictionary) -> Upgrade:
	var upgrade := Upgrade.new()
	upgrade.id = values.get("id", "")
	upgrade.step = float(values.get("step", 1.0))
	upgrade.base_cost = int(values.get("base_cost", 0))
	upgrade.cost_growth = float(values.get("cost_growth", 1.0))
	upgrade.max_level = int(values.get("max_level", 0))
	return upgrade


func cost_at(level: int) -> int:
	return roundi(base_cost * pow(cost_growth, level))
