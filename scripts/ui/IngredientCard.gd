class_name IngredientCard
extends Button
## Карточка ингредиента: иконка, название, свойства, отметка выбора и кнопка «i» с подсказкой.


signal info_requested(card: IngredientCard)

var item_id: String = ""
var kind: String = ""
var tip_data: Dictionary = {}
var locked: bool = false
var _selected: bool = false
var _icon: TextureRect
var _check: TextureRect
var _heart: TextureRect
var _hint: TextureRect
var _tween: Tween


func setup(p_id: String, p_kind: String, data: Dictionary, p_locked: bool, compact: bool) -> void:
	item_id = p_id
	kind = p_kind
	tip_data = data
	locked = p_locked
	custom_minimum_size = Vector2(98, 134) if compact else Vector2(112, 148)
	text = ""
	focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override("normal", UiKit.box("card_normal", 16, Color(0.4, 0.26, 0.17), 6))
	add_theme_stylebox_override("hover", UiKit.box("card_hover", 16, Color(0.5, 0.33, 0.2), 6))
	add_theme_stylebox_override("pressed", UiKit.box("card_selected", 16, Color(0.55, 0.4, 0.2), 6))
	add_theme_stylebox_override("disabled", UiKit.box("card_locked", 16, Color(0.2, 0.17, 0.15), 6))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 6
	column.offset_right = -6
	column.offset_top = 8
	column.offset_bottom = -6
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_icon = TextureRect.new()
	_icon.texture = UiKit.tex(str(data.get("icon", "")))
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(0, 62 if compact else 72)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		_icon.modulate = Color(0.25, 0.25, 0.28, 0.9)
	column.add_child(_icon)

	var name_label := UiKit.label(str(data.get("name", "")), 16 if compact else 17, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 22)
	column.add_child(name_label)

	var props: Array = data.get("props", [])
	var names: PackedStringArray = PackedStringArray()
	for property_key in props:
		names.append(Localization.property_name(str(property_key)))
	var prop_label := UiKit.label(" · ".join(names), 12, Color(0.95, 0.82, 0.5))
	prop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prop_label.add_theme_constant_override("outline_size", 2)
	if locked:
		prop_label.text = ""
	elif names.is_empty():
		prop_label.text = str(data.get("short", ""))
	column.add_child(prop_label)

	if locked:
		var lock := UiKit.icon_rect("icon_lock", 30)
		add_child(lock)
		lock.set_anchors_preset(Control.PRESET_CENTER_TOP)
		lock.offset_left = -15
		lock.offset_right = 15
		lock.offset_top = 26
		lock.offset_bottom = 56

	_check = UiKit.icon_rect("icon_check", 26)
	_check.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_check.offset_left = 4
	_check.offset_top = 4
	_check.offset_right = 30
	_check.offset_bottom = 30
	_check.visible = false
	add_child(_check)

	_heart = UiKit.icon_rect("icon_heart", 24)
	_heart.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_heart.offset_left = 4
	_heart.offset_top = -30
	_heart.offset_right = 28
	_heart.offset_bottom = -6
	_heart.visible = false
	add_child(_heart)
	_hint = UiKit.icon_rect("icon_star", 24)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -28
	_hint.offset_top = -30
	_hint.offset_right = -4
	_hint.offset_bottom = -6
	_hint.visible = false
	add_child(_hint)

	var info := TextureButton.new()
	info.texture_normal = UiKit.ui_tex("icon_info")
	info.ignore_texture_size = true
	info.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	info.custom_minimum_size = Vector2(28, 28)
	info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info.offset_left = -32
	info.offset_right = -4
	info.offset_top = 4
	info.offset_bottom = 32
	info.focus_mode = Control.FOCUS_NONE
	info.pressed.connect(func() -> void: info_requested.emit(self))
	add_child(info)
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func set_selected(value: bool, animate: bool = true) -> void:
	if locked:
		return
	var changed: bool = value != _selected
	_selected = value
	_check.visible = value
	var style: StyleBox = UiKit.box("card_selected", 16, Color(0.55, 0.4, 0.2), 6) if value else UiKit.box("card_normal", 16, Color(0.4, 0.26, 0.17), 6)
	add_theme_stylebox_override("normal", style)
	if value:
		add_theme_stylebox_override("hover", style)
	else:
		add_theme_stylebox_override("hover", UiKit.box("card_hover", 16, Color(0.5, 0.33, 0.2), 6))
	if changed and animate:
		_pop(1.1 if value else 0.96)


## liked — гость любит этот ингредиент (сердечко); required — подходит под заказ (звёздочка-подсказка).
func set_badges(liked: bool, required: bool) -> void:
	_heart.visible = liked and not locked
	_hint.visible = required and not locked


func is_selected() -> bool:
	return _selected


func icon_texture() -> Texture2D:
	return _icon.texture


func _pop(peak: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	pivot_offset = size * 0.5
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * peak, 0.09)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
