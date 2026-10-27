class_name Customer
extends Resource
## A customer in the café during a shift.

enum Stage {
	QUEUED, ## Waiting for a free seat.
	WAITING_FOOD, ## Seated, has ordered; a server may already be carrying it.
	EATING,
	STAR, ## Paid, starred and leaving: can be converted until the window ends.
	PAYING, ## Finished eating: in line at the register, or paying.
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
## Finished fully satisfied: shows a star and can be converted while paying
## and leaving (STAR).
@export var starred: bool = false
## What they owe at the register: the meal and the tip (tip 0 if they get angry in line).
@export var bill: int = 0
@export var tip: int = 0
## The Cashier taking their payment ("" = still in line), and the work left.
@export var cashier_id: String = ""
@export var pay_left: float = 0.0
## Max battery this customer would have as a Synth, rolled on arrival
## (0 = not rolled yet: older saves roll at conversion).
@export var battery_max: int = 0


func is_seated() -> bool:
	return stage == Stage.WAITING_FOOD or stage == Stage.EATING


## A starred customer on the way out (paying or leaving) can be offered NanoBrew.
func can_convert() -> bool:
	return starred and (stage == Stage.PAYING or stage == Stage.STAR)


func to_dict() -> Dictionary:
	return {"id": id, "type_id": type_id, "stage": stage, "satisfaction": satisfaction, "waited": waited,
		"timer": timer, "recipe_id": recipe_id, "served_by": served_by, "tip_bonus": tip_bonus,
		"trait_id": trait_id, "seat_uid": seat_uid, "battery_max": battery_max, "starred": starred, "bill": bill,
		"tip": tip, "cashier_id": cashier_id, "pay_left": pay_left}


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
	# Older saves: a STAR customer had already paid and was starred.
	customer.starred = bool(values.get("starred", customer.stage == Stage.STAR))
	customer.bill = int(values.get("bill", 0))
	customer.tip = int(values.get("tip", 0))
	customer.cashier_id = str(values.get("cashier_id", ""))
	customer.pay_left = float(values.get("pay_left", 0.0))
	return customer
