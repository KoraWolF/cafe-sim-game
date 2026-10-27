class_name UiTheme
extends RefCounted
## Placeholder look: a dark neon-city palette and one Theme for every screen.
## Real art and fonts replace these later without touching screen code.

## Height of the HUD's top bar (two rows); panels and the camera start below it.
const TOP_BAR_HEIGHT: float = 100.0
const BACKGROUND := Color("141225")
const PANEL := Color("1e1b36ee")
const PANEL_BORDER := Color("38e1ff")
const TEXT := Color("f2efff")
const TEXT_DIM := Color("a8a3c7")
const ACCENT := Color("ff4fd8")
const GOOD := Color("5dff9a")
const WARN := Color("ffcf4a")
const BAD := Color("ff5d6c")
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
	var panel := _box(PANEL, PANEL_BORDER, 2, 10)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PopupMenu", panel)
	theme.set_stylebox("panel", "TabContainer", _box(PANEL, PANEL_BORDER, 2, 6))
	theme.set_stylebox("normal", "Button", _box(Color("2b2650"), Color("5b54a0"), 1, 6))
	theme.set_stylebox("hover", "Button", _box(Color("3a3370"), PANEL_BORDER, 1, 6))
	theme.set_stylebox("pressed", "Button", _box(Color("4a2a6a"), ACCENT, 1, 6))
	theme.set_stylebox("disabled", "Button", _box(Color("221f3a"), Color("3a3560"), 1, 6))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT, 2, 6))
	for type: String in ["Label", "Button", "CheckBox", "OptionButton", "TabContainer", "PopupMenu"]:
		theme.set_color("font_color", type, TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_selected_color", "TabContainer", PANEL_BORDER)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	theme.set_stylebox("background", "ProgressBar", _box(Color(0, 0, 0, 0.5), Color("3a3560"), 1, 4, 0))
	theme.set_stylebox("fill", "ProgressBar", _box(PANEL_BORDER, PANEL_BORDER, 0, 4, 0))
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 10)
	return theme


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
static func label(text: String, size := 18, color := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


static func button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(Sfx.play.bind("ui_click"))
	button.pressed.connect(on_press)
	return button
