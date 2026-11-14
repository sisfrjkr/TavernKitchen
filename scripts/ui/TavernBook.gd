class_name TavernBook
extends Control
## Книга таверны: ежедневные цели, достижения и коллекция гостей (три вкладки).


signal closed

const TABS: Array[String] = ["goals", "ach", "guests"]

var session: GameSessionService
var _panel: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _tab_buttons: Dictionary = {}
var _header: Label
var _tab: String = "goals"


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
	head.add_child(UiKit.icon_rect("icon_trophy", 40))
	var title := UiKit.label(Localization.get_text("ui.goals_title"), 32, UiKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	for tab in TABS:
		var button := Button.new()
		button.toggle_mode = true
		button.text = Localization.get_text("ui.tab_" + tab)
		button.custom_minimum_size = Vector2(0, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_tab.bind(tab))
		tabs.add_child(button)
		_tab_buttons[tab] = button
	_header = UiKit.label("", 18, UiKit.CREAM)
	column.add_child(_header)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var close := Button.new()
	close.text = Localization.get_text("ui.close_panel")
	close.custom_minimum_size = Vector2(0, 54)
	close.focus_mode = Control.FOCUS_NONE
	UiKit.make_gold(close)
	close.pressed.connect(close_book)
	column.add_child(close)


func bind(p_session: GameSessionService) -> void:
	session = p_session
	session.stats_changed.connect(func() -> void:
		if visible:
			_rebuild())


func set_narrow(_narrow: bool) -> void:
	_apply_size()


func _apply_size() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var width: float = minf(viewport.x - 24.0, 700.0)
	_panel.custom_minimum_size = Vector2(width, 0)
	_scroll.custom_minimum_size = Vector2(width - 40.0, maxf(220.0, viewport.y - 330.0))


func open_book(tab: String = "goals") -> void:
	_tab = tab
	_apply_size()
	_rebuild()
	visible = true
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)


func close_book() -> void:
	Audio.play_effect("ui_click")
	visible = false
	closed.emit()


func _on_tab(tab: String) -> void:
	Audio.play_effect("ui_click")
	_tab = tab
	_rebuild()


func _rebuild() -> void:
	for key in _tab_buttons:
		(_tab_buttons[key] as Button).set_pressed_no_signal(key == _tab)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _tab == "goals":
		_build_goals()
	elif _tab == "ach":
		_build_achievements()
	else:
		_build_guests()


func _card(style: String = "card_normal") -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(style, 16, Color(0.3, 0.2, 0.15), 10))
	return card


func _wrap(text: String, size: int, color: Color) -> Label:
	var label := UiKit.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(200, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _build_goals() -> void:
	_header.text = "%s · %s" % [Localization.get_text("stage.%d.name" % session.tavern_stage), Localization.fmt("ui.goals_total", [session.save_service.save_data.goals_completed_total])]
	_list.add_child(UiKit.label(Localization.get_text("ui.goals_today"), 22, UiKit.GOLD))
	for goal in session.day.goals:
		var definition: DailyGoalDefinition = session.content.get_goal(str(goal["id"]))
		var done: bool = bool(goal["done"])
		var card := _card("card_selected" if done else "card_normal")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		row.add_child(UiKit.icon_rect("icon_check" if done else "icon_star", 36))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(_wrap(Localization.get_text(definition.text_key), 19, UiKit.GREEN if done else UiKit.CREAM))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = float(goal["target"])
		bar.value = float(goal["progress"])
		bar.custom_minimum_size = Vector2(120, 12)
		col.add_child(bar)
		var reward := HBoxContainer.new()
		reward.add_theme_constant_override("separation", 4)
		reward.add_child(UiKit.icon_rect("icon_coin", 26))
		reward.add_child(UiKit.label("+%d" % int(goal["reward"]), 22, UiKit.GOLD))
		row.add_child(reward)
		_list.add_child(card)


func _build_achievements() -> void:
	var data: SaveData = session.save_service.save_data
	_header.text = Localization.fmt("ui.ach_count", [data.achievements.size(), session.content.achievements.size()])
	for achievement in session.content.achievements:
		var unlocked: bool = data.achievements.has(achievement.id)
		var card := _card("card_selected" if unlocked else "card_locked")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var icon := UiKit.icon_rect("icon_trophy" if unlocked else "icon_lock", 40)
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(_wrap(Localization.get_text(achievement.name_key), 20, UiKit.GOLD if unlocked else Color(0.75, 0.7, 0.62)))
		col.add_child(_wrap(Localization.get_text(achievement.desc_key), 15, UiKit.CREAM if unlocked else Color(0.7, 0.65, 0.58)))
		if not unlocked:
			var value: int = mini(session.stat_value(achievement.stat), achievement.target)
			col.add_child(UiKit.label("%d / %d" % [value, achievement.target], 14, Color(0.85, 0.75, 0.5)))
		var reward := HBoxContainer.new()
		reward.add_theme_constant_override("separation", 4)
		reward.add_child(UiKit.icon_rect("icon_coin", 24))
		reward.add_child(UiKit.label("+%d" % achievement.reward_coins, 20, UiKit.GOLD if unlocked else Color(0.7, 0.62, 0.45)))
		row.add_child(reward)
		_list.add_child(card)


func _build_guests() -> void:
	var data: SaveData = session.save_service.save_data
	var met: int = 0
	for customer in session.content.customers:
		if data.opened_customers.has(customer.id):
			met += 1
	_header.text = Localization.fmt("ui.guests_met", [met, session.content.customers.size()])
	for customer in session.content.customers:
		var known: bool = data.opened_customers.has(customer.id)
		var card := _card("card_selected" if known else "card_locked")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var portrait := TextureRect.new()
		portrait.texture = UiKit.tex(customer.portrait_path("calm"))
		portrait.custom_minimum_size = Vector2(84, 84)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not known:
			portrait.modulate = Color(0.08, 0.08, 0.1, 0.9)
		row.add_child(portrait)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		if known:
			col.add_child(_wrap(Localization.get_text(customer.display_name_key), 21, UiKit.GOLD))
			col.add_child(_wrap(Localization.get_text(customer.bio_key), 15, UiKit.CREAM))
			var likes := HFlowContainer.new()
			likes.add_theme_constant_override("h_separation", 5)
			likes.add_child(UiKit.icon_rect("icon_heart", 20))
			for property_key in customer.likes:
				likes.add_child(UiKit.chip(Localization.property_name(str(property_key)), Localization.property_color(str(property_key)), 13))
			col.add_child(likes)
			col.add_child(UiKit.label(Localization.fmt("ui.visits", [int(data.guest_visits.get(customer.id, 0))]), 14, Color(0.9, 0.8, 0.55)))
		else:
			col.add_child(UiKit.label("???", 22, Color(0.75, 0.7, 0.62)))
			col.add_child(_wrap(Localization.fmt("ui.guest_locked", [customer.unlock_reputation]), 15, Color(0.7, 0.65, 0.58)))
		_list.add_child(card)
