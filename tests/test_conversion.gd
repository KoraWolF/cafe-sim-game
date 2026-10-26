extends TestCase
## Turning starred customers into Synths, and brewing NanoBrew.


## A game 12 s in, with one starred "regular" customer; returns [state, customer id].
func _starred(data: GameData) -> Array:
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 3
	var events := GameLoop.advance(state, 12, data)
	assert_eq(events.starred.size(), 1, "setup: starred customer")
	return [state, events.starred[0]]


func test_convert_starred_customer() -> void:
	var data := TestFixtures.data()
	var setup := _starred(data)
	var state: GameState = setup[0]
	var created: Array[Synth] = []
	assert_eq(GameLoop.convert_customer(state, setup[1], data, created), GameLoop.OK, "converted")
	assert_eq(created.size(), 1, "new Synth returned")
	assert_eq(created[0].species_id, "worker", "species from customer type")
	assert_eq(created[0].trait_id, "owl", "trait from the type's pool")
	assert_eq(created[0].battery, 50.0, "full battery")
	assert_eq(state.synths.size(), 2, "joined the staff")
	assert_eq(state.nanobrew, 0, "NanoBrew used")
	assert_eq(state.current_suspicion(), 10.0, "suspicion raised")
	assert_true(state.customer_by_id(setup[1]) == null, "customer is gone")


func test_conversion_needs_star_brew_and_pod() -> void:
	var data := TestFixtures.data()
	var setup := _starred(data)
	var state: GameState = setup[0]
	assert_eq(GameLoop.convert_customer(state, "nobody", data), GameLoop.UNKNOWN_CUSTOMER, "unknown")
	state.nanobrew = 0
	assert_eq(GameLoop.convert_customer(state, setup[1], data), GameLoop.NO_NANOBREW, "no brew")
	state.nanobrew = 1
	state.pods = 1
	assert_eq(GameLoop.convert_customer(state, setup[1], data), GameLoop.NO_FREE_POD, "pods full")
	state.customer_by_id(setup[1]).stage = Customer.Stage.EATING
	state.pods = 2
	assert_eq(GameLoop.convert_customer(state, setup[1], data), GameLoop.NO_STAR, "no star")


func test_converted_xeno_unlocks_its_recipe() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.start_cooking(state, 0, "jelly", data), GameLoop.RECIPE_LOCKED, "locked")
	state.add_synth("alien", "", data)
	assert_eq(GameLoop.start_cooking(state, 0, "jelly", data), GameLoop.OK, "unlocked")


func test_brew_nanobrew() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.brew_nanobrew(state, data), GameLoop.NOT_ENOUGH_CORES, "needs a core")
	state.cores = 1
	assert_eq(GameLoop.brew_nanobrew(state, data), GameLoop.OK, "brewed")
	assert_eq(state.nanobrew, 2, "one more")
	assert_eq(state.cores, 0, "core used")
	assert_eq(state.coins, 70, "coins used")


func test_role_change_waits_for_delivery() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 1
	GameLoop.advance(state, 4, data)
	var starter := state.synths[0]
	assert_true(starter.is_delivering(), "setup: carrying a dish")
	assert_eq(GameLoop.assign_role(state, starter.id, Synth.CHEF), GameLoop.SYNTH_BUSY, "busy")
	assert_eq(GameLoop.assign_role(state, starter.id, "dj"), GameLoop.UNKNOWN_ROLE, "bad role")
