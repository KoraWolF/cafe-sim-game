extends TestCase
## Items: unique pieces move between the inventory and one Synth; equipment
## adds stats (speed by a share, power and HP by an amount); equipment sells
## by tier; crafting spends Scrap and Chips; EXP bottles give XP; a won raid
## brings Scrap, maybe equipment and an EXP bottle. Fixture catalog: "boots"
## (+50% speed common, +100% rare), fashion "cap" and "coat", bottles "small"
## (+20 XP) and "big" (+350, from day 10).


func _state(data: GameData) -> GameState:
	var state := GameState.new_game(1, data)
	state.inventory.append(Items.make(state, Item.EQUIPMENT, "boots", "common"))
	state.inventory.append(Items.make(state, Item.EQUIPMENT, "boots", "rare"))
	state.inventory.append(Items.make(state, Item.FASHION, "cap"))
	return state


func test_equip_moves_the_piece_and_adds_its_stat() -> void:
	var data := TestFixtures.data()
	var state := _state(data)
	var synth := state.synths[0]
	var common := state.inventory[0]
	var speed := SynthStats.speed(synth, data)
	assert_eq(GameLoop.equip_item(state, synth.id, common.uid, data), GameLoop.OK, "equipped")
	assert_true(not state.inventory.has(common), "left the inventory")
	assert_eq(SynthStats.speed(synth, data), speed * 1.5, "+50% speed")
	assert_eq(GameLoop.equip_item(state, synth.id, common.uid, data), GameLoop.UNKNOWN_ITEM, "can't be worn twice")
	var rare := state.inventory[0]
	assert_eq(GameLoop.equip_item(state, synth.id, rare.uid, data), GameLoop.OK, "swap boots")
	assert_true(state.inventory.has(common), "the old pair went back")
	assert_eq(SynthStats.speed(synth, data), speed * 2.0, "+100% speed")
	assert_eq(GameLoop.unequip_item(state, synth.id, "boots", data), GameLoop.OK, "taken off")
	assert_eq(GameLoop.unequip_item(state, synth.id, "boots", data), GameLoop.NOTHING_WORN, "nothing left there")
	assert_eq(SynthStats.speed(synth, data), speed, "back to normal")


func test_fashion_is_worn_but_changes_no_stat_and_is_not_sold() -> void:
	var data := TestFixtures.data()
	var state := _state(data)
	var synth := state.synths[0]
	var cap := state.inventory[2]
	var power := SynthStats.stat(synth, "power", data)
	assert_eq(GameLoop.sell_item(state, cap.uid, data), GameLoop.NOT_FOR_SALE, "fashion is kept")
	assert_eq(GameLoop.equip_item(state, synth.id, cap.uid, data), GameLoop.OK, "worn")
	assert_eq(SynthStats.stat(synth, "power", data), power, "looks only")
	assert_eq(Items.worn(synth, "hat", data), cap, "on its head")


func test_selling_equipment_pays_its_tier() -> void:
	var data := TestFixtures.data()
	var state := _state(data)
	var coins := state.coins
	assert_eq(GameLoop.sell_item(state, state.inventory[1].uid, data), GameLoop.OK, "sold the rare boots")
	assert_eq(state.coins, coins + 100, "rare sells for 100")
	assert_eq(GameLoop.sell_item(state, "nope", data), GameLoop.UNKNOWN_ITEM, "unknown")


func test_crafting_spends_materials() -> void:
	var data := TestFixtures.data()
	var state := _state(data)
	state.scrap = 4
	assert_eq(GameLoop.craft_item(state, "basic", data), GameLoop.NOT_ENOUGH_MATERIALS, "needs 5 Scrap")
	state.scrap = 17
	var made: Array[Item] = []
	assert_eq(GameLoop.craft_item(state, "basic", data, made), GameLoop.OK, "crafted")
	assert_eq(made[0].tier, "common", "a basic piece")
	assert_eq(state.scrap, 12, "5 Scrap spent")
	assert_eq(GameLoop.craft_item(state, "advanced", data), GameLoop.NOT_ENOUGH_MATERIALS, "needs a Chip too")
	state.chips = 1
	made.clear()
	assert_eq(GameLoop.craft_item(state, "advanced", data, made), GameLoop.OK, "crafted")
	assert_eq(made[0].tier, "rare", "an advanced piece")
	assert_true(state.inventory.has(made[0]), "in the inventory")
	assert_eq(GameLoop.craft_item(state, "magic", data), GameLoop.UNKNOWN_CRAFT, "unknown recipe")


