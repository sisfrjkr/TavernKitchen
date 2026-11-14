class_name GameScreen
extends Control
## Экран игры: связывает игровую логику (GameSession), интерфейс и 3D-таверну.
## Раскладка адаптивна: на широком экране — гость слева, лоток внизу; на узком (портрет) —
## всё перестраивается в колонку, а размер логического экрана переключается на 720×1280.


const WIDE_SIZE: Vector2i = Vector2i(1280, 720)
const NARROW_SIZE: Vector2i = Vector2i(720, 1280)

var session: GameSessionService
var tavern: Tavern

var _narrow: bool = false
var _layout_ready: bool = false
var _in_game: bool = false
var _active_modal: Control = null
var _toast_queue: Array[String] = []
var _toast_busy: bool = false

var _top: TopStatus
var _order_card: OrderCard
var _dish_panel: DishPanel
var _tray: IngredientTray
var _result: ResultPanel
var _summary: DaySummary
var _shop: UpgradeShop
var _settings: SettingsPanel
var _book: RecipeBook
var _goals: TavernBook
var _tutorial: TutorialOverlay
var _menu: MainMenu
var _tooltip: IngredientTooltip
var _fly_layer: Control
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _hud: Control
var _vignette: TextureRect


func _ready() -> void:
	session = GameSession
	theme = UiKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scene_root: Node = get_parent().get_parent() if get_parent() != null else null
	if scene_root != null:
		tavern = scene_root.get_node_or_null("Tavern") as Tavern
	_build_ui()
	_connect_session()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_show_menu()
	if tavern != null:
		Audio.set_world_positions(tavern.audio_positions())
	Audio.play_track("menu")
	Audio.play_ambience()
	Audio.set_crowd_level(2)


# --- Сборка интерфейса -----------------------------------------------------------------

