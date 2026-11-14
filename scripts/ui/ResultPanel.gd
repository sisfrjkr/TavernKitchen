class_name ResultPanel
extends Control
## Панель результата: оценка, реплика гостя, объяснение, награда с анимацией монет и кнопка «Дальше».


signal continue_pressed
signal coins_arrived

var coin_target: Vector2 = Vector2(80, 30)

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _dish_label: Label
var _banners: VBoxContainer
var _quote: Label
var _portrait: TextureRect
var _lines_box: VBoxContainer
var _payout_box: VBoxContainer
var _total_icon: TextureRect
var _total_label: Label
var _continue: Button
var _tween: Tween
var _shown_total: int = 0


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = UiKit.dim_background(0.6)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.parchment_panel(22))
	_panel.custom_minimum_size = Vector2(440, 0)
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_title = UiKit.label("", 40, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_constant_override("outline_size", 8)
	column.add_child(_title)

	_dish_label = UiKit.label("", 22, Color(0.45, 0.28, 0.12), HORIZONTAL_ALIGNMENT_CENTER)
	_dish_label.add_theme_constant_override("outline_size", 0)
	_dish_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_dish_label)
	_banners = VBoxContainer.new()
	_banners.add_theme_constant_override("separation", 4)
	_banners.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_banners)

	var guest_row := HBoxContainer.new()
	guest_row.add_theme_constant_override("separation", 10)
	column.add_child(guest_row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(78, 78)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	guest_row.add_child(_portrait)
	_quote = UiKit.label("", 18, UiKit.INK)
	_quote.add_theme_constant_override("outline_size", 0)
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quote.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_quote.custom_minimum_size = Vector2(280, 0)
	guest_row.add_child(_quote)

	_lines_box = VBoxContainer.new()
	_lines_box.add_theme_constant_override("separation", 4)
	column.add_child(_lines_box)
	column.add_child(HSeparator.new())
	_payout_box = VBoxContainer.new()
	_payout_box.add_theme_constant_override("separation", 2)
	column.add_child(_payout_box)

	var total_row := HBoxContainer.new()
	total_row.alignment = BoxContainer.ALIGNMENT_CENTER
	total_row.add_theme_constant_override("separation", 8)
	column.add_child(total_row)
	_total_icon = UiKit.icon_rect("icon_coin", 42)
	total_row.add_child(_total_icon)
	_total_label = UiKit.label("+0", 36, Color(0.7, 0.4, 0.05))
	_total_label.add_theme_constant_override("outline_size", 4)
	_total_label.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.8))
	total_row.add_child(_total_label)

	_continue = Button.new()
	_continue.text = Localization.get_text("ui.continue_btn")
	_continue.custom_minimum_size = Vector2(0, 58)
	_continue.focus_mode = Control.FOCUS_NONE
	UiKit.make_gold(_continue)
	_continue.pressed.connect(_on_continue)
	column.add_child(_continue)


func set_narrow(narrow: bool) -> void:
	_panel.custom_minimum_size = Vector2(660 if narrow else 440, 0)
	_quote.custom_minimum_size = Vector2(500 if narrow else 280, 0)


## extra: dish_name (String), discovered (bool), recipe_bonus_line, unlocked_name (String), special_rep (int).
func show_result(order: OrderDefinition, dish: RecipeSelection, result: OrderEvaluation, customer: CustomerDefinition, payout: Dictionary, content: GameContent, extra: Dictionary = {}) -> void:
	var quality_key: String = "perfect" if result.is_perfect() else ("suitable" if result.is_suitable() else "wrong")
	_title.text = Localization.get_text("result.%s.title" % quality_key)
	var color: Color = UiKit.GOLD if result.is_perfect() else (Color(0.9, 0.85, 0.6) if result.is_suitable() else Color(0.9, 0.5, 0.42))
	_title.add_theme_color_override("font_color", color)
	var expression: String = "happy" if result.is_perfect() else ("calm" if result.is_suitable() else "sad")
	_portrait.texture = UiKit.tex(customer.portrait_path(expression))
	_quote.text = "«" + Localization.get_text(result.reaction_key) + "»"
	_dish_label.text = "«%s»" % str(extra.get("dish_name", ""))
	_dish_label.visible = str(extra.get("dish_name", "")) != ""
	_fill_banners(payout, extra)
	_fill_lines(ResultExplainer.build(order, dish, result, content))
	_fill_payout(payout, result, extra)
	_open(int(payout.get("total", 0)))


func show_lost(customer: CustomerDefinition) -> void:
	_dish_label.visible = false
	_clear(_banners)
	_title.text = Localization.get_text("result.lost.title")
	_title.add_theme_color_override("font_color", Color(0.9, 0.55, 0.45))
	_portrait.texture = UiKit.tex(customer.portrait_path("sad"))
	_quote.text = Localization.get_text("result.lost.text")
	_clear(_lines_box)
	_clear(_payout_box)
	_payout_box.add_child(_row_label("%s: -%d" % [Localization.get_text("ui.reputation"), EconomyService.REPUTATION_LOST], Color(0.7, 0.25, 0.2)))
	_open(0)


