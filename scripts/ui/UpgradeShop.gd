class_name UpgradeShop
extends Control
## Магазин улучшений: карточки с иконкой, описанием эффекта, ценой и состоянием покупки.


signal closed

var session: GameSessionService
var _panel: PanelContainer
var _list: VBoxContainer
var _coins_label: Label
var _scroll: ScrollContainer
var _narrow: bool = false


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
	_panel.add_theme_stylebox_override("panel", UiKit.dark_panel(20))
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	var title := UiKit.label(Localization.get_text("ui.shop"), 32, UiKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.icon_rect("icon_coin", 32))
	_coins_label = UiKit.label("0", 26, UiKit.GOLD)
	head.add_child(_coins_label)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var close := Button.new()
	close.text = Localization.get_text("ui.close")
	close.custom_minimum_size = Vector2(0, 54)
	close.focus_mode = Control.FOCUS_NONE
	UiKit.make_gold(close)
	close.pressed.connect(close_shop)
	column.add_child(close)


func bind(p_session: GameSessionService) -> void:
	session = p_session
	session.stats_changed.connect(func() -> void:
		if visible:
			_rebuild())


func set_narrow(narrow: bool) -> void:
	_narrow = narrow
	_apply_size()


func _apply_size() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var width: float = minf(viewport.x - 24.0, 680.0 if not _narrow else 696.0)
	_panel.custom_minimum_size = Vector2(width, 0)
	_scroll.custom_minimum_size = Vector2(width - 40.0, maxf(240.0, viewport.y - 260.0))


func open_shop() -> void:
	_apply_size()
	_rebuild()
	visible = true
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)


func close_shop() -> void:
	Audio.play_effect("ui_click")
	visible = false
	closed.emit()


func _rebuild() -> void:
	_coins_label.text = str(session.wallet.coins)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var upgrades: Array[UpgradeDefinition] = []
	for source in session.content.upgrades:
		upgrades.append(source)
	# Купленные — в конец списка, остальные по возрастанию цены.
	upgrades.sort_custom(func(a: UpgradeDefinition, b: UpgradeDefinition) -> bool:
		var a_owned: bool = session.has_upgrade(a.id)
		var b_owned: bool = session.has_upgrade(b.id)
		if a_owned != b_owned:
			return b_owned
		return a.cost_coins < b.cost_coins)
	for upgrade in upgrades:
		_list.add_child(_make_card(upgrade))


func _make_card(upgrade: UpgradeDefinition) -> Control:
	var owned: bool = session.has_upgrade(upgrade.id)
	var affordable: bool = session.wallet.has(upgrade.cost_coins)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box("card_selected" if owned else "card_normal", 16, Color(0.4, 0.26, 0.17), 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.texture = UiKit.tex("res://assets/ui/up_%s.png" % upgrade.visual_id)
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)
	text_col.add_child(UiKit.label(Localization.get_text(upgrade.display_name_key), 22, UiKit.GOLD))
	var desc := UiKit.label(Localization.get_text(upgrade.description_key), 15, UiKit.CREAM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(150, 0)
	text_col.add_child(desc)
	var effect := UiKit.label(Localization.get_text(upgrade.display_name_key.replace(".name", ".effect")), 15, UiKit.GREEN)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.custom_minimum_size = Vector2(150, 0)
	text_col.add_child(effect)

	var buy_col := VBoxContainer.new()
	buy_col.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_col.add_theme_constant_override("separation", 4)
	row.add_child(buy_col)
	if owned:
		var owned_row := HBoxContainer.new()
		owned_row.add_theme_constant_override("separation", 4)
		owned_row.add_child(UiKit.icon_rect("icon_check", 26))
		owned_row.add_child(UiKit.label(Localization.get_text("ui.owned"), 18, UiKit.GREEN))
		buy_col.add_child(owned_row)
	else:
		var price_row := HBoxContainer.new()
		price_row.alignment = BoxContainer.ALIGNMENT_CENTER
		price_row.add_theme_constant_override("separation", 4)
		price_row.add_child(UiKit.icon_rect("icon_coin", 26))
		price_row.add_child(UiKit.label(str(upgrade.cost_coins), 22, UiKit.GOLD if affordable else UiKit.RED))
		buy_col.add_child(price_row)
		var buy := Button.new()
		buy.text = Localization.get_text("ui.buy")
		buy.custom_minimum_size = Vector2(120, 48)
		buy.disabled = not affordable
		buy.focus_mode = Control.FOCUS_NONE
		if affordable:
			UiKit.make_gold(buy)
		buy.pressed.connect(_on_buy.bind(upgrade.id))
		buy_col.add_child(buy)
		if not affordable:
			var missing := UiKit.label(Localization.fmt("ui.not_enough", [upgrade.cost_coins - session.wallet.coins]), 13, UiKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
			buy_col.add_child(missing)
	return card


func _on_buy(upgrade_id: String) -> void:
	if session.buy_upgrade(upgrade_id):
		Audio.play_effect("buy")
	_rebuild()
