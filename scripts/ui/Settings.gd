class_name SettingsPanel
extends Control
## Настройки: общая громкость, музыка, атмосфера, голоса, эффекты; расслабленный режим; возврат в меню.


signal closed
signal menu_requested

const GROUPS: Array[String] = ["master", "music", "ambience", "voices", "sfx"]

var _panel: PanelContainer
var _scroll: ScrollContainer
var _sliders: Dictionary = {}
var _relaxed_button: Button
var _menu_button: Button
var _in_game: bool = false


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.dim_background(0.78))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.wood_panel(22))
	_panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	column.add_child(UiKit.label(Localization.get_text("ui.settings"), 34, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(inner)
	for group in GROUPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		inner.add_child(row)
		var label := UiKit.label(Localization.get_text("ui.vol_" + group), 20)
		label.custom_minimum_size = Vector2(150, 0)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(200, 36)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(_on_volume_changed.bind(group))
		row.add_child(slider)
		_sliders[group] = slider
	_relaxed_button = Button.new()
	_relaxed_button.toggle_mode = true
	_relaxed_button.custom_minimum_size = Vector2(0, 56)
	_relaxed_button.focus_mode = Control.FOCUS_NONE
	_relaxed_button.toggled.connect(_on_relaxed_toggled)
	inner.add_child(_relaxed_button)

	_menu_button = Button.new()
	_menu_button.text = Localization.get_text("ui.to_menu")
	_menu_button.custom_minimum_size = Vector2(0, 54)
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		close_settings()
		menu_requested.emit())
	column.add_child(_menu_button)

	var close := Button.new()
	close.text = Localization.get_text("ui.close")
	close.custom_minimum_size = Vector2(0, 58)
	close.focus_mode = Control.FOCUS_NONE
	UiKit.make_gold(close)
	close.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		close_settings())
	column.add_child(close)


func set_narrow(narrow: bool) -> void:
	_apply_size(narrow)


func _apply_size(narrow: bool = false) -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var width: float = minf(viewport.x - 24.0, 660.0 if narrow else 520.0)
	_panel.custom_minimum_size = Vector2(width, 0)
	_scroll.custom_minimum_size = Vector2(width - 44.0, minf(maxf(220.0, viewport.y - 260.0), 460.0))


func open_settings(in_game: bool) -> void:
	_in_game = in_game
	_apply_size(get_viewport_rect().size.x < get_viewport_rect().size.y)
	var data: SaveData = TavernSave.save_data
	var values: Dictionary = {"master": data.master_volume, "music": data.music_volume, "ambience": data.ambience_volume, "voices": data.voices_volume, "sfx": data.sfx_volume}
	for group in GROUPS:
		(_sliders[group] as HSlider).set_value_no_signal(float(values[group]))
	_relaxed_button.set_pressed_no_signal(data.relaxed_mode)
	_update_relaxed_text()
	_menu_button.visible = in_game
	visible = true


func close_settings() -> void:
	visible = false
	TavernSave.save()
	closed.emit()


func _on_volume_changed(value: float, group: String) -> void:
	match group:
		"master":
			TavernSave.set_master_volume(value)
			Audio.set_master_volume(value)
		"music":
			TavernSave.set_music_volume(value)
			Audio.set_music_volume(value)
		"ambience":
			TavernSave.set_ambience_volume(value)
			Audio.set_ambience_volume(value)
		"voices":
			TavernSave.set_voices_volume(value)
			Audio.set_voices_volume(value)
			Audio.play_event("murmur")
		"sfx":
			TavernSave.set_sfx_volume(value)
			Audio.set_sfx_volume(value)
			Audio.play_effect("ui_click")


func _on_relaxed_toggled(pressed: bool) -> void:
	TavernSave.set_relaxed_mode(pressed)
	_update_relaxed_text()
	Audio.play_effect("ui_click")


func _update_relaxed_text() -> void:
	var state: String = Localization.get_text("ui.on" if _relaxed_button.button_pressed else "ui.off")
	_relaxed_button.text = "%s: %s" % [Localization.get_text("ui.relaxed"), state]
