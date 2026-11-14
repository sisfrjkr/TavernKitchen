class_name IngredientTooltip
extends PanelContainer
## Подсказка к ингредиенту. На ПК появляется при наведении, на мобильных — по нажатию на «i».
## Скрывается сама через несколько секунд, чтобы не застревать на экране.


var _icon: TextureRect
var _title: Label
var _desc: Label
var _chips: HFlowContainer
var _extra: Label
var _timer: Timer


func _init() -> void:
	visible = false
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiKit.parchment_panel(14))
	custom_minimum_size = Vector2(250, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(56, 56)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_icon)
	_title = UiKit.label("", 22, UiKit.INK)
	_title.add_theme_constant_override("outline_size", 0)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_title)
	_desc = UiKit.label("", 16, UiKit.INK)
	_desc.add_theme_constant_override("outline_size", 0)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(226, 0)
	column.add_child(_desc)
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 5)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_chips)
	_extra = UiKit.label("", 15, Color(0.55, 0.3, 0.1))
	_extra.add_theme_constant_override("outline_size", 0)
	_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_extra.custom_minimum_size = Vector2(226, 0)
	column.add_child(_extra)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(hide_tip)
	add_child(_timer)


## data: name, desc, icon, props (Array), extra (необязательно). anchor — глобальный прямоугольник карточки.
func show_for(data: Dictionary, anchor: Rect2, auto_hide_seconds: float = 6.0) -> void:
	_icon.texture = UiKit.tex(str(data.get("icon", "")))
	_title.text = str(data.get("name", ""))
	_desc.text = str(data.get("desc", ""))
	for child in _chips.get_children():
		child.queue_free()
	for property_key in data.get("props", []):
		_chips.add_child(UiKit.chip(Localization.property_name(str(property_key)), Localization.property_color(str(property_key)), 14))
	_extra.text = str(data.get("extra", ""))
	_extra.visible = _extra.text != ""
	visible = true
	reset_size()
	await get_tree().process_frame
	if not visible:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var tip_size: Vector2 = size
	# Над карточкой, если помещается; иначе под ней. Всегда внутри экрана.
	var pos := Vector2(anchor.position.x + anchor.size.x * 0.5 - tip_size.x * 0.5, anchor.position.y - tip_size.y - 8.0)
	if pos.y < 8.0:
		pos.y = anchor.end.y + 8.0
	pos.x = clampf(pos.x, 8.0, maxf(8.0, viewport_size.x - tip_size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, viewport_size.y - tip_size.y - 8.0))
	global_position = pos
	_timer.start(auto_hide_seconds)


func hide_tip() -> void:
	visible = false
	if _timer != null:
		_timer.stop()
