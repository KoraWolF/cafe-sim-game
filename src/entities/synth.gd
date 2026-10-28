class_name Synth
extends Resource
## A converted customer working in the café.

const SERVER: String = "server"
const CHEF: String = "chef"
## Works a register: customers pay there on the way out.
const CASHIER: String = "cashier"
## Off duty: does no work and does not drain.
const REST: String = "rest"
const ROLES: Array[String] = [SERVER, CHEF, CASHIER, REST]

@export var id: String = ""
@export var name: String = ""
@export var species_id: String = ""
## "" = no trait.
@export var trait_id: String = ""
@export var role: String = SERVER
## Chef: the stove piece it works; Cashier: its register ("" = none; see Roles).
@export var station_uid: String = ""
@export var battery: float = 0.0
## This unit's max battery (0 = the species' battery_max: saves from before units rolled their own).
@export var battery_max: int = 0
@export var level: int = 1
## XP toward the next level.
@export var xp: int = 0
## The customer whose dish this server is carrying ("" = idle).
@export var task_customer_id: String = ""
@export var task_recipe_id: String = ""
## Work left on the current trip, and the whole trip, in seconds at speed 1.0
## (walking from where it stands to the pick-up and on to the drop-off; see Shift).
@export var task_remaining: float = 0.0
@export var task_total: float = 0.0
## The placed piece a Server last stopped at ("" = by the kitchen): trips start from here.
@export var spot_uid: String = ""
## Carrying a finished batch: from this stove piece ("" = not carrying)...
@export var task_stove_uid: String = ""
## ...to this counter. While delivering: the counter the dish came from.
## While throwing food away: the counter or stove it came from.
@export var task_counter_uid: String = ""
## Throwing food away: the bin it goes to ("" = not throwing away).
@export var task_bin_uid: String = ""
## Equipment and fashion it wears (one per slot; see Items).
@export var items: Array[Item] = []


func is_delivering() -> bool:
	return task_customer_id != ""


func is_carrying() -> bool:
	return task_stove_uid != ""


func is_discarding() -> bool:
	return task_bin_uid != ""


func is_busy() -> bool:
	return is_delivering() or is_carrying() or is_discarding()


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "species_id": species_id, "trait_id": trait_id, "role": role, "station_uid": station_uid,
		"battery": battery, "battery_max": battery_max, "level": level, "xp": xp, "task_customer_id": task_customer_id, "task_recipe_id": task_recipe_id,
		"task_remaining": task_remaining, "task_total": task_total, "spot_uid": spot_uid, "task_stove_uid": task_stove_uid, "task_counter_uid": task_counter_uid, "task_bin_uid": task_bin_uid,
		"items": items.map(func(item: Item) -> Dictionary: return item.to_dict())}


static func from_dict(values: Dictionary) -> Synth:
	var synth := Synth.new()
	synth.id = str(values.get("id", ""))
	synth.name = str(values.get("name", ""))
	synth.species_id = str(values.get("species_id", ""))
	synth.trait_id = str(values.get("trait_id", ""))
	synth.role = str(values.get("role", ""))
	if synth.role == "greeter":
		synth.role = SERVER  # the Greeter role is gone
	synth.station_uid = str(values.get("station_uid", ""))
	synth.battery = float(values.get("battery", 0.0))
	synth.battery_max = int(values.get("battery_max", 0))
	synth.level = int(values.get("level", 0))
	synth.xp = int(values.get("xp", -1))
	synth.task_customer_id = str(values.get("task_customer_id", ""))
	synth.task_recipe_id = str(values.get("task_recipe_id", ""))
	synth.task_remaining = float(values.get("task_remaining", 0.0))
	synth.task_total = maxf(float(values.get("task_total", 0.0)), synth.task_remaining)
	synth.spot_uid = str(values.get("spot_uid", ""))
	synth.task_stove_uid = str(values.get("task_stove_uid", ""))
	synth.task_counter_uid = str(values.get("task_counter_uid", ""))
	synth.task_bin_uid = str(values.get("task_bin_uid", ""))
	var worn: Variant = values.get("items", [])
	if worn is Array:
		for entry: Variant in worn:
			if entry is Dictionary:
				synth.items.append(Item.from_dict(entry))
	return synth