func _fill_lines(lines: Array[Dictionary]) -> void:
	_clear(_lines_box)
	for line in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var ok: bool = bool(line["ok"])
		row.add_child(UiKit.icon_rect("icon_check" if ok else "icon_cross", 24))
		var label := UiKit.label(str(line["text"]), 16, Color(0.22, 0.4, 0.15) if ok else Color(0.65, 0.22, 0.15))
		label.add_theme_constant_override("outline_size", 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(300, 0)
		row.add_child(label)
		_lines_box.add_child(row)


func _fill_banners(payout: Dictionary, extra: Dictionary) -> void:
	_clear(_banners)
	if bool(extra.get("discovered", false)):
		_banners.add_child(UiKit.chip("%s  +%d" % [Localization.get_text("ui.new_recipe"), int(payout.get("discovery", 0))], Color(0.9, 0.6, 0.1), 18))
	if str(extra.get("unlocked_name", "")) != "":
		_banners.add_child(UiKit.chip(Localization.fmt("ui.rare_unlocked", [str(extra["unlocked_name"])]), Color(0.55, 0.45, 0.9), 16))


func _fill_payout(payout: Dictionary, result: OrderEvaluation, extra: Dictionary = {}) -> void:
	_clear(_payout_box)
	var hint_key: String = "ui.perfect_hint" if result.is_perfect() else ("ui.suitable_hint" if result.is_suitable() else "ui.wrong_hint")
	_payout_box.add_child(_row_label(Localization.get_text(hint_key), Color(0.4, 0.28, 0.15)))
	if int(payout.get("base", 0)) > 0:
		_payout_box.add_child(_row_label("%s: +%d" % [Localization.get_text("ui.reward"), int(payout["base"])], UiKit.INK))
	if int(payout.get("tip", 0)) > 0:
		_payout_box.add_child(_row_label("%s: +%d" % [Localization.get_text("ui.tip"), int(payout["tip"])], UiKit.INK))
	if int(payout.get("counter_bonus", 0)) > 0:
		_payout_box.add_child(_row_label("%s: +%d" % [Localization.get_text("ui.counter_bonus"), int(payout["counter_bonus"])], UiKit.INK))
	if int(payout.get("streak_bonus", 0)) > 0:
		_payout_box.add_child(_row_label("%s: +%d" % [Localization.get_text("ui.streak_bonus"), int(payout["streak_bonus"])], UiKit.INK))
	if int(payout.get("taste", 0)) > 0:
		_payout_box.add_child(_row_label("%s: +%d" % [Localization.get_text("ui.taste_bonus"), int(payout["taste"])], Color(0.7, 0.2, 0.3)))
	if int(payout.get("recipe_bonus", 0)) > 0:
		_payout_box.add_child(_row_label("%s: +%d" % [Localization.get_text("ui.recipe_bonus"), int(payout["recipe_bonus"])], UiKit.INK))
	if int(payout.get("daily_bonus", 0)) > 0:
		_payout_box.add_child(_row_label("%s: +%d" % [Localization.get_text("ui.daily_bonus"), int(payout["daily_bonus"])], Color(0.2, 0.45, 0.2)))
	if int(payout.get("discovery", 0)) > 0:
		_payout_box.add_child(_row_label("%s: +%d" % [Localization.get_text("ui.discovery_bonus"), int(payout["discovery"])], Color(0.7, 0.4, 0.05)))
	if int(extra.get("special_rep", 0)) > 0:
		_payout_box.add_child(_row_label("%s: +%d" % [Localization.get_text("ui.special_rep"), int(extra["special_rep"])], Color(0.35, 0.3, 0.7)))


func _row_label(text: String, color: Color) -> Label:
	var label := UiKit.label(text, 16, color)
	label.add_theme_constant_override("outline_size", 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _clear(box: Control) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _open(total: int) -> void:
	_shown_total = total
	_total_label.text = "+0"
	_total_icon.visible = total > 0
	_total_label.visible = total > 0
	_continue.disabled = false
	visible = true
	_panel.scale = Vector2.ONE * 0.85
	modulate = Color(1, 1, 1, 0)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	_tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if total > 0:
		_tween.tween_method(_set_total_text, 0.0, float(total), 0.7)


func _set_total_text(value: float) -> void:
	_total_label.text = "+%d" % int(round(value))


func _on_continue() -> void:
	Audio.play_effect("ui_click")
	_continue.disabled = true
	if _shown_total > 0:
		_fly_coins(mini(_shown_total, 12))
		await get_tree().create_timer(0.75).timeout
	visible = false
	coins_arrived.emit()
	continue_pressed.emit()


func _fly_coins(count: int) -> void:
	Audio.play_effect("coin")
	var start: Vector2 = _total_icon.global_position
	for i in count:
		var coin := UiKit.icon_rect("icon_coin", 34)
		coin.z_index = 100
		add_child(coin)
		coin.global_position = start + Vector2(randf_range(-20, 20), randf_range(-10, 10))
		var tween := create_tween()
		tween.tween_interval(0.05 * i)
		tween.tween_property(coin, "global_position", coin_target - Vector2(17, 17), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(coin.queue_free)
