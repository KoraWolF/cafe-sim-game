class_name Counters
extends RefCounted
## What stands on the counters. Each counter (1x1) holds servings of one dish;
## servers carry a finished batch from its stove to the nearest counter that is
## empty or already holds that dish, and serve customers from the counters.
## state.counter keeps the total per dish (what can be served).
##
## A café with no counter piece (only test fixtures) skips all this: batches go
## straight into state.counter, as before counters existed.


static func in_use(state: GameState, data: GameData) -> bool:
	return Layout.count_placed(state, Piece.COUNTER, data) > 0


## The counter a batch of recipe_id from the stove piece at from_uid should go
## to: the nearest one empty or holding that dish (counting batches already on
## their way). "" if none is free.
static func free_counter(state: GameState, recipe_id: String, from_uid: String, data: GameData) -> String:
	var from := Layout.placed_by_uid(state, from_uid)
	var best := ""
	var best_distance := 1 << 30
	for placed: PlacedPiece in state.placed:
		if data.pieces[placed.piece_id].kind != Piece.COUNTER:
			continue
		var dish := dish_on(state, placed.uid)
		if dish != "" and dish != recipe_id:
			continue
		var distance := Layout.distance(from, placed, data) if from != null else 0
		if distance < best_distance:
			best = placed.uid
			best_distance = distance
	return best


## The dish a counter holds, or is reserved for by a batch on its way ("" = free).
static func dish_on(state: GameState, counter_uid: String) -> String:
	if state.counter_count.get(counter_uid, 0) > 0:
		return state.counter_dish.get(counter_uid, "")
	for synth: Synth in state.synths:
		if synth.is_carrying() and synth.task_counter_uid == counter_uid:
			return synth.task_recipe_id
	return ""


static func put(state: GameState, counter_uid: String, recipe_id: String, count: int) -> void:
	state.counter_dish[counter_uid] = recipe_id
	state.counter_count[counter_uid] = state.counter_count.get(counter_uid, 0) + count
	state.counter[recipe_id] = state.counter.get(recipe_id, 0) + count


## Takes one serving of recipe_id from a counter; returns that counter's uid
## ("" in a café without counters, or if there is none).
static func take(state: GameState, recipe_id: String, data: GameData) -> String:
	if state.counter.get(recipe_id, 0) <= 0:
		return ""
	state.counter[recipe_id] -= 1
	if not in_use(state, data):
		return ""
	for counter_uid: String in state.counter_count:
		if state.counter_count[counter_uid] > 0 and state.counter_dish.get(counter_uid, "") == recipe_id:
			state.counter_count[counter_uid] -= 1
			if state.counter_count[counter_uid] <= 0:
				state.counter_count.erase(counter_uid)
				state.counter_dish.erase(counter_uid)
			return counter_uid
	return ""


## Puts one serving back (a dish that was not delivered).
static func give_back(state: GameState, counter_uid: String, recipe_id: String, data: GameData) -> void:
	if counter_uid != "" and Layout.placed_by_uid(state, counter_uid) != null \
			and dish_on(state, counter_uid) in ["", recipe_id]:
		put(state, counter_uid, recipe_id, 1)
	elif in_use(state, data) and free_counter(state, recipe_id, counter_uid, data) != "":
		put(state, free_counter(state, recipe_id, counter_uid, data), recipe_id, 1)
	elif not in_use(state, data):
		state.counter[recipe_id] = state.counter.get(recipe_id, 0) + 1


## Totals from what stands on the counters (after loading).
static func recount(state: GameState) -> void:
	state.counter.clear()
	for counter_uid: String in state.counter_count:
		var recipe_id: String = state.counter_dish.get(counter_uid, "")
		if recipe_id != "":
			state.counter[recipe_id] = state.counter.get(recipe_id, 0) + state.counter_count[counter_uid]


## Saves from before counters held one dish each: spread the ready servings over
## the counters, one dish per counter; dishes left over without a counter are lost.
static func fill_from_pool(state: GameState, data: GameData) -> void:
	var pool := state.counter.duplicate()
	state.counter.clear()
	state.counter_dish.clear()
	state.counter_count.clear()
	for recipe_id: String in pool:
		if pool[recipe_id] <= 0:
			continue
		var counter_uid := free_counter(state, recipe_id, "", data)
		if counter_uid != "":
			put(state, counter_uid, recipe_id, pool[recipe_id])
