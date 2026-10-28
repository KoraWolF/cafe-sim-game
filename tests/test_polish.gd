extends TestCase
## The guided first day's step logic, placeholder sounds and saved settings.


class FakeLog:
	extends RefCounted
	var served: int = 0
	var conversions: int = 0


func test_tutorial_follows_the_first_day() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var log := FakeLog.new()
	var tutorial := Tutorial.new()
	assert_eq(tutorial.text_key(state), "tutorial.welcome", "welcome first")
	assert_true(tutorial.waits_for_next(), "welcome waits for Next")
	tutorial.next()
	assert_eq(tutorial.text_key(state), "tutorial.cook", "then cook")
	assert_true(not tutorial.update(state, log), "nothing cooked yet")
	GameLoop.start_cooking(state, 0, "tea", data)
	assert_true(tutorial.update(state, log), "cooking reached the goal")
	assert_eq(tutorial.text_key(state), "tutorial.deliver", "then watch a delivery")
	log.served = 1
	tutorial.update(state, log)
	assert_eq(tutorial.text_key(state), "", "the convert tip waits for a star")
	var star := Customer.new()
	star.id = "s"
	star.type_id = "regular"
	star.stage = Customer.Stage.STAR
	star.starred = true
	state.customers.append(star)
	assert_eq(tutorial.text_key(state), "tutorial.convert", "a star: convert tip shows")
	log.conversions = 1
	tutorial.update(state, log)
	assert_eq(tutorial.text_key(state), "tutorial.card", "then the Synth card")
	tutorial.seen[Tutorial.OPENED_CARD] = true
	tutorial.update(state, log)
	assert_eq(tutorial.text_key(state), "", "the night tip waits for the night")
	GameLoop.advance(state, data.balance.shift_seconds, data)
	assert_eq(tutorial.text_key(state), "tutorial.night", "night")
	tutorial.next()
	tutorial.update(state, log)
	assert_eq(tutorial.text_key(state), "tutorial.raid", "then plan a raid")
	tutorial.next()
	assert_eq(tutorial.text_key(state), "tutorial.end_night", "skipping the raid step")
	GameLoop.end_night(state, data)
	tutorial.update(state, log)
	assert_eq(tutorial.text_key(state), "tutorial.done", "the last tip")
	tutorial.next()
	assert_true(tutorial.finished, "finished")


func test_missed_shift_steps_are_passed_at_night() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	var tutorial := Tutorial.new()
	tutorial.next()
	GameLoop.advance(state, data.balance.shift_seconds, data)
	tutorial.update(state, FakeLog.new())
	assert_eq(tutorial.text_key(state), "tutorial.night", "cook/deliver/convert/card passed over at night")


func test_every_tutorial_step_has_text() -> void:
	var tutorial := Tutorial.new()
	for i: int in tutorial.step_count():
		var key: String = tutorial._steps[i]["key"]
		assert_true(tr(key) != key, "%s has text" % key)


func test_placeholder_sounds_render() -> void:
	var director: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AudioDirector")
	assert_true(director != null, "AudioDirector autoload is running")
	if director == null:
		return
	for event: String in director.SOUNDS:
		var stream: AudioStream = director._sound(event)
		assert_true(stream != null and stream.get_length() > 0.0, "%s has a sound" % event)
	for bus: String in Settings.BUSES:
		assert_true(AudioServer.get_bus_index(bus) >= 0, "bus %s exists" % bus)


func test_volume_is_saved() -> void:
	var before := Settings.volume("SFX")
	Settings.set_volume("SFX", 0.25)
	Settings._config = null  # read back from the file
	assert_true(is_equal_approx(Settings.volume("SFX"), 0.25), "saved")
	assert_true(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))), 0.25), "applied")
	Settings.set_volume("SFX", before)
