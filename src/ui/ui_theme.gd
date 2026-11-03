class_name UiTheme
extends RefCounted
## The neon dive-bar look (see docs/art-guide.md) and one Theme for every
## screen: near-black glass panels with a glowing cyan edge and two cut corners,
## slanted buttons edged in magenta that glow cyan on hover, tabs with a neon
## underline, slim neon scroll bars. Screens only use these colours and the Theme.

## Height of the HUD's top bar (two rows); panels and the camera start below it.
const TOP_BAR_HEIGHT: float = 100.0
const BACKGROUND := Color("0c0a14")
const PANEL := Color("120f1ef2")
const PANEL_BORDER := Color("19f0ff")
const TEXT := Color("eaf8ff")
const TEXT_DIM := Color("8f8ab3")
const ACCENT := Color("ff2fb4")
const GOOD := Color("5dff9a")
const WARN := Color("ffb03b")
const BAD := Color("ff4560")
## Button fills.
const BUTTON := Color("1a1428")
const BUTTON_HOVER := Color("241a3a")
## How far buttons lean (a cyberpunk slant).
const BUTTON_SLANT: float = 0.12
const FLOOR_A := Color("3a2f4f")
const FLOOR_B := Color("44385c")
const WALL := Color("231d36")

## Placeholder colours: customer types (clothes) and Synth species (signature glow).
const CUSTOMER_COLORS: Dictionary[String, Color] = {
	"office_worker": Color("6f8fd8"), "gym_fan": Color("e8734a"), "gamer": Color("9a5ce6"),
	"influencer": Color("ff6fb5"), "grandparent": Color("c9b48a"), "alien_tourist": Color("6fe8b0"),
}
const SPECIES_GLOW: Dictionary[String, Color] = {
	"clerkbot": Color("4fb3ff"), "bulkform": Color("ff8a3d"), "glitchling": Color("c46bff"),
	"hypeform": Color("ff4fd8"), "steady_unit": Color("9cff6b"), "xeno": Color("3dffd0"),
}
## Décor colour by its first tag.
const TAG_COLORS: Dictionary[String, Color] = {
	"plant": Color("4ec46a"), "light": Color("ffd84a"), "tech": Color("38e1ff"), "cozy": Color("ff9a5c"),
}

static var _shared: Theme = null


