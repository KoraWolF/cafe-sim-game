class_name InfoPanel
extends Modal
## The top bar's Info: how the main features work (Help), and what every stat,
## role and trait means.

## The Help tab, in order.
const HELP: Array[String] = ["cooking", "jobs", "converting", "quests", "shop", "arrange", "bag", "resources", "auto",
	"windows"]

var _tabs := TabContainer.new()


func _ready() -> void:
	super._ready()
	panel.custom_minimum_size = Vector2(720, 560)
	var header := HBoxContainer.new()
	var title := UiTheme.label(tr("info.title"), 26, UiTheme.PANEL_BORDER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiTheme.button(tr("ui.close"), hide_modal))
	content.add_child(header)
	_tabs.custom_minimum_size = Vector2(0, 480)
	content.add_child(_tabs)
	var help: Array[String] = []
	for key: String in HELP:
		help.append(tr("help." + key))
	_add_tab("info.tab_help", help)
	var stats: Array[String] = []
	for stat: String in ["speed", "cook", "appeal", "power", "hp", "battery", "level"]:
		stats.append(tr("info.stat." + stat))
	_add_tab("info.tab_stats", stats)
	var roles: Array[String] = []
	for role: String in Synth.ROLES:
		roles.append("%s: %s" % [UiText.role(role), tr("tip.role." + role)])
	_add_tab("info.tab_roles", roles)
	var traits: Array[String] = []
	var session := get_node_or_null("/root/Session")
	if session != null:
		for trait_id: String in session.data.traits:
			traits.append(tr("trait.%s.desc" % trait_id))
	_add_tab("info.tab_traits", traits)


func open() -> void:
	show_modal()


func _add_tab(title_key: String, lines: Array[String]) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tr(title_key)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	for line: String in lines:
		var label := UiTheme.label(line, 17)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(660, 0)
		column.add_child(label)
	_tabs.add_child(scroll)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		hide_modal()
		get_viewport().set_input_as_handled()
