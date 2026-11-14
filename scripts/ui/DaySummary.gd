class_name DaySummary
extends Control
## Итоги дня: обслуженные гости, потерянные заказы, монеты, изменение славы.


signal next_day_pressed
signal shop_pressed
signal ad_bonus_pressed
signal ad_pack_pressed

var _panel: PanelContainer
var _title: Label
var _rows: VBoxContainer
var _ad_button: Button
var _pack_button: Button
var _next_button: Button
var _shop_button: Button
var _tween: Tween


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.dim_background(0.75))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.wood_panel(24))
	_panel.custom_minimum_size = Vector2(460, 0)
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	_title = UiKit.label("", 34, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_constant_override("outline_size", 6)
	column.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	column.add_child(_rows)

	_ad_button = Button.new()
	_ad_button.text = Localization.get_text("ui.ad_bonus")
	_ad_button.custom_minimum_size = Vector2(0, 52)
	_ad_button.focus_mode = Control.FOCUS_NONE
	_ad_button.visible = false
	_ad_button.pressed.connect(func() -> void: ad_bonus_pressed.emit())
	column.add_child(_ad_button)

	_pack_button = Button.new()
	_pack_button.text = Localization.get_text("ui.ad_pack")
	_pack_button.custom_minimum_size = Vector2(0, 52)
	_pack_button.focus_mode = Control.FOCUS_NONE
	_pack_button.visible = false
	_pack_button.pressed.connect(func() -> void: ad_pack_pressed.emit())
	column.add_child(_pack_button)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	_shop_button = Button.new()
	_shop_button.text = Localization.get_text("ui.shop")
	_shop_button.icon = UiKit.ui_tex("icon_bag")
	_shop_button.expand_icon = true
	_shop_button.custom_minimum_size = Vector2(150, 60)
	_shop_button.focus_mode = Control.FOCUS_NONE
	_shop_button.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		shop_pressed.emit())
	buttons.add_child(_shop_button)
	_next_button = Button.new()
	_next_button.text = Localization.get_text("ui.next_day")
	_next_button.custom_minimum_size = Vector2(0, 60)
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.focus_mode = Control.FOCUS_NONE
	UiKit.make_gold(_next_button)
	_next_button.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		next_day_pressed.emit())
	buttons.add_child(_next_button)


func set_narrow(narrow: bool) -> void:
	_panel.custom_minimum_size = Vector2(660 if narrow else 460, 0)


func show_summary(summary: Dictionary, ad_available: bool) -> void:
	_title.text = Localization.fmt("ui.day_summary", [int(summary["day_number"])])
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_add_row("ui.served", str(summary["served"]), UiKit.CREAM)
	_add_row("ui.perfect_n", str(summary["perfect"]), UiKit.GOLD)
	_add_row("ui.suitable_n", str(summary["suitable"]), UiKit.CREAM)
	_add_row("ui.wrong_n", str(summary["wrong"]), UiKit.CREAM)
	_add_row("ui.lost_n", str(summary["lost_orders"]), UiKit.RED if int(summary["lost_orders"]) > 0 else UiKit.CREAM)
	_add_row("ui.coins_earned", "+%d" % int(summary["coins_earned"]), UiKit.GOLD)
	if int(summary.get("goals_total", 0)) > 0:
		_add_row("ui.goals_row", "%d / %d" % [int(summary["goals_done"]), int(summary["goals_total"])], UiKit.GREEN if int(summary["goals_done"]) > 0 else UiKit.CREAM)
	if int(summary.get("goal_coins", 0)) > 0:
		_add_row("ui.goal_coins", "+%d" % int(summary["goal_coins"]), UiKit.GOLD)
	var delta: int = int(summary["reputation_delta"])
	_add_row("ui.rep_change", ("+%d" % delta) if delta >= 0 else str(delta), UiKit.GREEN if delta >= 0 else UiKit.RED)
	_add_row("ui.coins_total", str(summary["coins"]), UiKit.GOLD)
	_ad_button.visible = ad_available and int(summary["coins_earned"]) > 0
	_ad_button.disabled = false
	_pack_button.visible = ad_available
	_pack_button.disabled = false
	visible = true
	_panel.scale = Vector2.ONE * 0.85
	modulate = Color(1, 1, 1, 0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate", Color.WHITE, 0.25)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_ad_button() -> void:
	_ad_button.visible = false


func hide_pack_button() -> void:
	_pack_button.visible = false


func update_total(coins: int) -> void:
	for row in _rows.get_children():
		if row.has_meta("is_total"):
			((row as HBoxContainer).get_child(1) as Label).text = str(coins)


func _add_row(key: String, value: String, color: Color) -> void:
	var row := HBoxContainer.new()
	var name_label := UiKit.label(Localization.get_text(key), 20, UiKit.CREAM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := UiKit.label(value, 22, color, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(value_label)
	if key == "ui.coins_total":
		row.set_meta("is_total", true)
	_rows.add_child(row)
