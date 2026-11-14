class_name OrderCard
extends PanelContainer
## Карточка гостя и заказа: портрет, имя, реплика-заказ, условия и полоса терпения.


var _portrait: GuestPortrait
var _name_label: Label
var _mood_label: Label
var _count_label: Label
var _text_label: Label
var _chips: HFlowContainer
var _new_badge: PanelContainer
var _special_badge: PanelContainer
var _greeting: Label
var _likes_row: HFlowContainer
var _patience_row: HBoxContainer
var _patience_bar: ProgressBar
var _patience_fill: StyleBoxFlat
var _compact: bool = false


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.parchment_panel(14))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_portrait = GuestPortrait.new()
	_portrait.custom_minimum_size = Vector2(120, 130)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_name_label = _dark_label(21)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_name_label)
	_count_label = _dark_label(14)
	_count_label.modulate = Color(1, 1, 1, 0.7)
	head.add_child(_count_label)

	_mood_label = _dark_label(14)
	_mood_label.modulate = Color(1, 1, 1, 0.65)
	col.add_child(_mood_label)

	_special_badge = UiKit.chip(Localization.get_text("ui.special_order"), Color(0.85, 0.55, 0.1), 15)
	_special_badge.visible = false
	col.add_child(_special_badge)

	_greeting = _dark_label(15)
	_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_greeting.add_theme_color_override("font_color", Color(0.45, 0.28, 0.12))
	_greeting.custom_minimum_size = Vector2(170, 0)
	_greeting.visible = false
	col.add_child(_greeting)

	_text_label = _dark_label(17)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(170, 0)
	col.add_child(_text_label)

	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 5)
	_chips.add_theme_constant_override("v_separation", 4)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_chips)

	_likes_row = HFlowContainer.new()
	_likes_row.add_theme_constant_override("h_separation", 5)
	_likes_row.add_theme_constant_override("v_separation", 3)
	_likes_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_likes_row)

	_patience_row = HBoxContainer.new()
	_patience_row.add_theme_constant_override("separation", 6)
	_patience_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_patience_row)
	_patience_row.add_child(UiKit.icon_rect("icon_hourglass", 22))
	_patience_bar = ProgressBar.new()
	_patience_bar.show_percentage = false
	_patience_bar.max_value = 1.0
	_patience_bar.value = 1.0
	_patience_bar.custom_minimum_size = Vector2(80, 14)
	_patience_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_patience_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_patience_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.3, 0.2, 0.12, 0.55)
	back.set_corner_radius_all(7)
	_patience_fill = StyleBoxFlat.new()
	_patience_fill.bg_color = UiKit.GREEN
	_patience_fill.set_corner_radius_all(7)
	_patience_bar.add_theme_stylebox_override("background", back)
	_patience_bar.add_theme_stylebox_override("fill", _patience_fill)
	_patience_row.add_child(_patience_bar)

	_new_badge = UiKit.chip(Localization.get_text("ui.new_guest"), Color(0.9, 0.55, 0.15), 14)
	_new_badge.visible = false
	_new_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.add_child(_new_badge)
	_new_badge.move_to_front()


func _dark_label(font_size: int) -> Label:
	var label := UiKit.label("", font_size, UiKit.INK)
	label.add_theme_constant_override("outline_size", 0)
	return label


func set_compact(compact: bool) -> void:
	_compact = compact
	_portrait.custom_minimum_size = Vector2(96, 110) if compact else Vector2(120, 130)
	_text_label.add_theme_font_size_override("font_size", 16 if compact else 17)


func show_order(order: OrderDefinition, customer: CustomerDefinition, content: GameContent, is_new: bool, index: int, total: int, visit: int = 1) -> void:
	_portrait.set_guest(customer)
	_name_label.text = Localization.get_text(customer.display_name_key)
	_mood_label.text = Localization.get_text(order.title_key) if order.is_special else Localization.get_text(customer.mood_key)
	_special_badge.visible = order.is_special
	modulate = Color(1.0, 0.96, 0.84) if order.is_special else Color.WHITE
	# Повторные визиты: гость узнаёт таверну и говорит что-то новое.
	if visit >= 2 and not order.is_special:
		var key: String = "greet.%s.%d" % [customer.id, 2 if visit < 4 else 3]
		_greeting.text = "— " + Localization.get_text(key)
		_greeting.visible = true
	else:
		_greeting.visible = false
	_rebuild_likes(customer)
	_count_label.text = Localization.fmt("ui.guest_n", [index, total])
	_text_label.text = "«" + Localization.get_text(order.text_key) + "»"
	_new_badge.visible = is_new
	_rebuild_chips(order, content)
	update_patience(1.0, false)


func _rebuild_likes(customer: CustomerDefinition) -> void:
	for child in _likes_row.get_children():
		child.queue_free()
	if customer.likes.is_empty():
		return
	_likes_row.add_child(UiKit.icon_rect("icon_heart", 20))
	for property_key in customer.likes:
		_likes_row.add_child(UiKit.chip(Localization.property_name(str(property_key)), Localization.property_color(str(property_key)), 13))


func _rebuild_chips(order: OrderDefinition, content: GameContent) -> void:
	for child in _chips.get_children():
		child.queue_free()
	var base: DishBaseDefinition = content.get_base(order.required_base_id)
	if base != null:
		_chips.add_child(UiKit.chip("%s: %s" % [Localization.get_text("ui.order_base"), Localization.get_text(base.display_name_key)], Color(0.7, 0.5, 0.3)))
	if order.required_main_ids.size() > 0:
		var main: IngredientDefinition = content.get_ingredient(str(order.required_main_ids[0]))
		if main != null:
			_chips.add_child(UiKit.chip("%s: %s" % [Localization.get_text("ui.order_main"), Localization.get_text(main.display_name_key)], Color(0.75, 0.4, 0.25)))
	if order.required_herb_id != "":
		var wanted: IngredientDefinition = content.get_ingredient(order.required_herb_id)
		if wanted != null:
			_chips.add_child(UiKit.chip("%s: %s" % [Localization.get_text("ui.order_herb"), Localization.get_text(wanted.display_name_key)], Color(0.6, 0.55, 0.95)))
	elif order.required_herb_property != "":
		_chips.add_child(UiKit.chip("%s: %s" % [Localization.get_text("ui.order_herb"), Localization.property_adjective(order.required_herb_property)], Localization.property_color(order.required_herb_property)))
	if order.optional_herb_property != "":
		_chips.add_child(UiKit.chip("%s: %s" % [Localization.get_text("ui.order_optional"), Localization.property_adjective(order.optional_herb_property)], Localization.property_color(order.optional_herb_property).darkened(0.1)))


## ratio — оставшееся терпение 0..1. В расслабленном режиме полоса скрыта.
func update_patience(ratio: float, relaxed: bool) -> void:
	_patience_row.visible = not relaxed
	_patience_bar.value = clampf(ratio, 0.0, 1.0)
	if ratio > 0.5:
		_patience_fill.bg_color = UiKit.GREEN
	elif ratio > 0.25:
		_patience_fill.bg_color = Color(0.95, 0.75, 0.25)
	else:
		_patience_fill.bg_color = UiKit.RED
	_portrait.set_impatience(0.0 if relaxed else 1.0 - ratio)


func react(kind: String) -> void:
	_portrait.react(kind)


func guest_center() -> Vector2:
	return _portrait.global_position + _portrait.size * 0.5
