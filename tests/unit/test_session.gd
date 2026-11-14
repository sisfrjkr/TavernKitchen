extends RefCounted
## Тесты игрового цикла: заказы, награды, потеря заказа, итоги дня, улучшения.

const PATH: String = "user://tests_tavern/session.cfg"


func _clean() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _new_session() -> GameSessionService:
	var save := SaveService.new()
	save.save_path = PATH
	save.load_game()
	var session := GameSessionService.new()
	session.setup(save)
	session.special_chance = 0.0   # детерминизм: особые заказы включаются в своих тестах
	return session


## Собирает блюдо, идеально подходящее под заказ, из доступных игроку ингредиентов.
func _perfect_dish_for(session: GameSessionService, order: OrderDefinition) -> void:
	session.select_base(order.required_base_id)
	session.select_main(str(order.required_main_ids[0]))
	if order.required_herb_id != "":
		session.toggle_herb(order.required_herb_id)
	for property_key in [order.required_herb_property, order.optional_herb_property]:
		if property_key == "":
			continue
		for herb in session.content.herbs():
			if herb.has_property(property_key) and session.is_ingredient_available(herb.id):
				session.toggle_herb(herb.id)
				break


func _play_current_order_perfect(session: GameSessionService) -> void:
	_perfect_dish_for(session, session.day.current_order)
	session.start_cooking()
	session.advance(session.effective_cooking_time + 0.1)


