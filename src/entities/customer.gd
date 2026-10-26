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


func is_seated() -> bool:
	return stage == Stage.WAITING_FOOD or stage == Stage.EATING
