class_name TopStatus
extends PanelContainer
## Верхняя панель: монеты, слава, день и кнопки «Магазин» / «Настройки».


signal shop_pressed
signal settings_pressed
signal book_pressed
signal goals_pressed

var _coins_icon: TextureRect
var _coins_label: Label
var _rep_label: Label
var _day_label: Label
var _shop_button: Button
var _book_button: Button
var _goals_button: Button
var _settings_button: Button
var _shown_coins: int = -1
var _coin_tween: Tween
var _display_coins: float = 0.0
## Пока true, счётчик монет не обновляется (ждём, пока монеты «долетят» с панели результата).
var hold_coins: bool = false
var _compact: bool = false


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.dark_panel(8))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)

	_coins_icon = UiKit.icon_rect("icon_coin", 34)
	row.add_child(_coins_icon)
	_coins_label = UiKit.label("0", 26, UiKit.GOLD)
	_coins_label.custom_minimum_size = Vector2(64, 0)
	_coins_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_coins_label)

	row.add_child(UiKit.icon_rect("icon_star", 32))
	_rep_label = UiKit.label("0", 24, UiKit.CREAM)
	_rep_label.custom_minimum_size = Vector2(44, 0)
	_rep_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_rep_label)

	_day_label = UiKit.label("", 20, UiKit.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_day_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_day_label)

	_shop_button = Button.new()
	_shop_button.text = Localization.get_text("ui.shop")
	_shop_button.icon = UiKit.ui_tex("icon_bag")
	_shop_button.expand_icon = true
	_shop_button.custom_minimum_size = Vector2(0, 46)
	_shop_button.focus_mode = Control.FOCUS_NONE
	_shop_button.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		shop_pressed.emit())
	row.add_child(_shop_button)

	_book_button = Button.new()
	_book_button.text = Localization.get_text("ui.book")
	_book_button.icon = UiKit.ui_tex("icon_book")
	_book_button.expand_icon = true
	_book_button.custom_minimum_size = Vector2(0, 46)
	_book_button.focus_mode = Control.FOCUS_NONE
	_book_button.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		book_pressed.emit())
	row.add_child(_book_button)

	_goals_button = Button.new()
	_goals_button.text = Localization.get_text("ui.goals_btn")
	_goals_button.icon = UiKit.ui_tex("icon_trophy")
	_goals_button.expand_icon = true
	_goals_button.custom_minimum_size = Vector2(0, 46)
	_goals_button.focus_mode = Control.FOCUS_NONE
	_goals_button.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		goals_pressed.emit())
	row.add_child(_goals_button)

	_settings_button = Button.new()
	_settings_button.icon = UiKit.ui_tex("icon_gear")
	_settings_button.expand_icon = true
	_settings_button.custom_minimum_size = Vector2(52, 46)
	_settings_button.focus_mode = Control.FOCUS_NONE
	_settings_button.pressed.connect(func() -> void:
		Audio.play_effect("ui_click")
		settings_pressed.emit())
	row.add_child(_settings_button)


func set_compact(compact: bool) -> void:
	_compact = compact
	_shop_button.text = "" if compact else Localization.get_text("ui.shop")
	_shop_button.custom_minimum_size = Vector2(52 if compact else 0, 46)
	_book_button.text = "" if compact else Localization.get_text("ui.book")
	_book_button.custom_minimum_size = Vector2(52 if compact else 0, 46)
	_goals_button.text = "" if compact else Localization.get_text("ui.goals_btn")
	_goals_button.custom_minimum_size = Vector2(52 if compact else 0, 46)
	_day_label.add_theme_font_size_override("font_size", 16 if compact else 20)


func refresh(session: GameSessionService) -> void:
	var coins: int = session.wallet.coins
	if not hold_coins:
		if _shown_coins < 0:
			_display_coins = float(coins)
			_coins_label.text = str(coins)
		elif coins != _shown_coins:
			_animate_coins(coins)
		_shown_coins = coins
	_rep_label.text = str(session.reputation)
	_day_label.text = Localization.fmt("ui.day", [session.day.day_number])
	if not _compact:
		_day_label.text += " · " + Localization.get_text("stage.%d.name" % session.tavern_stage)


func _animate_coins(target: int) -> void:
	if _coin_tween != null and _coin_tween.is_valid():
		_coin_tween.kill()
	_coin_tween = create_tween()
	_coin_tween.tween_method(_set_display_coins, _display_coins, float(target), 0.6)
	if target > _shown_coins:
		_coins_icon.pivot_offset = _coins_icon.size * 0.5
		var pulse := create_tween()
		pulse.tween_property(_coins_icon, "scale", Vector2.ONE * 1.3, 0.1)
		pulse.tween_property(_coins_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_display_coins(value: float) -> void:
	_display_coins = value
	_coins_label.text = str(int(round(value)))


func coin_target() -> Vector2:
	return _coins_icon.global_position + _coins_icon.size * 0.5