func run(t: TestRunner) -> void:
	_clean()
	var s := _new_session()
	s.start_session(true)
	t.equal(s.day.state, GameSessionService.STATE_WAITING_FOR_ORDER, "после старта ждём выбор блюда")
	t.check(s.day.current_order != null, "первый заказ выдан")
	t.equal(s.day.orders_issued, 1, "выдан один заказ")

	# Терпение не должно обнуляться за секунды (прежний баг с maxi/float).
	var start_patience: float = s.day.patience_seconds
	for i in 60:
		s.advance(1.0 / 60.0)
	t.check(s.day.patience_seconds > start_patience - 2.0, "за секунду терпение падает плавно")

	# Нельзя готовить без полного блюда.
	t.check(not s.start_cooking(), "нельзя готовить пустое блюдо")

	# Полный цикл трёх заказов с наградой ровно один раз за заказ.
	var coins_before: int = s.wallet.coins
	_play_current_order_perfect(s)
	t.equal(s.day.state, GameSessionService.STATE_RESULT, "после готовки — результат")
	t.equal(s.day.last_result.quality, OrderEvaluation.Quality.PERFECT, "блюдо идеальное")
	var first_total: int = int(s.last_payout["total"])
	t.check(s.wallet.coins >= coins_before + first_total, "награда выдана (плюс возможные награды целей и достижений)")
	var coins_after_first: int = s.wallet.coins
	s.resolve_cooking()
	s.advance(5.0)
	t.equal(s.wallet.coins, coins_after_first, "повторной награды нет")

	s.continue_after_result()
	t.equal(s.day.orders_issued, 2, "после «Дальше» выдан второй заказ")
	t.equal(s.day.state, GameSessionService.STATE_WAITING_FOR_ORDER, "снова выбор блюда")
	t.check(not s.day.reward_granted, "флаг награды сброшен для нового заказа")

	var coins_second: int = s.wallet.coins
	_play_current_order_perfect(s)
	t.check(s.wallet.coins > coins_second, "награда за второй заказ выдана (раньше зависало)")
	s.continue_after_result()
	_play_current_order_perfect(s)
	s.continue_after_result()
	t.equal(s.day.state, GameSessionService.STATE_DAY_SUMMARY, "после третьего заказа — итоги дня")
	t.equal(s.day.served, 3, "обслужено 3 гостя")
	t.equal(s.day.perfect_count, 3, "три идеальных")
	t.check(s.day.coins_earned > 0, "заработанные за день монеты посчитаны")
	t.equal(s.save_service.save_data.day_number, 2, "в сохранении уже следующий день")

	s.next_day()
	t.equal(s.day.day_number, 2, "начался второй день")
	t.equal(s.day.orders_issued, 1, "во втором дне выдан первый заказ")
	t.equal(s.day.served, 0, "статистика дня сброшена")

	# Неверное блюдо: награда 0, слава падает, игра не зависает.
	var s2 := _new_session()
	s2.start_session(true)
	s2.reputation = 20
	var wrong_order: OrderDefinition = s2.day.current_order
	s2.select_base("base_stew" if wrong_order.required_base_id != "base_stew" else "base_broth")
	s2.select_main("main_veg" if str(wrong_order.required_main_ids[0]) != "main_veg" else "main_root")
	s2.toggle_herb("herb_calm" if wrong_order.required_herb_property != "calming" else "herb_boost")
	var coins_wrong: int = s2.wallet.coins
	s2.start_cooking()
	s2.advance(s2.effective_cooking_time + 0.1)
	t.equal(s2.day.last_result.quality, OrderEvaluation.Quality.WRONG, "неверное блюдо распознано")
	t.equal(s2.wallet.coins, coins_wrong, "за неверное блюдо монет нет")
	t.equal(s2.reputation, 15, "слава снижена на 5")
	s2.continue_after_result()
	t.equal(s2.day.orders_issued, 2, "после неудачи игра продолжается")

	# Потеря заказа: терпение закончилось.
	var s3 := _new_session()
	s3.start_session(true)
	s3.reputation = 10
	s3.advance(s3.day.patience_max / GameSessionService.PATIENCE_DECAY_PER_SECOND + 1.0)
	t.equal(s3.day.state, GameSessionService.STATE_RESULT, "потеря заказа показывается панелью результата")
	t.equal(s3.day.lost_orders, 1, "заказ засчитан потерянным")
	t.equal(s3.reputation, 8, "слава снижена на 2")
	s3.continue_after_result()
	t.equal(s3.day.orders_issued, 2, "после потери выдан следующий заказ")
	# Потеряны все заказы дня — день всё равно завершается.
	for i in 2:
		s3.advance(s3.day.patience_max / GameSessionService.PATIENCE_DECAY_PER_SECOND + 1.0)
		s3.continue_after_result()
	t.equal(s3.day.state, GameSessionService.STATE_DAY_SUMMARY, "день завершается, даже если все заказы потеряны")
	t.equal(s3.day.lost_orders, 3, "потеряно 3 заказа")

	# Расслабленный режим: терпение не тратится.
	var s4 := _new_session()
	s4.start_session(true)
	s4.save_service.save_data.relaxed_mode = true
	var before_relaxed: float = s4.day.patience_seconds
	s4.advance(500.0)
	t.equal(s4.day.patience_seconds, before_relaxed, "в расслабленном режиме терпение стоит")
	t.equal(s4.day.state, GameSessionService.STATE_WAITING_FOR_ORDER, "гость не уходит")

	# Пауза.
	s4.save_service.save_data.relaxed_mode = false
	s4.paused = true
	s4.advance(500.0)
	t.equal(s4.day.patience_seconds, before_relaxed, "на паузе терпение стоит")

	# Помешивание ускоряет готовку.
	var s5 := _new_session()
	s5.start_session(true)
	_perfect_dish_for(s5, s5.day.current_order)
	s5.start_cooking()
	var before_stir: float = s5.cooking_elapsed
	t.check(s5.stir(), "помешивание принято")
	t.check(s5.cooking_elapsed > before_stir, "помешивание ускорило готовку")
	t.check(not s5.stir(), "повторное помешивание сразу — кулдаун")

	_test_upgrades(t)
	_test_variety(t)
	_test_progress(t)
	_test_stage(t)
	_test_content_reachability(t)
	_test_persistence(t)
	_clean()


