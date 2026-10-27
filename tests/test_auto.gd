extends TestCase
## The Auto button: unlocks on auto_unlock_day, is saved, and stops for a
## coming Corporate Audit. (The night itself is passed by Session.auto_night.)


func test_auto_unlocks_after_two_days() -> void:
	var data := GameData.load_default()
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.set_auto(state, true, data), GameLoop.AUTO_LOCKED, "locked on day 1")
	state.day = 2
	assert_eq(GameLoop.set_auto(state, true, data), GameLoop.AUTO_LOCKED, "locked on day 2")
	state.day = 3
	assert_eq(GameLoop.set_auto(state, true, data), GameLoop.OK, "unlocked on day 3")
	assert_true(state.auto_night, "on")
	assert_eq(GameLoop.set_auto(state, false, data), GameLoop.OK, "can turn off")
	assert_true(not state.auto_night, "off")


func test_auto_is_saved() -> void:
	var data := GameData.load_default()
	var state := GameState.new_game(1, data)
	state.day = 3
	GameLoop.set_auto(state, true, data)
	var loaded := SaveSystem.from_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_dict(state))))
	assert_true(loaded.auto_night, "still on after loading")


func test_auto_stops_for_an_audit() -> void:
	var data := GameData.load_default()
	var state := GameState.new_game(1, data)
	assert_eq(GameLoop.auto_stop_reason(state, data), "", "a normal night passes")
	state.suspicion[state.district_id] = data.balance.audit_suspicion
	assert_eq(GameLoop.auto_stop_reason(state, data), "audit", "the player plans an Audit night")
