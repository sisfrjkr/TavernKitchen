class_name DishPanel
extends PanelContainer
## Панель «Ваше блюдо»: четыре слота (основа, продукт, две травы), подсказка шага,
## кнопки «Готовить» / «Очистить», а во время варки — прогресс и кнопка «Помешать».


signal cook_pressed
signal clear_pressed
signal stir_pressed

var _hint: Label
var _slots: Array[Dictionary] = []
var _slot_row: HBoxContainer
var _build_box: VBoxContainer
var _cook_box: VBoxContainer
var _cook_button: Button
var _clear_button: Button
var _button_row: HBoxContainer
var _progress: ProgressBar
var _cook_label: Label
var _stir_button: Button
var _content: GameContent


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.wood_panel(12))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	_build_box = VBoxContainer.new()
	_build_box.add_theme_constant_override("separation", 6)
	root.add_child(_build_box)
	_hint = UiKit.label("", 16, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(300, 0)
	_build_box.add_child(_hint)

	_slot_row = HBoxContainer.new()
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override("separation", 8)
	_build_box.add_child(_slot_row)
	for caption_key in ["ui.slot_base", "ui.slot_main", "ui.slot_herb", "ui.slot_herb2"]:
		_slots.append(_make_slot(Localization.get_text(caption_key)))

	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", 10)
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_build_box.add_child(_button_row)
	_clear_button = Button.new()
	_clear_button.text = Localization.get_text("ui.clear")
	_clear_button.icon = UiKit.ui_tex("icon_broom")
	_clear_button.expand_icon = true
	_clear_button.custom_minimum_size = Vector2(150, 54)
	_clear_button.focus_mode = Control.FOCUS_NONE
	_clear_button.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		clear_pressed.emit())
	_button_row.add_child(_clear_button)
	_cook_button = Button.new()
	_cook_button.text = Localization.get_text("ui.cook")
	_cook_button.icon = UiKit.ui_tex("icon_flame")
	_cook_button.expand_icon = true
	_cook_button.custom_minimum_size = Vector2(190, 54)
	_cook_button.focus_mode = Control.FOCUS_NONE
	UiKit.make_gold(_cook_button)
	_cook_button.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		cook_pressed.emit())
	_button_row.add_child(_cook_button)

	_cook_box = VBoxContainer.new()
	_cook_box.add_theme_constant_override("separation", 8)
	_cook_box.visible = false
	root.add_child(_cook_box)
	_cook_label = UiKit.label(Localization.get_text("ui.cooking"), 20, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_cook_box.add_child(_cook_label)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.custom_minimum_size = Vector2(300, 20)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.12, 0.07, 0.05)
	back.set_corner_radius_all(10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.65, 0.2)
	fill.set_corner_radius_all(10)
	_progress.add_theme_stylebox_override("background", back)
	_progress.add_theme_stylebox_override("fill", fill)
	_cook_box.add_child(_progress)
	_stir_button = Button.new()
	_stir_button.text = Localization.get_text("ui.stir")
	_stir_button.icon = UiKit.ui_tex("icon_spoon")
	_stir_button.expand_icon = true
	_stir_button.custom_minimum_size = Vector2(0, 54)
	_stir_button.focus_mode = Control.FOCUS_NONE
	UiKit.make_gold(_stir_button)
	_stir_button.pressed.connect(func() -> void: stir_pressed.emit())
	_cook_box.add_child(_stir_button)


func bind(content: GameContent) -> void:
	_content = content


func _make_slot(caption: String) -> Dictionary:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_slot_row.add_child(column)
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.07, 0.05, 0.85)
	style.border_color = Color(0.7, 0.5, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = Vector2(68, 68)
	column.add_child(frame)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UiKit.ui_tex("icon_plus")
	icon.modulate = Color(1, 1, 1, 0.25)
	frame.add_child(icon)
	var label := UiKit.label(caption, 12, Color(0.9, 0.8, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_constant_override("outline_size", 2)
	column.add_child(label)
	return {"frame": frame, "icon": icon, "style": style}


func _fill_slot(index: int, texture_path: String) -> void:
	var slot: Dictionary = _slots[index]
	var icon: TextureRect = slot["icon"]
	var style: StyleBoxFlat = slot["style"]
	if texture_path == "":
		icon.texture = UiKit.ui_tex("icon_plus")
		icon.modulate = Color(1, 1, 1, 0.25)
		style.border_color = Color(0.7, 0.5, 0.25)
	else:
		icon.texture = UiKit.tex(texture_path)
		icon.modulate = Color.WHITE
		style.border_color = UiKit.GOLD


func show_dish(dish: RecipeSelection) -> void:
	if _content == null:
		return
	var base: DishBaseDefinition = _content.get_base(dish.base_id)
	_fill_slot(0, base.icon_path() if base != null else "")
	var main: IngredientDefinition = _content.get_ingredient(dish.main_ingredient_id)
	_fill_slot(1, main.icon_path() if main != null else "")
	var herb1: IngredientDefinition = _content.get_ingredient(dish.primary_herb_id)
	_fill_slot(2, herb1.icon_path() if herb1 != null else "")
	var herb2: IngredientDefinition = _content.get_ingredient(dish.optional_herb_id)
	_fill_slot(3, herb2.icon_path() if herb2 != null else "")
	if dish.base_id == "":
		_hint.text = Localization.get_text("ui.hint_base")
	elif dish.main_ingredient_id == "":
		_hint.text = Localization.get_text("ui.hint_main")
	elif dish.primary_herb_id == "":
		_hint.text = Localization.get_text("ui.hint_herb")
	else:
		_hint.text = Localization.get_text("ui.hint_ready")
	_cook_button.disabled = not dish.is_complete()
	_clear_button.disabled = dish.is_empty()


func set_cooking(active: bool) -> void:
	_build_box.visible = not active
	_cook_box.visible = active
	if active:
		_progress.value = 0.0
		_stir_button.disabled = false


func set_progress(ratio: float, seconds_left: float) -> void:
	_progress.value = ratio
	_cook_label.text = "%s %d" % [Localization.get_text("ui.cooking"), int(ceil(seconds_left))]


func set_narrow(narrow: bool) -> void:
	_hint.custom_minimum_size = Vector2(500 if narrow else 300, 0)
	for slot in _slots:
		(slot["frame"] as Control).custom_minimum_size = Vector2(76, 76) if narrow else Vector2(66, 66)
	_cook_button.custom_minimum_size = Vector2(250 if narrow else 176, 58 if narrow else 54)
	_clear_button.custom_minimum_size = Vector2(190 if narrow else 130, 58 if narrow else 54)
	_progress.custom_minimum_size = Vector2(500 if narrow else 300, 20)