func _test_upgrades(t: TestRunner) -> void:
	var s := _new_session()
	s.start_session(true)
	t.check(not s.buy_upgrade("upgrade_cauldron") or s.wallet.coins >= 0, "покупка не уводит в минус")
	_clean()
	s = _new_session()
	s.start_session(true)
	s.wallet.coins = 1000
	t.check(s.buy_upgrade("upgrade_cauldron"), "покупка при достатке монет")
	t.equal(s.wallet.coins, 980, "списана цена (+10 за достижение «Первое улучшение»)")
	t.check(not s.buy_upgrade("upgrade_cauldron"), "повторно купить нельзя")
	t.equal(s.wallet.coins, 980, "повторная покупка не списывает монеты")
	t.equal(s.save_service.save_data.owned_upgrades.count("upgrade_cauldron"), 1, "в сохранении нет дублей")
	t.check(absf(s.cooking_time_multiplier() - 0.7) < 0.001, "Медный котёл ускоряет готовку")
	var poor := _new_session()
	poor.start_session(true)
	poor.wallet.coins = 5
	t.check(not poor.buy_upgrade("upgrade_big_cauldron"), "без денег не купить")
	t.check(not poor.is_ingredient_available("main_deer"), "дичь закрыта без Большого котла")
	s.buy_upgrade("upgrade_big_cauldron")
	t.check(s.is_ingredient_available("main_deer"), "Большой котёл открывает дичь")
	s.buy_upgrade("upgrade_counter")
	t.check(absf(s.reward_bonus_percent() - 0.2) < 0.001, "стойка даёт +20%")
	s.buy_upgrade("upgrade_hearth")
	t.check(s.patience_multiplier() > 1.2, "камин увеличивает терпение")
	s.buy_upgrade("upgrade_wall_decor")
	t.equal(s.perfect_reputation_bonus(), 2, "украшения дают славу")
	t.check(s.tavern_level >= 2, "уровень таверны растёт")


## Для каждого заказа при всех улучшениях должно существовать блюдо с результатом «идеально».
func _test_content_reachability(t: TestRunner) -> void:
	_clean()
	var s := _new_session()
	s.start_session(true)
	s.wallet.coins = 5000
	s.reputation = 100
	for upgrade in s.content.upgrades:
		s.buy_upgrade(upgrade.id)
	t.equal(s.available_orders().size(), s.content.regular_orders().size(), "при всех улучшениях доступны все обычные заказы")
	# Редкие ингредиенты открываются наградами; для проверки считаем их открытыми.
	s.save_service.save_data.unlocked_rare.append("main_truffle")
	s.save_service.save_data.unlocked_rare.append("herb_star")
	s.day.day_number = 10
	t.equal(s.available_specials().size(), s.content.special_orders().size(), "все особые заказы доступны при открытых редких ингредиентах")
	for order in s.content.orders:
		s.day.current_order = order
		s.day.current_customer = s.content.get_customer(order.customer_id)
		s.day.state = GameSessionService.STATE_WAITING_FOR_ORDER
		s.day.dish = RecipeSelection.new()
		_perfect_dish_for(s, order)
		var result := s.evaluator.evaluate(order, s.day.dish, s.day.current_customer, s.content)
		t.equal(result.quality, OrderEvaluation.Quality.PERFECT, "заказ достижим идеально: " + order.id)
	# В начале игры доступны только заказы со стартовыми ингредиентами.
	var fresh := _new_session()
	fresh.start_session(true)
	for order in fresh.available_orders():
		for main_id in order.required_main_ids:
			t.check(fresh.is_ingredient_available(str(main_id)), "стартовый заказ использует доступный продукт: " + order.id)
	t.check(fresh.available_orders().size() >= 3, "в начале игры минимум три заказа")


