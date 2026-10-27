extends TestCase
## UI helpers that do not need a window: error texts, isometric math and the
## night report lines.


func test_every_error_code_has_a_message() -> void:
	var codes := (load("res://src/systems/game_loop.gd") as Script).get_script_constant_map()
	for name: String in codes:
		var code: Variant = codes[name]
		if code is String and code != "":
			assert_true(UiText.error(code) != code, "error.%s has a message" % code)


func test_every_role_has_a_name() -> void:
	for role: String in Synth.ROLES:
		assert_true(UiText.role(role) != "role." + role, "role.%s has a name" % role)


func test_pretty_names_and_clock() -> void:
	assert_eq(UiText.pretty("megabean_kiosk"), "Megabean Kiosk", "ids read as names")
	assert_eq(UiText.name("steady_unit"), "Steady Unit", "fallback without a translation")
	assert_eq(UiText.clock(125), "2:05", "m:ss")


func test_iso_round_trip() -> void:
	for cell: Vector2 in [Vector2(0, 0), Vector2(3.5, 1.25), Vector2(7, 13)]:
		var back := Iso.to_cell(Iso.to_world(cell))
		assert_true(back.is_equal_approx(cell), "%s -> %s" % [cell, back])
	assert_eq(Iso.tile_at(Iso.centre(Vector2i(4, 2), Vector2i.ONE)), Vector2i(4, 2), "tile under a tile centre")


func test_report_lines() -> void:
	var data := TestFixtures.data()
	Session.data = data
	Session.state = GameState.new_game(1, data)
	var quiet := NightOps.Report.new()
	var lines := ReportPanel.lines(quiet)
	assert_eq(lines[0][0], tr("ui.report_quiet"), "a quiet night")
	var takeover := NightOps.Report.new()
	takeover.raid = Battle.Report.new()
	takeover.raid.attackers_won = true
	takeover.raid_target = "hq"
	takeover.district_taken = "town"
	takeover.next_district = "city"
	lines = ReportPanel.lines(takeover)
	assert_true(lines[0][0].begins_with("Raid on Hq: WON"), "raid line: %s" % lines[0][0])
	assert_true(lines[1][0].contains("Town is yours"), "takeover line: %s" % lines[1][0])
	Session.data = GameData.load_default()
	Session.state = null


func _seated(state: GameState, id: String) -> Customer:
	var customer := Customer.new()
	customer.id = id
	customer.type_id = "regular"
	customer.stage = Customer.Stage.WAITING_FOOD
	customer.recipe_id = "tea"
	state.customers.append(customer)
	return customer
