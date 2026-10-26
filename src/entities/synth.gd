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