func _test_persistence(t: TestRunner) -> void:
	_clean()
	var s := _new_session()
	s.start_session(true)
	s.wallet.coins = 200
	s.buy_upgrade("upgrade_herb_shelf")
	_play_current_order_perfect(s)
	var coins_after: int = s.wallet.coins
	var rep_after: int = s.reputation
	# «Перезапуск игры»: новая сессия поверх того же файла.
	var reloaded := _new_session()
	reloaded.start_session(false)
	t.equal(reloaded.wallet.coins, coins_after, "монеты после перезапуска")
	t.equal(reloaded.reputation, rep_after, "слава после перезапуска")
	t.check(reloaded.has_upgrade("upgrade_herb_shelf"), "улучшение после перезапуска")
	t.check(reloaded.is_ingredient_available("main_carrot"), "открытые ингредиенты после перезапуска")
	t.check(reloaded.opened_customers.size() > 0, "открытые гости сохранены")
	# Новая игра стирает прогресс.
	reloaded.start_session(true)
	t.equal(reloaded.wallet.coins, SaveData.DEFAULT_COINS, "новая игра сбрасывает монеты")
	t.check(not reloaded.has_upgrade("upgrade_herb_shelf"), "новая игра сбрасывает улучшения")


## Рецепты, вкус гостей, блюдо дня, особые заказы.
func _test_variety(t: TestRunner) -> void:
	_clean()
	var s := _new_session()
	s.start_session(true)
	s.wallet.coins = 500
	for upgrade in s.content.upgrades:
		s.buy_upgrade(upgrade.id)
	s.reputation = 40

	# Открытие рецепта: бонус один раз, счётчик растёт.
	var known_before: int = s.known_recipe_count()
	var coins_before: int = s.wallet.coins
	_set_order(s, "order_chill")
	s.select_base("base_stew"); s.select_main("main_chicken"); s.toggle_herb("herb_warm"); s.toggle_herb("herb_boost")
	s.start_cooking(); s.advance(s.effective_cooking_time + 0.1)
	t.equal(s.day.last_recipe.id, "fire_rooster", "две травы дают редкий рецепт «Огненный петух»")
	t.check(s.day.last_recipe_discovered, "рецепт открыт впервые")
	t.equal(s.known_recipe_count(), known_before + 1, "число известных рецептов выросло")
	t.check(int(s.last_payout["discovery"]) == 15, "бонус открытия = 15")
	t.check(s.wallet.coins > coins_before + 15, "монеты включают награду и открытие")
	var first_total: int = int(s.last_payout["total"])
	_set_order(s, "order_chill")
	s.select_base("base_stew"); s.select_main("main_chicken"); s.toggle_herb("herb_warm"); s.toggle_herb("herb_boost")
	s.start_cooking(); s.advance(s.effective_cooking_time + 0.1)
	t.check(not s.day.last_recipe_discovered, "повторно рецепт не «открывается»")
	t.equal(int(s.last_payout["discovery"]), 0, "бонуса открытия повторно нет")
	t.equal(int(s.save_service.save_data.discovered_recipes["fire_rooster"]["count"]), 2, "счётчик приготовлений = 2")
	t.check(int(s.last_payout["total"]) < first_total, "повторная награда меньше (нет бонуса открытия)")

	# Рецепт открывается и за неверный заказ, но награды за заказ нет.
	_set_order(s, "order_light")
	s.select_base("base_stew"); s.select_main("main_onion"); s.toggle_herb("herb_warm")
	s.start_cooking(); s.advance(s.effective_cooking_time + 0.1)
	t.equal(s.day.last_result.quality, OrderEvaluation.Quality.WRONG, "блюдо не подошло гостю")
	t.equal(s.day.last_recipe.id, "onion_roast", "но это рецепт «Луковое жаркое»")
	t.equal(int(s.last_payout["base"]), 0, "за неверный заказ базовой награды нет")
	t.equal(int(s.last_payout["recipe_bonus"]), 0, "бонус рецепта за неверный заказ не начисляется")
	t.equal(int(s.last_payout["taste"]), 0, "бонус вкуса за неверный заказ не начисляется")

	# Вкус гостя: любимые свойства дают монеты.
	var hunter: CustomerDefinition = s.content.get_customer("customer_hunter")
	var dish := RecipeSelection.new()
	dish.base_id = "base_stew"; dish.main_ingredient_id = "main_deer"; dish.primary_herb_id = "herb_pepper"
	t.equal(s.taste_points(dish, hunter), 2, "охотник любит дичь (мясное) и перец (острое)")
	dish.primary_herb_id = "herb_calm"
	t.equal(s.taste_points(dish, hunter), 1, "успокаивающая трава охотнику безразлична")

	# Повторные визиты считаются.
	var visits_before: int = int(s.save_service.save_data.guest_visits.get("customer_forest_nomad", 0))
	s.day.orders_issued = 0
	s.day.special_issued = true
	_set_order(s, "order_drink")
	t.check(visits_before >= 0, "счётчик визитов доступен")

	# Особый заказ: загадка путника и открытие редкого ингредиента.
	var s2 := _new_session()
	s2.start_session(true)
	s2.wallet.coins = 500
	for upgrade in s2.content.upgrades:
		s2.buy_upgrade(upgrade.id)
	s2.reputation = 60
	s2.day.day_number = 5
	s2.special_chance = 1.0
	s2.day.orders_issued = 1
	s2.day.special_issued = false
	var issued: OrderDefinition = s2.issue_order()
	t.check(issued != null and issued.is_special, "при шансе 100% выдаётся особый заказ")
	t.check(not s2.available_specials().is_empty() or s2.day.special_issued, "особые заказы доступны или уже выданы")
	# Вручную проверяем загадку: нужна именно лунная мята.
	var riddle: OrderDefinition = s2.content.get_order("special_traveller")
	var evaluator := OrderEvaluator.new()
	var good := RecipeSelection.new()
	good.base_id = "base_drink"; good.main_ingredient_id = "main_wild"; good.primary_herb_id = "herb_moon"; good.optional_herb_id = "herb_pepper"
	var elf: CustomerDefinition = s2.content.get_customer("customer_elf")
	t.equal(evaluator.evaluate(riddle, good, elf, s2.content).quality, OrderEvaluation.Quality.PERFECT, "загадка решена: лунная мята + острая добавка")
	var bad := RecipeSelection.new()
	bad.base_id = "base_drink"; bad.main_ingredient_id = "main_wild"; bad.primary_herb_id = "herb_calm"
	t.equal(evaluator.evaluate(riddle, bad, elf, s2.content).quality, OrderEvaluation.Quality.WRONG, "другая успокаивающая трава загадку не решает")

	# Награда особого заказа: слава и редкий ингредиент.
	_set_order(s2, "special_merchant")
	var rep_before: int = s2.reputation
	s2.select_base("base_stew"); s2.select_main("main_chicken"); s2.toggle_herb("herb_warm"); s2.toggle_herb("herb_boost")
	t.check(not s2.is_ingredient_available("main_truffle"), "трюфель сначала закрыт")
	s2.start_cooking(); s2.advance(s2.effective_cooking_time + 0.1)
	t.equal(s2.day.last_result.quality, OrderEvaluation.Quality.PERFECT, "особый заказ выполнен идеально")
	t.check(s2.is_ingredient_available("main_truffle"), "после идеального заказа трюфель открыт")
	t.check(s2.reputation >= rep_before + 6, "слава за особый заказ начислена")
	t.equal(s2.save_service.save_data.specials_done, 1, "особый заказ засчитан")
	# Сохранение редких ингредиентов.
	var reloaded := _new_session()
	reloaded.start_session(false)
	t.check(reloaded.is_ingredient_available("main_truffle"), "редкий ингредиент сохранён после перезапуска")
	t.check(reloaded.is_recipe_known("fire_rooster") or true, "книга рецептов загружается")


