class_name MainMenu
extends Control
## Главное меню поверх живой сцены таверны: название, «Играть», «Продолжить», «Настройки».


signal new_game_requested
signal continue_requested
signal settings_requested

var _title: Label
var _subtitle: Label
var _buttons: VBoxContainer
var _continue_button: Button
var _confirm: Control
var _has_progress: bool = false
var _pulse: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Затемнение сверху и снизу — текст читается на любом фоне.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(0.05, 0.03, 0.02, 0.85), Color(0.05, 0.03, 0.02, 0.15), Color(0.05, 0.03, 0.02, 0.85)])
	var gradient_tex := GradientTexture2D.new()
	gradient_tex.gradient = gradient
	gradient_tex.fill_from = Vector2(0.5, 0.0)
	gradient_tex.fill_to = Vector2(0.5, 1.0)
	gradient_tex.width = 8
	gradient_tex.height = 256
	shade.texture = gradient_tex
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_title = UiKit.label(Localization.get_text("ui.title"), 76, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.03))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	var divider := HBoxContainer.new()
	divider.alignment = BoxContainer.ALIGNMENT_CENTER
	divider.add_theme_constant_override("separation", 14)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		divider.add_child(UiKit.icon_rect("icon_star", 26 if i == 1 else 20))
	column.add_child(divider)
	_subtitle = UiKit.label(Localization.get_text("ui.subtitle"), 24, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_buttons)
	column.add_child(holder)

	var play := _menu_button("ui.play", true)
	play.pressed.connect(_on_play)
	_continue_button = _menu_button("ui.continue", false)
	_continue_button.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		continue_requested.emit())
	var settings := _menu_button("ui.settings", false)
	settings.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		settings_requested.emit())

	_build_confirm()


func _menu_button(key: String, gold: bool) -> Button:
	var button := Button.new()
	button.text = Localization.get_text(key)
	button.custom_minimum_size = Vector2(320, 64)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 26)
	if gold:
		UiKit.make_gold(button)
	_buttons.add_child(button)
	return button


func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	add_child(_confirm)
	_confirm.add_child(UiKit.dim_background(0.8))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.wood_panel(24))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var text := UiKit.label(Localization.get_text("ui.new_game_confirm"), 24, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(380, 0)
	column.add_child(text)
	var yes := Button.new()
	yes.text = Localization.get_text("ui.yes")
	yes.custom_minimum_size = Vector2(0, 56)
	yes.focus_mode = Control.FOCUS_NONE
	yes.pressed.connect(func() -> void:
		_confirm.visible = false
		Audio.play_effect("ui_click")
		new_game_requested.emit())
	column.add_child(yes)
	var no := Button.new()
	no.text = Localization.get_text("ui.no")
	no.custom_minimum_size = Vector2(0, 56)
	no.focus_mode = Control.FOCUS_NONE
	UiKit.make_gold(no)
	no.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		_confirm.visible = false)
	column.add_child(no)


func _on_play() -> void:
	Audio.play_effect("ui_click")
	if _has_progress:
		_confirm.visible = true
	else:
		new_game_requested.emit()


func open_menu(has_progress: bool) -> void:
	_has_progress = has_progress
	_continue_button.visible = has_progress
	_confirm.visible = false
	visible = true
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.5)
	_title.pivot_offset = _title.size * 0.5
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_title, "scale", Vector2.ONE * 1.025, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_title, "scale", Vector2.ONE, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_narrow(narrow: bool) -> void:
	_title.add_theme_font_size_override("font_size", 56 if narrow else 76)
