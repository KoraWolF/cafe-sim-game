extends TestCase
## Playtest 1 fixes: start layout, traits rolled on arrival, explanations.


func test_real_start_puts_pods_in_the_bay_not_on_the_floor() -> void:
	var data := GameData.load_default()
	var state := GameState.new_game(1, data)
	assert_eq(state.pods, 3, "three Pods in the Pod bay")
	assert_true(state.placed.all(func(p: PlacedPiece) -> bool: return p.piece_id != "pod"), "no Pod takes floor space")
	assert_eq(state.seats, 3, "all three seats placed, each at its table")
	assert_eq(state.stoves.size(), 1, "the one stove placed")


func test_start_layout_falls_back_when_a_spot_is_taken() -> void:
	var content := TestFixtures.content()
	content["balance"]["start_layout"] = [{"piece": "stove", "cell": [0, 0]}, {"piece": "stove", "cell": [1, 0]}]
	var data := GameData.from_content(content)
	var state := GameState.new_game(1, data)
	assert_eq(state.stoves.size(), 2, "the overlapping stove went to the first free spot instead")


func test_trait_is_rolled_on_arrival_and_kept_on_conversion() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 3
	var events := GameLoop.advance(state, 4, data)
	var customer := state.customer_by_id(events.arrived[0])
	assert_eq(customer.trait_id, "owl", "rolled from the type's pool on arrival")
	GameLoop.advance(state, 8, data)
	var created: Array[Synth] = []
	assert_eq(GameLoop.convert_customer(state, customer.id, data, created), GameLoop.OK, "converted")
	assert_eq(created[0].trait_id, "owl", "the Synth has the trait the card showed")


func test_trait_survives_saving() -> void:
	var customer := Customer.new()
	customer.id = "c"
	customer.trait_id = "owl"
	assert_eq(Customer.from_dict(customer.to_dict()).trait_id, "owl", "saved and loaded")


func test_every_species_and_trait_is_explained() -> void:
	var data := GameData.load_default()
	for species_id: String in data.species:
		var key := "species.%s.desc" % species_id
		assert_true(tr(key) != key, "%s has an explanation" % key)
	for trait_id: String in data.traits:
		var key := "trait.%s.desc" % trait_id
		assert_true(tr(key) != key, "%s has an explanation" % key)
	for stage: int in Customer.Stage.values():
		var key := "customer.stage_%d" % stage
		assert_true(tr(key) != key, "%s has text" % key)


func test_rename_synth() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var synth := state.synths[0]
	assert_eq(GameLoop.rename_synth(state, synth.id, "  Barista Bot  "), GameLoop.OK, "renamed")
	assert_eq(synth.name, "Barista Bot", "spaces trimmed")
	assert_eq(GameLoop.rename_synth(state, synth.id, "   "), GameLoop.EMPTY_NAME, "empty refused")
	assert_eq(GameLoop.rename_synth(state, synth.id, "x".repeat(21)), GameLoop.NAME_TOO_LONG, "too long refused")
	assert_eq(GameLoop.rename_synth(state, "nobody", "A"), GameLoop.UNKNOWN_SYNTH, "unknown")
	assert_eq(synth.name, "Barista Bot", "unchanged by refusals")
	assert_eq(Synth.from_dict(synth.to_dict()).name, "Barista Bot", "the name is saved")
