extends SceneTree
## A contact sheet of every furniture and décor SVG, on the café's dark
## background: each at half its 4x canvas (2x game size), with the game-size
## (1x) version under it. Usage:
##   godot --headless --path . -s res://tools/art/preview_sheet.gd -- <out.png>

const FOLDERS: Array[String] = ["res://art/furniture", "res://art/decor"]
const CELL := Vector2i(460, 520)
const COLUMNS: int = 6


func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var files: Array[String] = []
	for folder: String in FOLDERS:
		for file: String in DirAccess.get_files_at(folder):
			if file.ends_with(".svg"):
				files.append(folder.path_join(file))
	var rows := ceili(files.size() / float(COLUMNS))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1b1630"))
	for i: int in files.size():
		var text := FileAccess.get_file_as_string(files[i])
		var at := Vector2i(i % COLUMNS * CELL.x, i / COLUMNS * CELL.y)
		for scale: float in [0.5, 0.25]:
			var image := Image.new()
			image.load_svg_from_string(text, scale)
			image.convert(Image.FORMAT_RGBA8)
			var spot := at + (Vector2i(10, 10) if scale == 0.5 else Vector2i(10, CELL.y - image.get_height() - 10))
			sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), spot)
	sheet.save_png(out)
	print("sheet: ", files.size(), " pieces -> ", out)
	quit()
