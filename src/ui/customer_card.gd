class_name CustomerCard
extends PanelContainer
## Shown while the mouse is over a customer: who they are, what they want, how
## happy they are, and what they would become as a Synth (species and the trait
## they arrived with), so the player can choose who to convert.

var customer_id: String = ""
var _title := UiTheme.label("", 20, UiTheme.PANEL_BORDER)
var _body := UiTheme.label("", 15)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(330, 0)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(_title)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(300, 0)
	column.add_child(_body)


## Shows the card for a customer near a screen position ("" hides it).
func show_for(id: String, at: Vector2) -> void:
	customer_id = id
	refresh()
	if not visible:
		return
	reset_size()
	var area := get_parent_area_size()
	position = Vector2(clampf(at.x + 24, 8, area.x - size.x - 8), clampf(at.y - size.y - 16, 60, area.y - size.y - 8))


func refresh() -> void:
	var session := get_node_or_null("/root/Session")
	var customer: Customer = session.state.customer_by_id(customer_id) if session != null and session.has_game() else null
	visible = customer != null
	if customer == null:
		return
	var data: GameData = session.data
	var type := data.customer_types[customer.type_id]
	_title.text = UiText.name(customer.type_id)
	var lines: Array[String] = []
	lines.append(tr("customer.stage_%d" % customer.stage))
	if customer.recipe_id != "":
		var favourite := tr("customer.favourite") if type.favorites.has(customer.recipe_id) else ""
		lines.append(tr("customer.order") % [UiText.name(customer.recipe_id), favourite])
	lines.append(tr("customer.mood") % roundi(customer.satisfaction))
	if customer.is_seated():
		lines.append(tr("customer.seat_vibe") % roundi(session.state.seat_vibe.get(customer.seat_uid, 0.0)))
	lines.append(tr("customer.converts") % [UiText.name(type.synth_species),
		UiText.name(customer.trait_id) if customer.trait_id != "" else tr("ui.card_no_trait")])
	lines.append(tr("species.%s.desc" % type.synth_species))
	if customer.trait_id != "":
		lines.append(tr("trait.%s.desc" % customer.trait_id))
	if customer.stage == Customer.Stage.STAR:
		lines.append(tr("customer.click_convert"))
	_body.text = "\n".join(lines)
