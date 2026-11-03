class_name MenuBackdrop
extends Control
## The main menu's backdrop: a rainy neon skyline at night. Dark towers with lit
## windows against a magenta-to-indigo sky, a few blinking neon signs, a glowing
## street line and falling rain. Drawn in code; the layout is the same every
## start (seeded), only the rain and the blinking move.

const TOWERS: int = 26
const RAIN: int = 140
const SIGN_COLORS: Array[Color] = [Color("ff2fb4"), Color("19f0ff"), Color("b6ff3b"), Color("ffb03b")]

var _towers: Array[Rect2] = []
var _windows: Array[Array] = []  # [position, colour] per lit window
var _signs: Array[Array] = []  # [rect, colour, blink phase]
var _drops: Array[Vector3] = []  # x, y, speed
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2045
	var area := size if size.x > 0.0 else Vector2(1920, 1080)
	var ground := area.y * 0.86
	_towers.clear()
	_windows.clear()
	_signs.clear()
	var x := -40.0
	while x < area.x + 40.0:
		var width := rng.randf_range(70.0, 170.0)
		var height := rng.randf_range(area.y * 0.18, area.y * 0.62)
		var tower := Rect2(x, ground - height, width, height)
		_towers.append(tower)
		for wy in range(int(tower.position.y + 18), int(ground - 14), 22):
			for wx in range(int(x + 10), int(x + width - 12), 18):
				if rng.randf() < 0.32:
					_windows.append([Vector2(wx, wy), SIGN_COLORS[rng.randi_range(0, 3)] if rng.randf() < 0.18 else Color("ffd9a0")])
		if rng.randf() < 0.45:
			var sign_rect := Rect2(x + rng.randf_range(6.0, width * 0.5), tower.position.y + rng.randf_range(30.0, height * 0.5),
				rng.randf_range(14.0, 26.0), rng.randf_range(50.0, 110.0))
			_signs.append([sign_rect, SIGN_COLORS[rng.randi_range(0, 3)], rng.randf_range(0.0, TAU)])
		x += width + rng.randf_range(-10.0, 18.0)
	_drops.clear()
	for i: int in RAIN:
		_drops.append(Vector3(rng.randf_range(0.0, area.x), rng.randf_range(0.0, area.y), rng.randf_range(600.0, 1100.0)))
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	for i: int in _drops.size():
		var drop := _drops[i]
		drop.y += drop.z * delta
		drop.x -= drop.z * 0.15 * delta
		if drop.y > size.y:
			drop.y -= size.y + 40.0
			drop.x = fmod(drop.x + size.x * 0.37, size.x)
		_drops[i] = drop
	queue_redraw()


func _draw() -> void:
	var area := size
	var ground := area.y * 0.86
	# Sky: indigo above, a magenta haze on the horizon.
	var sky := PackedVector2Array([Vector2.ZERO, Vector2(area.x, 0), Vector2(area.x, ground), Vector2(0, ground)])
	draw_polygon(sky, PackedColorArray([Color("0c0a14"), Color("0c0a14"), Color("3a1240"), Color("3a1240")]))
	for tower: Rect2 in _towers:
		draw_rect(tower, Color("100c1c"))
		draw_line(tower.position, tower.position + Vector2(tower.size.x, 0), Color("19f0ff", 0.25), 2.0)
	for window: Array in _windows:
		draw_rect(Rect2(window[0], Vector2(7, 9)), Color(window[1], 0.75))
	for sign_entry: Array in _signs:
		var rect: Rect2 = sign_entry[0]
		var lit := 0.55 + 0.45 * maxf(sin(_time * 1.7 + sign_entry[2]), -0.3)
		draw_rect(rect.grow(6.0), Color(sign_entry[1], 0.12 * lit))
		draw_rect(rect, Color(sign_entry[1], 0.85 * lit), false, 3.0)
	# The street: wet, with a neon line and reflections.
	draw_rect(Rect2(0, ground, area.x, area.y - ground), Color("08060e"))
	draw_line(Vector2(0, ground), Vector2(area.x, ground), Color("ff2fb4", 0.8), 3.0)
	draw_rect(Rect2(0, ground + 3, area.x, 18), Color("ff2fb4", 0.08))
	for sign_entry: Array in _signs:
		var rect: Rect2 = sign_entry[0]
		draw_rect(Rect2(rect.position.x, ground + 8, rect.size.x, 40), Color(sign_entry[1], 0.07))
	for drop: Vector3 in _drops:
		draw_line(Vector2(drop.x, drop.y), Vector2(drop.x - 3.0, drop.y + 16.0), Color("9fd8ff", 0.35), 1.5)
	# Darken the middle a little, so the menu reads over it.
	draw_rect(Rect2(area.x * 0.5 - 330, 0, 660, area.y), Color(0, 0, 0, 0.35))