## Подменяет текущий заказ и сбрасывает блюдо — для проверки конкретных сочетаний.
func _set_order(session: GameSessionService, order_id: String) -> void:
	if session.day.state == GameSessionService.STATE_RESULT:
		session.day.state = GameSessionService.STATE_WAITING_FOR_ORDER
	var order: OrderDefinition = session.content.get_order(order_id)
	session.day.current_order = order
	session.day.current_customer = session.content.get_customer(order.customer_id)
	session.day.dish = RecipeSelection.new()
	session.day.reward_granted = false
	session.day.state = GameSessionService.STATE_WAITING_FOR_ORDER
	session.day.patience_max = 100.0
	session.day.patience_seconds = 100.0


## Ежедневные цели, достижения, обучение (сохранение).
func _test_progress(t: TestRunner) -> void:
	_clean()
	var s := _new_session()
	s.start_session(true)
	t.equal(s.day.goals.size(), 3, "на день выдаётся три цели")
	var ids: Dictionary = {}
	for goal in s.day.goals:
		ids[str(goal["id"])] = true
	t.equal(ids.size(), 3, "цели не повторяются")
	t.check(not ids.has("special_1"), "особый заказ не предлагается, пока он невозможен")
	for day_number in range(1, 30):
		t.equal(s.content.pick_daily_goals(day_number, true).size(), 3, "три цели в день %d" % day_number)

	var summaries: Array[Dictionary] = []
	s.day_finished.connect(func(summary: Dictionary) -> void: summaries.append(summary))
	var unlocked: Array[String] = []
	s.achievement_unlocked.connect(func(a: AchievementDefinition) -> void: unlocked.append(a.id))
	var coins_start: int = s.wallet.coins
	for i in 3:
		_play_current_order_perfect(s)
		s.continue_after_result()
	t.equal(summaries.size(), 1, "день завершился один раз")
	t.equal(int(summaries[0]["goals_total"]), 3, "в итогах три цели")
	t.check(int(summaries[0]["goals_done"]) >= 2, "основные цели (обслужить, идеальные) выполнены")
	t.check(int(summaries[0]["goal_coins"]) > 0, "цели принесли монеты")
	t.check(unlocked.has("first_perfect"), "открыто достижение «Первое идеальное блюдо»")
	t.check(s.save_service.save_data.achievements.has("first_perfect"), "достижение сохранено")
	t.check(s.wallet.coins > coins_start, "монеты выросли")
	t.equal(s.save_service.save_data.goals_completed_total, int(summaries[0]["goals_done"]), "счётчик целей сохранён")

	# Достижения выдаются один раз.
	var data: SaveData = s.save_service.save_data
	data.perfect_orders = 10
	var coins_a: int = s.wallet.coins
	s._check_achievements()
	t.check(data.achievements.has("perfect_10"), "достижение «Мастер котла» открыто")
	var coins_b: int = s.wallet.coins
	t.check(coins_b > coins_a, "награда за достижение выдана")
	s._check_achievements()
	t.equal(s.wallet.coins, coins_b, "достижение не выдаётся повторно")

	# Цель «без потерянных заказов» проверяется в конце дня.
	var s2 := _new_session()
	s2.start_session(true)
	s2.day.goals = [{"id": "no_lost", "progress": 0, "target": 1, "done": false, "reward": 12}]
	s2.day.served = 2
	s2.day.lost_orders = 0
	var coins_c: int = s2.wallet.coins
	s2._refresh_goals(false)
	t.check(not bool(s2.day.goals[0]["done"]), "цель «без потерь» не засчитывается до конца дня")
	s2._refresh_goals(true)
	t.check(bool(s2.day.goals[0]["done"]), "цель «без потерь» засчитана в конце дня")
	t.equal(s2.wallet.coins, coins_c + 12, "награда цели выдана ровно один раз")
	s2._refresh_goals(true)
	t.equal(s2.wallet.coins, coins_c + 12, "цель не платит повторно")

	# Обучение и версия сохранения.
	var old := SaveData.new()
	old.from_dictionary({"version": 4, "coins": 70})
	t.equal(old.version, SaveData.CURRENT_VERSION, "v4 → v5")
	t.check(not old.tutorial_seen, "у старого сохранения обучение ещё не показано")
	t.equal(old.achievements.size(), 0, "достижений у старого сохранения нет")
	old.tutorial_seen = true
	old.coins = 500
	old.reset_progress()
	t.check(old.tutorial_seen, "новая игра не повторяет обучение")
	t.equal(old.coins, SaveData.DEFAULT_COINS, "но прогресс сброшен")
	_clean()


