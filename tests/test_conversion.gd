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
	assert_eq(created[0].battery_max, 50, "max battery rolled in the species range")
	assert_eq(created[0].battery, 35.0, "lost 30% of max battery in the Pod")
	assert_eq(created[0].role, Synth.REST, "starts Resting in its Pod")
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
	state.convertible_by_id(setup[1]).starred = false
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


func test_max_battery_is_rolled_per_unit() -> void:
	var data := GameData.load_default()
	var rolled: Dictionary[int, bool] = {}
	for seed_value: int in 30:
		var state := GameState.new_game(seed_value, data)
		var starter := state.synths[0]
		var range_of := data.species[starter.species_id].battery_range
		assert_true(starter.battery_max >= range_of.x and starter.battery_max <= range_of.y, "starter in its species range")
		assert_eq(starter.battery, float(starter.battery_max), "starter starts full")
		rolled[starter.battery_max] = true
	assert_true(rolled.size() > 5, "max battery differs between units")
	for species: Species in data.species.values():
		assert_true(species.battery_range.x >= 70 and species.battery_range.y <= 200, "%s: within 70-200" % species.id)
	assert_eq(data.species["bulkform"].battery_range, Vector2i(130, 200), "Bulkform leans high")
	assert_eq(data.species["hypeform"].battery_range, Vector2i(70, 140), "Hypeform leans low")


func test_customer_brings_their_max_battery() -> void:
	var data := TestFixtures.data()
	var setup := _starred(data)
	var state: GameState = setup[0]
	var customer := state.convertible_by_id(setup[1])
	assert_eq(customer.battery_max, 50, "rolled on arrival")
	customer.battery_max = 0
	var created: Array[Synth] = []
	assert_eq(GameLoop.convert_customer(state, setup[1], data, created), GameLoop.OK, "old-save customer converts")
	assert_eq(created[0].battery_max, 50, "rolled at conversion instead")


func test_old_synths_keep_the_species_max() -> void:
	var data := TestFixtures.data()
	var synth := Synth.from_dict({"id": "synth_9", "species_id": "worker", "role": "server", "battery": 20.0, "level": 1, "xp": 0})
	assert_eq(synth.battery_max, 0, "no rolled max in the old save")
	assert_eq(SynthStats.stat(synth, "battery_max", data), 50.0, "species battery_max")
	assert_eq(SynthStats.battery_percent(synth, data), 40, "battery as a percentage")
