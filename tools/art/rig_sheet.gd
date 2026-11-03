extends SceneTree
## Sheets for checking the rig by eye. Needs a window (not --headless).
##   godot --path . --resolution 1600x900 -s res://tools/art/rig_sheet.gd -- <out.png>
##     every animation, for the office worker and the Clerkbot;
##   godot --path . --resolution 1700x1300 -s res://tools/art/rig_sheet.gd -- <out.png> cast
##     every customer type (idle, walk, eat, happy, angry) beside its Synth (idle, carry, cook, attack, hurt);
##   godot --path . --resolution 1300x900 -s res://tools/art/rig_sheet.gd -- <out.png> staff
##     MegaBean's staff, one look per combat class, in their battle animations;
##   godot --path . --resolution 1700x1300 -s res://tools/art/rig_sheet.gd -- <out.png> back
##     every customer type, its Synth and MegaBean's staff walking away (the back view).

const ANIMS: Array[String] = ["idle", "walk", "carry", "sit", "eat", "cook", "rest", "happy", "angry", "attack", "cast",
	"hurt", "down"]
const FACES: Dictionary[String, String] = {"eat": "eat", "rest": "rest", "happy": "happy", "angry": "angry", "attack": "angry",
	"hurt": "angry"}
const CAST: Array[Array] = [["office_worker", "clerkbot", "4fb3ff"], ["gym_fan", "bulkform", "ff8a3d"],
	["gamer", "glitchling", "c46bff"], ["influencer", "hypeform", "ff4fd8"], ["grandparent", "steady_unit", "9cff6b"],
	["alien_tourist", "xeno", "3dffd0"]]
const CUSTOMER_ANIMS: Array[String] = ["idle", "walk", "eat", "happy", "angry"]
const SYNTH_ANIMS: Array[String] = ["idle", "carry", "cook", "attack", "hurt"]
const STAFF: Array[String] = ["fighter", "tank", "ranged", "fragile"]
const STAFF_ANIMS: Array[String] = ["idle", "walk", "attack", "cast", "hurt", "down"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var cast := args.has("cast")
	var staff := args.has("staff")
	var back := args.has("back")
	var view := Control.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.draw.connect(func() -> void:
		view.draw_rect(Rect2(Vector2.ZERO, view.size), Color("1b1630"))
		if back:
			var bodies: Array[Array] = []
			for entry: Array in CAST:
				bodies.append([entry[0], "", Color.WHITE])
				bodies.append([entry[0], entry[1], Color(entry[2])])
			for class_id: String in STAFF:
				bodies.append(["megabean/" + class_id, "", Color.WHITE])
			for i: int in bodies.size():
				var feet := Vector2(90 + (i % 8) * 200, 220 + (i / 8) * 300)
				for k: int in 2:
					CharacterArt.draw(view, feet + Vector2(k * 80, 0), 0.32, bodies[i][0], bodies[i][1],
						{"anim": "walk", "t": 0.1 + k * 0.15, "back": true, "mirror": k == 1, "glow": bodies[i][2]})
			return
		if staff:
			for row: int in STAFF.size():
				for i: int in STAFF_ANIMS.size():
					_pose(view, Vector2(110 + i * 200, 200 + row * 210), 0.4, "megabean/" + STAFF[row], "", STAFF_ANIMS[i], Color.WHITE)
			return
		if cast:
			for row: int in CAST.size():
				var anims: Array[String] = CUSTOMER_ANIMS + SYNTH_ANIMS
				for i: int in anims.size():
					var species: String = "" if i < CUSTOMER_ANIMS.size() else CAST[row][1]
					var feet := Vector2(80 + i * 160 + (40 if species != "" else 0), 190 + row * 210)
					_pose(view, feet, 0.4, CAST[row][0], species, anims[i], Color(CAST[row][2]))
			return
		for row: int in 2:
			for i: int in ANIMS.size():
				_pose(view, Vector2(70 + i * 118, 330 + row * 400), 0.42, "office_worker", "" if row == 0 else "clerkbot",
					ANIMS[i], Color("4fb3ff"))
				view.draw_string(ThemeDB.fallback_font, Vector2(30 + i * 118, 370 + row * 400), ANIMS[i],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 18))
	root.add_child(view)
	for frame: int in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(args[0])
	print("rig sheet -> ", args[0])
	quit()


func _pose(view: Control, feet: Vector2, size: float, type_id: String, species: String, anim: String, glow: Color) -> void:
	var t := 0.3 if anim in ["attack", "hurt", "cast", "down"] else 0.75
	CharacterArt.draw(view, feet, size, type_id, species, {"anim": anim, "t": t, "face": FACES.get(anim, "neutral"), "glow": glow})
