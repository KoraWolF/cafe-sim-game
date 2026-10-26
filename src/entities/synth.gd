class_name Synth
extends Resource
## A converted customer working in the café.

const SERVER: String = "server"
const CHEF: String = "chef"
const GREETER: String = "greeter"
## Off duty: does no work and does not drain.
const REST: String = "rest"
const ROLES: Array[String] = [SERVER, CHEF, GREETER, REST]

@export var id: String = ""
@export var name: String = ""
@export var species_id: String = ""
## "" = no trait.
@export var trait_id: String = ""
@export var role: String = SERVER
@export var battery: float = 0.0
## The customer whose dish this server is carrying ("" = idle).
@export var task_customer_id: String = ""
@export var task_recipe_id: String = ""
## Delivery work left (delivery_seconds at speed 1.0).
@export var task_remaining: float = 0.0


func is_delivering() -> bool:
	return task_customer_id != ""


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "species_id": species_id, "trait_id": trait_id, "role": role,
		"battery": battery, "task_customer_id": task_customer_id, "task_recipe_id": task_recipe_id,
		"task_remaining": task_remaining}


static func from_dict(values: Dictionary) -> Synth:
	var synth := Synth.new()
	synth.id = str(values.get("id", ""))
	synth.name = str(values.get("name", ""))
	synth.species_id = str(values.get("species_id", ""))
	synth.trait_id = str(values.get("trait_id", ""))
	synth.role = str(values.get("role", ""))
	synth.battery = float(values.get("battery", 0.0))
	synth.task_customer_id = str(values.get("task_customer_id", ""))
	synth.task_recipe_id = str(values.get("task_recipe_id", ""))
	synth.task_remaining = float(values.get("task_remaining", 0.0))
	return synth
