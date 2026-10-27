class_name Customer
extends Resource
## A customer in the café during a shift.

enum Stage {
	QUEUED, ## Waiting for a free seat.
	WAITING_FOOD, ## Seated, has ordered; a server may already be carrying it.
	EATING,
	STAR, ## Finished fully satisfied and leaving: can be converted until the window ends.
}

@export var id: String = ""
@export var type_id: String = ""
@export var stage: Stage = Stage.QUEUED
## 0..100.
@export var satisfaction: float = 100.0
## Seconds waited in the current stage (queue or table).
@export var waited: int = 0
## Seconds left eating, or left in the star window.
@export var timer: int = 0
@export var recipe_id: String = ""
## Synth carrying this customer's dish ("" = nobody yet).
@export var served_by: String = ""
## Tip bonus of the Synth who served the dish.
@export var tip_bonus: float = 0.0
## The trait this customer brings if converted, rolled on arrival so the player
## can choose who to convert ("" = no trait; older saves roll at conversion).
@export var trait_id: String = ""
## The placed seat this customer sits at ("" while queued).
@export var seat_uid: String = ""
## Max battery this customer would have as a Synth, rolled on arrival
## (0 = not rolled yet: older saves roll at conversion).
@export var battery_max: int = 0


func is_seated() -> bool:
	return stage == Stage.WAITING_FOOD or stage == Stage.EATING


func to_dict() -> Dictionary:
	return {"id": id, "type_id": type_id, "stage": stage, "satisfaction": satisfaction, "waited": waited,
		"timer": timer, "recipe_id": recipe_id, "served_by": served_by, "tip_bonus": tip_bonus,
		"trait_id": trait_id, "seat_uid": seat_uid, "battery_max": battery_max}


static func from_dict(values: Dictionary) -> Customer:
	var customer := Customer.new()
	customer.id = str(values.get("id", ""))
	customer.type_id = str(values.get("type_id", ""))
	customer.stage = int(values.get("stage", -1)) as Stage
	customer.satisfaction = float(values.get("satisfaction", 0.0))
	customer.waited = int(values.get("waited", 0))
	customer.timer = int(values.get("timer", 0))
	customer.recipe_id = str(values.get("recipe_id", ""))
	customer.served_by = str(values.get("served_by", ""))
	customer.tip_bonus = float(values.get("tip_bonus", 0.0))
	customer.trait_id = str(values.get("trait_id", ""))
	customer.seat_uid = str(values.get("seat_uid", ""))
	customer.battery_max = int(values.get("battery_max", 0))
	return customer