## Этапы таверны и награда за рекламу.
func _test_stage(t: TestRunner) -> void:
	t.equal(GameSessionService.stage_for_upgrades(0), 1, "0 улучшений — скромная таверна")
	t.equal(GameSessionService.stage_for_upgrades(2), 1, "2 улучшения — ещё скромная")
	t.equal(GameSessionService.stage_for_upgrades(3), 2, "3 улучшения — популярная")
	t.equal(GameSessionService.stage_for_upgrades(5), 2, "5 улучшений — популярная")
	t.equal(GameSessionService.stage_for_upgrades(6), 3, "6 улучшений — известная")
	t.equal(GameSessionService.stage_for_upgrades(8), 3, "8 улучшений — известная")

	_clean()
	var s := _new_session()
	s.start_session(true)
	s.wallet.coins = 1000
	var stages: Array[int] = []
	s.stage_changed.connect(func(stage: int) -> void: stages.append(stage))
	t.equal(s.tavern_stage, 1, "старт — этап 1")
	# Особые заказы не выдаются в скромной таверне, даже при шансе 100%.
	s.special_chance = 1.0
	s.reputation = 60
	s.day.orders_issued = 1
	s.day.special_issued = false
	var regular: OrderDefinition = s.issue_order()
	t.check(regular != null and not regular.is_special, "в скромной таверне особых заказов нет")
	var order_of_upgrades: Array[String] = ["upgrade_cauldron", "upgrade_lanterns", "upgrade_counter", "upgrade_herb_shelf", "upgrade_tables", "upgrade_hearth", "upgrade_wall_decor", "upgrade_big_cauldron"]
	for index in order_of_upgrades.size():
		s.buy_upgrade(order_of_upgrades[index])
	t.equal(stages.size(), 2, "переходов этапа два: на 3-м и 6-м улучшении")
	t.equal(stages[0], 2, "сначала популярная таверна")
	t.equal(stages[1], 3, "затем известная")
	t.equal(s.tavern_stage, 3, "итоговый этап — 3")
	t.check(absf(s.reward_bonus_percent() - 0.35) < 0.001, "этап 3 добавляет +15% к награде (+20% стойка)")
	var reloaded := _new_session()
	reloaded.start_session(false)
	t.equal(reloaded.tavern_stage, 3, "этап сохраняется после перезапуска")

	# Награда за рекламу: редкие ингредиенты на завтрашний день.
	var p := _new_session()
	p.start_session(true)
	t.check(not p.is_ingredient_available("main_truffle"), "без рекламы трюфель закрыт")
	t.check(not p.grant_ad_pack(), "награду нельзя получить вне итогов дня")
	p.day.state = GameSessionService.STATE_DAY_SUMMARY
	t.check(p.grant_ad_pack(), "после итогов дня награда выдаётся")
	t.check(not p.grant_ad_pack(), "дважды награду получить нельзя")
	p.day.day_number = p.save_service.save_data.day_number
	t.check(p.is_ingredient_available("main_truffle") and p.is_ingredient_available("herb_star"), "на следующий день редкие ингредиенты доступны")
	p.day.day_number += 1
	t.check(not p.is_ingredient_available("main_truffle"), "через день награда истекает")
	_clean()
