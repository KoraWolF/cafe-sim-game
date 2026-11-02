extends SceneTree
## Debug probe on a save: walking routes from each seat and register to the
## street, then one shift and night with every Synth's battery.
## Usage: godot --headless --path . -s res://tools/route_probe.gd -- <save.json>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var data = GameData.load_default()
	var state = SaveSystem.load_file(args[0], data, PackedStringArray())
	var paths := FloorPaths.new()
	paths.update(state, data)
	var street := Vector2(state.floor_width + 5.0, state.floor_rows - 0.5)
	for placed in state.placed:
		var kind: String = data.pieces[placed.piece_id].kind
		if kind == Piece.SEAT or kind == Piece.REGISTER:
			var from := Vector2(placed.cell) + Vector2(0.5, 1.35 if kind == Piece.REGISTER else 0.5)
			var route := paths.route(from, street)
			print("%s %s: length %.2f" % [kind, placed.cell, FloorPaths.length(route)])
	print("power ", state.power, " shift ", state.shift_time)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	for synth in state.synths:
		print("closing %s %s day_role=%s battery %.1f / %.1f" % [synth.id, synth.role, synth.day_role, synth.battery,
			SynthStats.stat(synth, "battery_max", data)])
	print("defenders ", state.defenders, " power ", state.power)
	var report = GameLoop.end_night(state, data)
	print("defence ", report.defense != null, " undercharged ", report.undercharged, " power used ", report.power_used)
	for synth in state.synths:
		print("morning %s %s battery %.1f / %.1f" % [synth.id, synth.role, synth.battery, SynthStats.stat(synth, "battery_max", data)])
	quit()
