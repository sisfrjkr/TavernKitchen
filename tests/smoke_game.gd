extends SceneTree
## Дымовой тест настоящей игры: запускает Main.tscn и проигрывает несколько дней через реальный интерфейс —
## выбор карточек (с анимацией полёта), готовка, результат, потеря заказа, итоги дня, магазин, книги, настройки.
## Любая ошибка скрипта в консоли печатается движком вместе со строкой — пришлите её.
##
## Запуск (с окном, чтобы видеть игру):  godot --path . -s tests/smoke_game.gd
## Без окна:                              godot --headless --path . -s tests/smoke_game.gd
## Тест использует ОТДЕЛЬНОЕ сохранение (user://smoke_test/), ваш прогресс не затрагивается.

const DAYS: int = 4

var _screen: Node
var _session: GameSessionService


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _log(text: String) -> void:
	print("[smoke] ", text)


func _run() -> void:
	var save: SaveService = root.get_node("TavernSave")
	save.save_path = "user://smoke_test/save.cfg"
	save.save_data = SaveData.new()
	save.save_data.tutorial_seen = true
	_session = root.get_node("GameSession")
	var packed: PackedScene = load("res://scenes/main/Main.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await _frames(6)
	_screen = scene.find_child("GameScreen", true, false)
	if _screen == null:
		printerr("[smoke] FAIL: GameScreen не найден")
		quit(1)
		return
	_log("главная сцена загружена; моделей не найдено: %d; звуков не найдено: %d" % [Props.missing.size(), root.get_node("Audio").missing.size()])

	# Главное меню → окна из меню не должны перекрываться кнопками меню.
	_screen._open_settings(false)
	await _frames(3)
	_screen._dismiss_active_modal()
	await _frames(3)
	_log("меню и настройки: ок")

	_screen._menu.new_game_requested.emit()
	await _frames(6)
	for day in DAYS:
		_log("=== день %d ===" % (day + 1))
		var guard: int = 0
		var first_order: bool = true
		while _session.day.state != GameSessionService.STATE_DAY_SUMMARY and guard < 40:
			guard += 1
			if day == 1 and first_order:
				await _lose_order()
			else:
				await _play_order(guard % 4 == 0)
			first_order = false
		if _session.day.state != GameSessionService.STATE_DAY_SUMMARY:
			printerr("[smoke] FAIL: день %d не завершился за %d шагов" % [day + 1, guard])
			quit(1)
			return
		await _frames(4)
		_log("итоги дня %d: монет %d, слава %d, целей %d/%d" % [day + 1, _session.wallet.coins, _session.reputation, _count_goals(), _session.day.goals.size()])
		await _exercise_windows()
		_buy_something()
		await _frames(3)
		_screen._summary.next_day_pressed.emit()
		await _frames(6)
	_log("OK: сыграно %d дней без остановки; монет %d, рецептов %d, достижений %d, этап таверны %d" % [DAYS, _session.wallet.coins, _session.known_recipe_count(), _session.save_service.save_data.achievements.size(), _session.tavern_stage])
	_screen._return_to_menu()
	await _frames(4)
	_screen._open_settings(false)
	await _frames(3)
	_screen._dismiss_active_modal()
	_log("возврат в меню: ок")
	quit(0)


func _count_goals() -> int:
	var done: int = 0
	for goal in _session.day.goals:
		if bool(goal["done"]):
			done += 1
	return done


## Играет один заказ как игрок: нажимает карточки, «Готовить», ждёт панель результата, жмёт «Дальше».
func _play_order(make_mistake: bool) -> void:
	if _session.day.state == GameSessionService.STATE_RESULT:
		await _finish_result()
		return
	if _session.day.state != GameSessionService.STATE_WAITING_FOR_ORDER or _session.day.current_order == null:
		await _frames(2)
		return
	var order: OrderDefinition = _session.day.current_order
	_press("base", "base_stew" if make_mistake and order.required_base_id != "base_stew" else order.required_base_id)
	var main_id: String = str(order.required_main_ids[0])
	if make_mistake:
		main_id = "main_veg" if main_id != "main_veg" else "main_root"
	_press("main", main_id)
	var herbs: Array[String] = _herbs_for(order)
	for herb_id in herbs:
		_press("herb", herb_id)
	await _frames(2)
	_screen._on_cook_pressed()
	await _frames(2)
	_screen._on_stir_pressed()
	_session.advance(_session.effective_cooking_time + 0.2)
	await _wait(1.4)
	await _finish_result()


func _press(kind: String, id: String) -> void:
	_screen._tray.show_tab(kind)
	var card: IngredientCard = _screen._tray.card_for(id)
	if card == null:
		# Нет карточки (закрыт ингредиент) — выбираем напрямую через логику.
		if kind == "base":
			_session.select_base(id)
		elif kind == "main":
			_session.select_main(id)
		else:
			_session.toggle_herb(id)
		return
	_screen._on_item_pressed(kind, id, card)


func _herbs_for(order: OrderDefinition) -> Array[String]:
	var result: Array[String] = []
	var wanted: Array[String] = []
	if order.required_herb_id != "":
		result.append(order.required_herb_id)
	elif order.required_herb_property != "":
		wanted.append(order.required_herb_property)
	if order.optional_herb_property != "":
		wanted.append(order.optional_herb_property)
	for property_key in wanted:
		for herb in _session.content.herbs():
			if herb.has_property(property_key) and _session.is_ingredient_available(herb.id) and not result.has(herb.id):
				result.append(herb.id)
				break
	return result


func _finish_result() -> void:
	if _screen._result.visible:
		_screen._result._on_continue()
		await _wait(1.2)
	elif _session.day.state == GameSessionService.STATE_RESULT:
		_session.continue_after_result()
		await _frames(3)


## Потеря заказа: терпение заканчивается, показывается панель «Гость ушёл».
func _lose_order() -> void:
	_session.advance(100000.0)
	await _wait(0.4)
	_log("потеря заказа: состояние=%d" % _session.day.state)
	await _finish_result()


## Открывает и закрывает все окна по очереди (проверка менеджера окон и перекрытий).
func _exercise_windows() -> void:
	_screen._open_shop()
	await _frames(3)
	_screen._open_book()
	await _frames(3)
	_screen._open_goals()
	await _frames(3)
	_screen._open_settings(true)
	await _frames(3)
	_screen._dismiss_active_modal()
	await _frames(3)
	if _screen._active_modal != null:
		printerr("[smoke] FAIL: после закрытия остался активный диалог")
	_log("окна: магазин → книга → цели → настройки → закрытие: ок")


func _buy_something() -> void:
	for upgrade in _session.content.upgrades:
		if _session.can_buy_upgrade(upgrade.id):
			_session.buy_upgrade(upgrade.id)
			_log("куплено: " + upgrade.id)
			return
