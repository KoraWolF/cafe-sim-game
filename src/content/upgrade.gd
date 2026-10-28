class_name Upgrade
extends RefCounted
## A café upgrade bought at night. Its id says what it adds (see IDS); the
## numbers come from /data/upgrades.json.

## Things that are not on the floor: furniture and décor are bought by the
## piece (Piece.price), as many as fit.
## Pod upgrades add a Sync Pod to the Pod bay outside the café.
const POD: String = "pod"
## A bigger floor: level n makes it sizes[n - 1] tiles square.
const FLOOR: String = "floor"
## Extra HP for each home defender.
const SECURITY: String = "security"
const IDS: Array[String] = [POD, FLOOR, SECURITY]

var id: String = ""
## How much one purchase adds.
var step: float = 1.0
## Level n (0 = none bought yet) costs base_cost * cost_growth^n.
var base_cost: int = 0
var cost_growth: float = 1.0
var max_level: int = 0
## The floor's side after each level (the floor upgrade; max_level follows it).
var sizes: Array[int] = []


static func from_dict(values: Dictionary) -> Upgrade:
	var upgrade := Upgrade.new()
	upgrade.id = values.get("id", "")
	upgrade.step = float(values.get("step", 1.0))
	upgrade.base_cost = int(values.get("base_cost", 0))
	upgrade.cost_growth = float(values.get("cost_growth", 1.0))
	upgrade.max_level = int(values.get("max_level", 0))
	for size: Variant in values.get("sizes", []):
		upgrade.sizes.append(int(size))
	if not upgrade.sizes.is_empty():
		upgrade.max_level = upgrade.sizes.size()
	return upgrade


func cost_at(level: int) -> int:
	return roundi(base_cost * pow(cost_growth, level))