## The game's Theme. Set it on every top-level Control: a theme on the Window
## does not reach Controls whose parent is a plain Node or a CanvasLayer.
static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	var panel := panel_box(PANEL_BORDER)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_stylebox("panel", "TooltipPanel", panel_box(ACCENT, 6))
	theme.set_stylebox("panel", "TabContainer", panel_box(PANEL_BORDER, 6))
	theme.set_stylebox("hover", "PopupMenu", _box(Color(ACCENT, 0.3), ACCENT, 0, 2, 4))
	# Buttons: slanted, edged in magenta; cyan glow on hover, magenta when pressed.
	theme.set_stylebox("normal", "Button", button_box(BUTTON, Color(ACCENT, 0.7)))
	theme.set_stylebox("hover", "Button", button_box(BUTTON_HOVER, PANEL_BORDER, PANEL_BORDER))
	theme.set_stylebox("pressed", "Button", button_box(Color(ACCENT, 0.35), ACCENT, ACCENT))
	theme.set_stylebox("hover_pressed", "Button", button_box(Color(ACCENT, 0.45), ACCENT, ACCENT))
	theme.set_stylebox("disabled", "Button", button_box(Color("14111c"), Color("2a2640")))
	var focus := button_box(Color(0, 0, 0, 0), ACCENT)
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	for type: String in ["Label", "Button", "CheckBox", "OptionButton", "TabContainer", "PopupMenu", "LineEdit"]:
		theme.set_color("font_color", type, TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	# Tabs: a neon underline on the chosen one.
	theme.set_color("font_selected_color", "TabContainer", PANEL_BORDER)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	theme.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	var tab := _box(Color(PANEL_BORDER, 0.12), PANEL_BORDER, 0, 2, 6)
	tab.border_width_bottom = 3
	theme.set_stylebox("tab_selected", "TabContainer", tab)
	theme.set_stylebox("tab_unselected", "TabContainer", _box(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 0, 2, 6))
	var tab_hover := _box(Color(ACCENT, 0.15), ACCENT, 0, 2, 6)
	tab_hover.border_width_bottom = 2
	theme.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	# Text fields: dark glass with a cyan underline.
	var field := _box(Color("0a0812"), Color(PANEL_BORDER, 0.6), 0, 2, 6)
	field.border_width_bottom = 2
	theme.set_stylebox("normal", "LineEdit", field)
	var field_focus := _box(Color("0a0812"), PANEL_BORDER, 0, 2, 6)
	field_focus.border_width_bottom = 2
	field_focus.shadow_color = Color(PANEL_BORDER, 0.3)
	field_focus.shadow_size = 6
	theme.set_stylebox("focus", "LineEdit", field_focus)
	# Scroll bars: a slim neon grabber.
	for bar: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, _box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 3, 0))
		theme.set_stylebox("grabber", bar, _box(Color(PANEL_BORDER, 0.55), Color(0, 0, 0, 0), 0, 3, 0))
		theme.set_stylebox("grabber_highlight", bar, _box(PANEL_BORDER, Color(0, 0, 0, 0), 0, 3, 0))
		theme.set_stylebox("grabber_pressed", bar, _box(ACCENT, Color(0, 0, 0, 0), 0, 3, 0))
	# Progress: a glowing cyan fill.
	theme.set_stylebox("background", "ProgressBar", _box(Color(0, 0, 0, 0.55), Color(PANEL_BORDER, 0.35), 1, 2, 0))
	var fill := _box(PANEL_BORDER, PANEL_BORDER, 0, 2, 0)
	fill.shadow_color = Color(PANEL_BORDER, 0.4)
	fill.shadow_size = 4
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_stylebox("separator", "HSeparator", _line(Color(ACCENT, 0.6)))
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 10)
	return theme


## A panel: near-black glass, a glowing edge in `edge`, and two cut corners
## (sharp top-left and bottom-right, rounded at the others).
static func panel_box(edge: Color, margin := 8) -> StyleBoxFlat:
	var box := _box(PANEL, edge, 2, 0, margin)
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_left = 16
	box.shadow_color = Color(edge, 0.22)
	box.shadow_size = 10
	return box


## A slanted button: a fill, an edge, and a glow in `glow` (none if transparent).
static func button_box(fill: Color, edge: Color, glow := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := _box(fill, edge, 2, 0, 8)
	box.corner_radius_top_left = 2
	box.corner_radius_bottom_right = 2
	box.skew = Vector2(BUTTON_SLANT, 0)
	if glow.a > 0.0:
		box.shadow_color = Color(glow, 0.35)
		box.shadow_size = 7
	return box


## A thin glowing line (for separators).
static func _line(color: Color) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = color
	line.thickness = 2
	return line


static func _box(fill: Color, border: Color, width: int, radius: int, margin := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin * 1.5
	box.content_margin_right = margin * 1.5
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box


## A label with a font size and colour (UI code uses it everywhere).
## Makes the mouse wheel scroll a sideways ScrollContainer left and right.
static func wheel_scrolls_sideways(scroll: ScrollContainer, step := 120.0) -> void:
	scroll.gui_input.connect(func(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button == null or not button.pressed:
			return
		if button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
			scroll.scroll_horizontal -= int(step)
		elif button.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			scroll.scroll_horizontal += int(step)
		else:
			return
		scroll.accept_event())


static func label(text: String, size := 18, color := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if size >= 26:
		# Big titles get a neon halo in their own colour.
		label.add_theme_constant_override("outline_size", maxi(size / 5, 4))
		label.add_theme_color_override("font_outline_color", Color(color, 0.3))
	return label


static func button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(Sfx.play.bind("ui_click"))
	button.pressed.connect(on_press)
	return button
