extends SceneTree
## A sheet of every rig animation (a few moments of each) for the office worker
## and the Clerkbot, to check the rig by eye. Needs a window (not --headless):
##   godot --path . --resolution 1600x900 -s res://tools/art/rig_sheet.gd -- <out.png>

const ANIMS: Array[String] = ["idle", "walk", "carry", "sit", "eat", "cook", "rest", "happy", "angry", "attack", "cast",
	"hurt", "down"]
const FACES: Dictionary[String, String] = {"eat": "eat", "rest": "rest", "happy": "happy", "angry": "angry", "attack": "angry",
	"hurt": "angry"}


func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var view := Control.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.draw.connect(func() -> void:
		view.draw_rect(Rect2(Vector2.ZERO, view.size), Color("1b1630"))
		for row: int in 2:
			var species := "" if row == 0 else "clerkbot"
			for i: int in ANIMS.size():
				var feet := Vector2(70 + i * 118, 330 + row * 400)
				var t := 0.3 if ANIMS[i] in ["attack", "hurt", "cast", "down"] else 0.75
				CharacterArt.draw(view, feet, 0.42, "office_worker", species, {"anim": ANIMS[i], "t": t,
					"face": FACES.get(ANIMS[i], "neutral"), "glow": Color("4fb3ff")})
				view.draw_string(ThemeDB.fallback_font, feet + Vector2(-40, 40), ANIMS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18))
	root.add_child(view)
	for frame: int in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	print("rig sheet -> ", out)
	quit()