func test_exp_bottles() -> void:
	var data := TestFixtures.data()
	var state := _state(data)
	var synth := state.synths[0]
	assert_eq(GameLoop.use_bottle(state, synth.id, "small", data), GameLoop.NONE_LEFT, "none yet")
	state.bottles["small"] = 1
	assert_eq(GameLoop.use_bottle(state, synth.id, "small", data), GameLoop.OK, "used")
	assert_eq(synth.xp, 20, "+20 XP")
	assert_true(not state.bottles.has("small"), "used up")
	state.bottles["small"] = 1
	synth.level = data.balance.max_synth_level
	assert_eq(GameLoop.use_bottle(state, synth.id, "small", data), GameLoop.MAXED, "max level")


func test_won_raid_brings_loot() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.add_synth("worker", "", data)
	state.phase = GameState.Phase.NIGHT
	GameLoop.plan_raid(state, "weak", [state.synths[1].id] as Array[String], data)
	var report := GameLoop.end_night(state, data)
	assert_true(report.raid.attackers_won, "setup: won")
	assert_eq(report.loot_scrap, 2, "Scrap")
	assert_eq(state.scrap, 2, "kept")
	assert_eq(report.loot_items.size(), 1, "a piece of equipment")
	assert_eq(report.loot_bottle, "small", "a bottle (the big one only from day 10)")
	assert_eq(state.bottles.get("small", 0), 1, "kept")


func test_bottles_get_rarer() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	assert_eq(Items.bottle_chance(state, data), 1.0, "day 1: always")
	state.day = 6
	assert_eq(Items.bottle_chance(state, data), 0.5, "-10% a day")
	state.day = 30
	assert_eq(Items.bottle_chance(state, data), 0.0, "never below the minimum")


func test_items_survive_save_and_audit_loss_leaves_them() -> void:
	var data := TestFixtures.data()
	var state := _state(data)
	var synth := state.synths[0]
	GameLoop.equip_item(state, synth.id, state.inventory[0].uid, data)
	state.scrap = 3
	state.bottles["small"] = 2
	var loaded := SaveSystem.from_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_dict(state))))
	assert_eq(loaded.inventory.size(), 2, "inventory saved")
	assert_eq(loaded.synths[0].items.size(), 1, "worn piece saved")
	assert_eq(loaded.scrap, 3, "Scrap saved")
	assert_eq(loaded.bottles["small"], 2, "bottles saved")
	assert_true(SaveSystem.validate(loaded, data).is_empty(), "valid")
	Items.return_all(state, synth)
	assert_eq(state.inventory.size(), 3, "a Synth leaving leaves its pieces")


func test_new_game_gets_starter_fashion() -> void:
	var data := GameData.load_default()
	var state := GameState.new_game(1, data)
	var kinds := state.inventory.map(func(item: Item) -> String: return item.type_id)
	assert_eq(kinds, ["neon_cap", "teal_jacket"], "a hat and an outfit to try")
	assert_true(data.items.tiers.size() == 5 and data.items.tier_order[4] == "legendary", "5 tiers")


func test_version_11_game_gets_starter_fashion() -> void:
	var data := GameData.load_default()
	var path := "user://test_saves/no_items.json"
	var state := GameState.new_game(1, data)
	state.inventory.clear()
	var raw := SaveSystem.to_dict(state)
	for key: String in ["inventory", "bottles", "scrap", "chips"]:
		raw.erase(key)
	raw["version"] = 11
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var errors: PackedStringArray = []
	var loaded := SaveSystem.load_file(path, data, errors)
	SaveSystem.delete_save(path)
	assert_true(loaded != null, "loaded: %s" % ", ".join(errors))
	if loaded != null:
		assert_eq(loaded.inventory.size(), 2, "the starter hat and outfit")