func _build_ui() -> void:
	_vignette = TextureRect.new()
	_vignette.texture = _make_vignette()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.visible = false
	add_child(_hud)

	_top = TopStatus.new()
	_top.shop_pressed.connect(_open_shop)
	_top.settings_pressed.connect(func() -> void: _open_settings(true))
	_top.book_pressed.connect(_open_book)
	_top.goals_pressed.connect(_open_goals)
	_hud.add_child(_top)

	_order_card = OrderCard.new()
	_hud.add_child(_order_card)

	_dish_panel = DishPanel.new()
	_dish_panel.bind(session.content)
	_dish_panel.cook_pressed.connect(_on_cook_pressed)
	_dish_panel.clear_pressed.connect(func() -> void: session.clear_dish())
	_dish_panel.stir_pressed.connect(_on_stir_pressed)
	_hud.add_child(_dish_panel)

	_tray = IngredientTray.new()
	_tray.bind(session)
	_tray.item_pressed.connect(_on_item_pressed)
	_tray.tip_requested.connect(_on_tip_requested)
	_tray.tip_hidden.connect(func() -> void: _tooltip.hide_tip())
	_hud.add_child(_tray)

	_fly_layer = Control.new()
	_fly_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fly_layer)

	_tooltip = IngredientTooltip.new()
	add_child(_tooltip)

	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UiKit.dark_panel(10))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate = Color(1, 1, 1, 0)
	_toast_label = UiKit.label("", 22, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_child(_toast_label)
	add_child(_toast)

	_result = ResultPanel.new()
	_result.continue_pressed.connect(_on_result_continue)
	_result.coins_arrived.connect(func() -> void:
		_top.hold_coins = false
		_top.refresh(session))
	add_child(_result)

	_summary = DaySummary.new()
	_summary.next_day_pressed.connect(_on_next_day)
	_summary.shop_pressed.connect(_open_shop)
	_summary.ad_bonus_pressed.connect(_on_ad_bonus_pressed)
	_summary.ad_pack_pressed.connect(_on_ad_pack_pressed)
	add_child(_summary)

	_shop = UpgradeShop.new()
	_shop.bind(session)
	_shop.closed.connect(_on_overlay_closed)
	add_child(_shop)

	_settings = SettingsPanel.new()
	_settings.closed.connect(_on_overlay_closed)
	_settings.menu_requested.connect(_return_to_menu)
	add_child(_settings)

	_book = RecipeBook.new()
	_book.bind(session)
	_book.closed.connect(_on_overlay_closed)
	add_child(_book)

	_goals = TavernBook.new()
	_goals.bind(session)
	_goals.closed.connect(_on_overlay_closed)
	add_child(_goals)

	_menu = MainMenu.new()
	_menu.new_game_requested.connect(func() -> void: _start_game(true))
	_menu.continue_requested.connect(func() -> void: _start_game(false))
	_menu.settings_requested.connect(func() -> void: _open_settings(false))
	add_child(_menu)

	_tutorial = TutorialOverlay.new()
	_tutorial.finished.connect(_on_tutorial_finished)
	add_child(_tutorial)

	# Порядок отрисовки: 3D → виньетка → HUD → меню → окна (результат, итоги, магазин, настройки, книги) → обучение.
	# Меню должно лежать НИЖЕ окон, иначе его кнопки рисуются поверх настроек, открытых из меню.
	move_child(_menu, _fly_layer.get_index())
	move_child(_vignette, 0)


func _connect_session() -> void:
	session.order_issued.connect(_on_order_issued)
	session.dish_changed.connect(_on_dish_changed)
	session.state_changed.connect(_on_state_changed)
	session.cooking_progress_changed.connect(_on_cooking_progress)
	session.order_resolved.connect(_on_order_resolved)
	session.order_lost.connect(_on_order_lost)
	session.day_finished.connect(_on_day_finished)
	session.upgrade_purchased.connect(_on_upgrade_purchased)
	session.stirred.connect(_on_stirred)
	session.goal_completed.connect(_on_goal_completed)
	session.stage_changed.connect(_on_stage_changed)
	session.achievement_unlocked.connect(_on_achievement_unlocked)
	session.stats_changed.connect(func() -> void: _top.refresh(session))


# --- Адаптивная раскладка ----------------------------------------------------------------

func _apply_layout() -> void:
	var window: Window = get_window()
	var pixel_size: Vector2 = Vector2(window.size)
	var want_narrow: bool = pixel_size.x / maxf(1.0, pixel_size.y) < 1.15
	if want_narrow != _narrow or not _layout_ready:
		_narrow = want_narrow
		window.content_scale_size = NARROW_SIZE if _narrow else WIDE_SIZE
	_layout_ready = true
	_place_controls()
	if tavern != null:
		tavern.set_layout(_narrow)
	for widget in [_order_card, _dish_panel, _tray, _result, _summary, _shop, _settings, _book, _goals, _menu]:
		if widget.has_method("set_narrow"):
			widget.call("set_narrow", _narrow)
	_order_card.set_compact(_narrow)
	_top.set_compact(_narrow)
	_tray.set_narrow(_narrow)


func _place(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w


func _place_controls() -> void:
	var cooking: bool = session.day.state == GameSessionService.STATE_COOKING
	var tray_height: float = 410.0 if _narrow else 214.0
	var dish_bottom: float = -(8.0 if cooking else tray_height + 16.0)
	_place(_top, Vector4(0, 0, 1, 0), Vector4(10, 8, -10, 66))
	_dish_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tray.visible = not cooking
	if _narrow:
		_place(_order_card, Vector4(0, 0, 1, 0), Vector4(10, 74, -10, 74))
		_place(_tray, Vector4(0, 1, 1, 1), Vector4(10, -tray_height, -10, -10))
		_place(_dish_panel, Vector4(0, 1, 1, 1), Vector4(10, dish_bottom, -10, dish_bottom))
	else:
		_place(_order_card, Vector4(0, 0, 0, 0), Vector4(12, 74, 372, 74))
		_place(_tray, Vector4(0, 1, 1, 1), Vector4(12, -tray_height, -12, -10))
		# Широкий экран: панель блюда — отдельная правая колонка (не перекрывает котёл и лоток).
		_dish_panel.grow_vertical = Control.GROW_DIRECTION_END
		_place(_dish_panel, Vector4(1, 0, 1, 0), Vector4(-372, 74, -12, 74))
	_place(_toast, Vector4(0.5, 0, 0.5, 0), Vector4(-190, 78 if not _narrow else 330, 190, 78 if not _narrow else 330))
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH


# --- Меню и старт ---------------------------------------------------------------------------

func _show_menu() -> void:
	_in_game = false
	_close_all_overlays()
	session.running = false
	session.paused = true
	_hud.visible = false
	_result.visible = false
	_summary.visible = false
	if tavern != null:
		tavern.apply_upgrades(session)
		tavern.set_menu_view(true)
	Audio.set_night(false)
	Audio.set_crowd_level(2)
	Audio.play_track("menu")
	_menu.open_menu(session.has_saved_progress())


func _start_game(new_game: bool) -> void:
	_menu.visible = false
	session.start_session(new_game)
	_in_game = true
	_hud.visible = true
	if tavern != null:
		tavern.apply_upgrades(session)
		tavern.set_menu_view(false)
	_top.hold_coins = false
	_top.refresh(session)
	_place_controls()
	_tray.show_tab("base")
	Audio.play_track("day")
	if tavern != null:
		tavern.set_crowd(2)
	if Props.missing.size() > 0:
		_show_toast(Localization.fmt("ui.models_missing", [Props.missing.size()]))
	if not TavernSave.save_data.tutorial_seen:
		call_deferred("_start_tutorial")


func _return_to_menu() -> void:
	session.running = false
	_show_menu()


# --- Реакции на игровую логику ---------------------------------------------------------------

func _on_order_issued(order: OrderDefinition) -> void:
	var customer: CustomerDefinition = session.day.current_customer
	_order_card.show_order(order, customer, session.content, session.day.guest_is_new, session.day.orders_issued, session.day.orders_per_day, session.day.guest_visit)
	_tray.set_hints(order, customer, TavernSave.save_data.relaxed_mode)
	_tray.show_tab("base")
	_tray.sync_selection(session.day.dish)
	_dish_panel.show_dish(session.day.dish)
	_dish_panel.set_cooking(false)
	_place_controls()
	_top.refresh(session)
	Audio.play_effect("order_issued")
	Audio.guest_arrives()
	_update_audio_mood(order)
	if tavern != null:
		tavern.set_crowd(1 + mini(5, session.day.orders_issued))
	if session.day.orders_issued == 1 and session.day.daily_recipe_id != "":
		var daily: RecipeDefinition = session.content.get_recipe(session.day.daily_recipe_id)
		if daily != null:
			_show_toast(Localization.fmt("ui.daily_today", [Localization.get_text(daily.name_key)]))
	if order.is_special:
		_show_toast(Localization.get_text("ui.special_order"))
	if session.day.guest_is_new:
		_show_toast(Localization.get_text("ui.new_guest"))


## Музыка и атмосфера по ходу дня: особый заказ — живая тема, последний заказ дня — вечерняя.
func _update_audio_mood(order: OrderDefinition) -> void:
	var evening: bool = session.day.orders_issued >= session.day.orders_per_day and not order.is_special
	Audio.set_night(evening)
	Audio.set_crowd_level(1 + mini(5, session.day.orders_issued))
	if order.is_special:
		Audio.play_track("event")
	elif evening:
		Audio.play_track("evening")
	else:
		Audio.play_track("day")


func _on_dish_changed(dish: RecipeSelection) -> void:
	_dish_panel.show_dish(dish)
	_tray.sync_selection(dish)
	if tavern != null:
		tavern.kitchen.show_dish(dish, session.content)


func _on_state_changed(state: int) -> void:
	var cooking: bool = state == GameSessionService.STATE_COOKING
	_dish_panel.set_cooking(cooking)
	_place_controls()
	Audio.set_boiling(cooking)
	if tavern != null:
		tavern.kitchen.set_cooking(cooking)
	if state == GameSessionService.STATE_WAITING_FOR_ORDER:
		_dish_panel.show_dish(session.day.dish)


func _on_cooking_progress(ratio: float) -> void:
	_dish_panel.set_progress(ratio, maxf(0.0, session.effective_cooking_time - session.cooking_elapsed))


func _on_order_resolved(order: OrderDefinition, result: OrderEvaluation) -> void:
	var customer: CustomerDefinition = session.day.current_customer
	var dish: RecipeSelection = session.day.dish
	var payout: Dictionary = session.last_payout.duplicate()
	_top.hold_coins = true
	if tavern != null:
		tavern.kitchen.play_result(result.quality)
	if result.is_perfect():
		_order_card.react("happy")
		if tavern != null:
			tavern.react_crowd("happy")
		Audio.play_effect("success")
	elif result.is_suitable():
		_order_card.react("surprised")
		Audio.play_effect("serve")
	else:
		_order_card.react("sad")
		if tavern != null:
			tavern.react_crowd("surprised")
		Audio.play_effect("fail")
	# Даём насладиться вспышкой/паром котла, затем показываем итог.
	await get_tree().create_timer(1.0).timeout
	if session.day.state != GameSessionService.STATE_RESULT or not _in_game:
		_top.hold_coins = false
		return
	Audio.react_crowd(result.quality)
	_result.coin_target = _top.coin_target()
	var extra: Dictionary = {
		"dish_name": ResultExplainer.dish_name(dish, session.content, session.matcher),
		"discovered": session.day.last_recipe_discovered,
		"special_rep": session.day.last_special_rep,
		"unlocked_name": "",
	}
	if session.day.last_unlocked != "":
		var rare: IngredientDefinition = session.content.get_ingredient(session.day.last_unlocked)
		if rare != null:
			extra["unlocked_name"] = Localization.get_text(rare.display_name_key)
	_result.show_result(order, dish, result, customer, payout, session.content, extra)


func _on_order_lost(_order: OrderDefinition) -> void:
	var customer: CustomerDefinition = session.day.current_customer
	_order_card.react("sad")
	Audio.play_event("gasp")
	Audio.play_event("murmur")
	_result.coin_target = _top.coin_target()
	_result.show_lost(customer)


func _on_result_continue() -> void:
	session.continue_after_result()
	_tray.refresh()


func _on_day_finished(summary: Dictionary) -> void:
	_top.refresh(session)
	_summary.show_summary(summary, RewardAd.can_show_rewarded())


func _on_next_day() -> void:
	_summary.visible = false
	session.next_day()


func _on_ad_bonus_pressed() -> void:
	# Награда выдаётся только из колбэка успеха и только после подтверждённого просмотра.
	RewardAd.show_rewarded_ad(_on_ad_rewarded, _on_ad_failed)


func _on_ad_rewarded() -> void:
	var bonus: int = session.grant_ad_bonus()
	if bonus > 0:
		_summary.hide_ad_button()
		_summary.update_total(session.wallet.coins)
		_top.refresh(session)
		_show_toast("+%d" % bonus)


func _on_ad_pack_pressed() -> void:
	RewardAd.show_rewarded_ad(_on_pack_rewarded, _on_pack_failed)


func _on_pack_rewarded() -> void:
	if session.grant_ad_pack():
		_summary.hide_pack_button()
		_tray.refresh()
		_show_toast(Localization.get_text("ui.ad_pack_got"))


func _on_pack_failed(_reason: String) -> void:
	_summary.hide_pack_button()


func _on_stage_changed(stage: int) -> void:
	_show_toast(Localization.fmt("ui.stage_up", [Localization.get_text("stage.%d.name" % stage)]))
	Audio.play_effect("success")
	if tavern != null:
		tavern.apply_upgrades(session)
		tavern.celebrate_stage()


func _on_ad_failed(_reason: String) -> void:
	_summary.hide_ad_button()


func _on_upgrade_purchased(upgrade_id: String) -> void:
	if tavern != null:
		tavern.apply_upgrades(session)
	var upgrade: UpgradeDefinition = session.content.get_upgrade(upgrade_id)
	if upgrade != null:
		_show_toast(Localization.fmt("ui.bought", [Localization.get_text(upgrade.display_name_key)]))
	_tray.refresh()


func _on_stirred() -> void:
	if tavern != null:
		tavern.kitchen.play_stir()
	Audio.play_effect("stir")


# --- Ввод игрока ---------------------------------------------------------------------------------

func _on_item_pressed(kind: String, id: String, card: IngredientCard) -> void:
	if not session.can_edit_dish():
		return
	_tooltip.hide_tip()
	var added: bool = false
	if kind == "base":
		added = session.select_base(id)
	elif kind == "main":
		added = session.select_main(id)
	else:
		added = session.toggle_herb(id)
	Audio.play_effect("ingredient_select")
	if added:
		_fly_ingredient(card)
		if kind != "herb":
			_tray.auto_advance(kind)


func _on_cook_pressed() -> void:
	if session.start_cooking():
		Audio.play_effect("lid")


func _on_stir_pressed() -> void:
	session.stir()


func _on_tip_requested(data: Dictionary, card: IngredientCard, from_hover: bool) -> void:
	# На ПК подсказка по наведению; на касаниях — по нажатию на «i» (from_hover=false).
	if from_hover and DisplayServer.is_touchscreen_available():
		return
	_tooltip.show_for(data, card.get_global_rect(), 6.0 if not from_hover else 20.0)


# --- Анимация ингредиента ------------------------------------------------------------------------

## Подсвечивается → подпрыгивает → летит к котлу → падает внутрь → реакция котла.
func _fly_ingredient(card: IngredientCard) -> void:
	var texture: Texture2D = card.icon_texture()
	var target: Vector2 = tavern.cauldron_screen_position() if tavern != null else Vector2(size.x * 0.5, size.y * 0.35)
	var color: Color = card.tip_data.get("color", Color(0.7, 0.5, 0.3))
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = Vector2(72, 72)
	sprite.pivot_offset = sprite.size * 0.5
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly_layer.add_child(sprite)
	var start: Vector2 = card.get_global_rect().get_center() - sprite.size * 0.5
	sprite.global_position = start
	sprite.modulate = Color(1.4, 1.35, 1.1)
	var end: Vector2 = target - sprite.size * 0.5
	var peak: Vector2 = Vector2((start.x + end.x) * 0.5, minf(start.y, end.y) - 70.0)
	var tween := create_tween()
	# 1. Подсветка и подпрыгивание над карточкой.
	tween.tween_property(sprite, "scale", Vector2.ONE * 1.25, 0.1)
	tween.parallel().tween_property(sprite, "global_position", start + Vector2(0, -34), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. Полёт к котлу по дуге.
	var arc_start: Vector2 = start + Vector2(0, -34)
	tween.tween_method(_fly_step.bind(sprite, arc_start, peak, end), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 3. Падение внутрь: уменьшение и исчезновение.
	tween.tween_property(sprite, "global_position", end + Vector2(0, 26), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE * 0.25, 0.16)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.16)
	tween.tween_callback(func() -> void:
		sprite.queue_free()
		if tavern != null:
			tavern.kitchen.on_ingredient_landed(color)
		Audio.play_effect("ingredient_drop")
		Audio.play_effect("splash"))


func _fly_step(t: float, sprite: TextureRect, from_pos: Vector2, peak: Vector2, to_pos: Vector2) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.global_position = from_pos.lerp(peak, t).lerp(peak.lerp(to_pos, t), t)
	sprite.rotation = t * TAU * 0.75
	sprite.scale = Vector2.ONE * lerpf(1.25, 0.8, t)


# --- Окна и подсказки -----------------------------------------------------------------------------------

## Закрывает все окна и обучение (при возврате в главное меню).
func _close_all_overlays() -> void:
	_active_modal = null
	for panel in [_shop, _settings, _book, _goals, _result, _summary, _tutorial]:
		if panel != null:
			panel.visible = false
	_tooltip.hide_tip()


## Мягкая тёмная виньетка по краям кадра: фокусирует взгляд на котле.
func _make_vignette() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0.02, 0.01, 0.0, 0.0), Color(0.02, 0.01, 0.0, 0.5)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


## Единый механизм модальных окон: одновременно открыто не более одного.
func _open_modal(modal: Control) -> void:
	if _active_modal == modal and modal.visible:
		return
	_dismiss_active_modal()
	_active_modal = modal
	session.paused = true


func _dismiss_active_modal() -> void:
	if _active_modal == null:
		return
	var previous: Control = _active_modal
	if previous == _shop:
		_shop.close_shop()
	elif previous == _settings:
		_settings.close_settings()
	elif previous == _book:
		_book.close_book()
	elif previous == _goals:
		_goals.close_book()
	_active_modal = null


func _open_shop() -> void:
	_open_modal(_shop)
	_shop.open_shop()


func _open_settings(in_game: bool) -> void:
	_open_modal(_settings)
	_settings.open_settings(in_game)


func _open_goals() -> void:
	_open_modal(_goals)
	_goals.open_book("goals")


func _on_goal_completed(goal: DailyGoalDefinition) -> void:
	Audio.play_effect("coin")
	_show_toast(Localization.fmt("ui.goal_done", [Localization.get_text(goal.text_key), goal.reward_coins]))


func _on_achievement_unlocked(achievement: AchievementDefinition) -> void:
	Audio.play_effect("buy")
	_show_toast(Localization.fmt("ui.ach_unlocked", [Localization.get_text(achievement.name_key), achievement.reward_coins]))


## Обучение при первом запуске: пять коротких подсказок с подсветкой нужной части экрана.
func _start_tutorial() -> void:
	session.paused = true
	var steps: Array[Dictionary] = [
		{"text": Localization.get_text("tutorial.1"), "target": _order_card},
		{"text": Localization.get_text("tutorial.2"), "target": _tray},
		{"text": Localization.get_text("tutorial.3"), "target": _dish_panel},
		{"text": Localization.get_text("tutorial.4"), "target": _top},
		{"text": Localization.get_text("tutorial.5"), "target": _top},
	]
	_tutorial.start(steps)


func _on_tutorial_finished() -> void:
	TavernSave.save_data.tutorial_seen = true
	TavernSave.save()
	if _in_game and _active_modal == null:
		session.paused = false


func _open_book() -> void:
	_open_modal(_book)
	_book.open_book()


func _on_overlay_closed() -> void:
	_active_modal = null
	if _in_game:
		session.paused = false
	_top.refresh(session)
	_tray.refresh()


func _show_toast(text: String) -> void:
	_toast_queue.append(text)
	if not _toast_busy:
		_pump_toast()


func _pump_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	_toast_label.text = _toast_queue.pop_front()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate = Color(1, 1, 1, 0)
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_pump_toast)


func _process(_delta: float) -> void:
	if not _in_game or session.day.current_order == null:
		return
	if session.day.state == GameSessionService.STATE_WAITING_FOR_ORDER:
		var relaxed: bool = TavernSave.save_data.relaxed_mode
		var ratio: float = session.day.patience_seconds / maxf(1.0, session.day.patience_max)
		_order_card.update_patience(ratio, relaxed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _active_modal != null:
			_dismiss_active_modal()
		elif _in_game and not _result.visible and not _summary.visible:
			_open_settings(true)
