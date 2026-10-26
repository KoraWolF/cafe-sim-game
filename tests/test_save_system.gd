extends TestCase
## Saving and loading: exact round trips, the .bak fallback and refusing bad saves.

const PATH: String = "user://test_saves/save.json"


func _clean() -> void:
	SaveSystem.delete_save(PATH)


## A game mid-shift with customers in every stage, a chef and a dish in hand.
func _busy_state(data: GameData) -> GameState:
	var state := GameState.new_game(3, data)
	state.add_synth("chef", "owl", data)
	state.counter["tea"] = 1
	GameLoop.start_cooking(state, 0, "tea", data)
	GameLoop.advance(state, 5, data)
	assert_true(state.synths[0].is_delivering(), "setup: dish in hand")
	return state


func test_round_trip_continues_the_same_way() -> void:
	_clean()
	var data := TestFixtures.data({"arrival_min_seconds": 2, "arrival_max_seconds": 6})
	var state := _busy_state(data)
	assert_eq(SaveSystem.save(state, PATH), OK, "saved")
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(PATH, data, errors)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded == null:
		return
	assert_eq(SaveSystem.to_dict(loaded), SaveSystem.to_dict(state), "same data")
	GameLoop.advance(state, 60, data)
	GameLoop.advance(loaded, 60, data)
	assert_eq(SaveSystem.to_dict(loaded), SaveSystem.to_dict(state), "same game a minute later (rng too)")
	_clean()


func test_round_trip_at_night_with_raid_plan() -> void:
	_clean()
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var raider := state.add_synth("worker", "klepto", data)
	GameLoop.advance(state, 100, data)
	raider.battery = 40.0
	state.add_suspicion(30.0)
	state.raid_cooldowns["fort"] = 4
	assert_eq(GameLoop.plan_raid(state, "weak", [raider.id] as Array[String], data), GameLoop.OK, "setup: raid")
	SaveSystem.save(state, PATH)
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(PATH, data, errors)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded == null:
		return
	assert_eq(loaded.phase, GameState.Phase.NIGHT, "night")
	assert_eq(loaded.raid_squad, [raider.id] as Array[String], "squad")
	assert_eq(loaded.current_suspicion(), 30.0, "suspicion")
	assert_eq(loaded.raid_cooldowns["fort"], 4, "cooldown")
	_clean()


func test_second_save_keeps_the_first_as_backup() -> void:
	_clean()
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	SaveSystem.save(state, PATH)
	state.coins = 777
	SaveSystem.save(state, PATH)
	assert_true(FileAccess.file_exists(PATH + ".bak"), "backup written")
	assert_true(not FileAccess.file_exists(PATH + ".tmp"), "no temp file left")
	var errors: PackedStringArray = []
	assert_eq(SaveSystem.load_file(PATH, data, errors).coins, 777, "newest save loads")
	_clean()


func test_broken_save_falls_back_to_backup() -> void:
	_clean()
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.coins = 111
	SaveSystem.save(state, PATH)
	state.coins = 222
	SaveSystem.save(state, PATH)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 1, \"day\": ")
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(PATH, data, errors)
	assert_true(loaded != null, "backup loaded")
	assert_eq(loaded.coins if loaded != null else -1, 111, "the previous save")
	_clean()


func test_invalid_save_is_refused() -> void:
	_clean()
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.synths[0].species_id = "dragon"
	SaveSystem.save(state, PATH)
	var errors: PackedStringArray = []
	assert_true(SaveSystem.load_file(PATH, data, errors) == null, "refused")
	assert_true(", ".join(errors).contains("dragon"), "says why: %s" % ", ".join(errors))
	_clean()


func test_newer_save_version_is_refused() -> void:
	_clean()
	var data := TestFixtures.data()
	var raw := SaveSystem.to_dict(GameState.new_game(1, data))
	raw["version"] = SaveSystem.VERSION + 1
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	assert_true(SaveSystem.load_file(PATH, data, errors) == null, "refused")
	assert_true(", ".join(errors).contains("newer version"), "says why")
	_clean()


func test_missing_save() -> void:
	_clean()
	var errors: PackedStringArray = []
	assert_true(not SaveSystem.has_save(PATH), "nothing there")
	assert_true(SaveSystem.load_file(PATH, TestFixtures.data(), errors) == null, "nothing loads")
	assert_true(not errors.is_empty(), "reported")


func test_slot_range() -> void:
	var data := TestFixtures.data()
	assert_eq(SaveSystem.save_slot(GameState.new_game(1, data), SaveSystem.SLOTS), ERR_PARAMETER_RANGE_ERROR, "slot 3 of 0..2")
