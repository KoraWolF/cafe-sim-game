extends TestCase
## Loading content from /data and from test fixtures.


func test_real_data_loads() -> void:
	var data := GameData.load_default()
	assert_true(data != null, "data/*.json loads")
	if data == null:
		return
	assert_eq(data.customer_types.size(), 6, "customer types")
	assert_eq(data.species.size(), 6, "species")
	assert_eq(data.balance.shift_seconds, 480, "shift length")
	assert_eq(typeof(data.balance.shift_seconds), TYPE_INT, "JSON numbers keep int fields int")


func test_every_customer_type_has_its_species() -> void:
	var data := GameData.load_default()
	for type: CustomerType in data.customer_types.values():
		assert_true(data.species.has(type.synth_species), "%s converts to a known species" % type.id)


func test_fixture_loads() -> void:
	var data := TestFixtures.data()
	assert_true(data != null, "fixture content is valid")
	assert_eq(data.species["steady"].stats["drain"], 1.0, "given stat")
	assert_eq(data.species["steady"].stats["recharge_multiplier"], 1.0, "default stat")


func test_broken_reference_is_rejected() -> void:
	var content := TestFixtures.content()
	content["customer_types"][0]["synth_species"] = "nobody"
	expected_errors = 1
	assert_true(GameData.from_content(content) == null, "unknown species rejected")


func test_unknown_balance_key_is_reported() -> void:
	expected_errors = 1
	var data := TestFixtures.data({"not_a_key": 1})
	assert_true(data != null, "still loads")
