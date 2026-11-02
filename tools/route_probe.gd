extends SceneTree
## Debug probe on a save: a MegaBean raid fought in front of the café with
## every Synth defending; prints where each defender went.
## Usage: godot --headless --path . -s res://tools/route_probe.gd -- <save.json>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var data = GameData.load_default()
	var state = SaveSystem.load_file(args[0], data, PackedStringArray())
	var home: Array[Battle.Fighter] = []
	for synth in state.synths:
		home.append(NightOps.synth_fighter(synth, state.security, data))
	var raiders: Array[Battle.Fighter] = []
	for class_id in ["fighter", "ranged", "tank", "fragile"]:
		raiders.append(Battle.Fighter.make("", 8.0, 40.0, class_id))
	var field := RaidField.for_home(state, data)
	var report := Battle.run(raiders, home, RandomNumberGenerator.new(), data, field)
	print("door ", field.door, " split ", field.split, " engaged ", report.engaged_at, " duration ", report.duration,
		" attackers won ", report.attackers_won)
	for i in home.size():
		var cells: Array = [home[i].cell]
		var attacks := 0
		for event in report.events:
			if not event.side and event.index == i:
				if event.kind == Battle.Event.MOVE:
					cells.append(event.to)
				elif event.kind == Battle.Event.ATTACK:
					attacks += 1
		print("%s %s: %s attacks %d hp %.0f" % [home[i].synth_id, home[i].class_id, cells, attacks, home[i].hp])
	quit()
