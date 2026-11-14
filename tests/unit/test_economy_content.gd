extends RefCounted
## Тесты экономики и согласованности контента.


func run(t: TestRunner) -> void:
	var content := GameContent.new()
	var economy := EconomyService.new()
	var order: OrderDefinition = content.get_order("order_chill")

	var perfect: Dictionary = economy.calculate_reward(order, OrderEvaluation.Quality.PERFECT)
	t.equal(int(perfect["total"]), order.reward_coins + order.tip_coins, "награда идеального")
	var suitable: Dictionary = economy.calculate_reward(order, OrderEvaluation.Quality.SUITABLE)
	t.equal(int(suitable["total"]), order.reward_coins, "награда подходящего")
	var wrong: Dictionary = economy.calculate_reward(order, OrderEvaluation.Quality.WRONG, 0.2, 3)
	t.equal(int(wrong["total"]), 0, "за неверное — 0 даже с бонусами")
	var bonus: Dictionary = economy.calculate_reward(order, OrderEvaluation.Quality.PERFECT, 0.2, 0)
	t.check(int(bonus["total"]) > int(perfect["total"]), "бонус стойки увеличивает награду")
	var streak_cap: Dictionary = economy.calculate_reward(order, OrderEvaluation.Quality.PERFECT, 0.0, 99)
	t.equal(int(streak_cap["streak_bonus"]), int(round(float(order.reward_coins + order.tip_coins) * 0.5)), "серия ограничена +50%")
	t.equal(economy.orders_for_day(1), 3, "в первый день 3 заказа")
	t.check(economy.orders_for_day(30) <= 5, "заказов в день не больше 5")

	# Контент: ссылки не битые.
	for order_def in content.orders:
		t.check(content.get_customer(order_def.customer_id) != null, "гость есть: " + order_def.id)
		t.check(content.get_base(order_def.required_base_id) != null, "основа есть: " + order_def.id)
		for main_id in order_def.required_main_ids:
			t.check(content.get_ingredient(str(main_id)) != null, "продукт есть: " + order_def.id)
		t.check(Localization.get_text(order_def.text_key) != order_def.text_key, "есть текст заказа: " + order_def.id)
	for upgrade in content.upgrades:
		t.check(Localization.get_text(upgrade.display_name_key) != upgrade.display_name_key, "есть название улучшения: " + upgrade.id)
		t.check(upgrade.cost_coins > 0, "у улучшения есть цена: " + upgrade.id)
	t.equal(content.upgrades.size(), 8, "восемь улучшений")
	for goal in content.goals:
		t.check(Localization.get_text(goal.text_key) != goal.text_key, "есть текст цели: " + goal.id)
		t.check(goal.target > 0 and goal.reward_coins > 0, "цель корректна: " + goal.id)
	for achievement in content.achievements:
		t.check(Localization.get_text(achievement.name_key) != achievement.name_key, "есть название достижения: " + achievement.id)
		t.check(Localization.get_text(achievement.desc_key) != achievement.desc_key, "есть описание достижения: " + achievement.id)
	for customer in content.customers:
		t.check(Localization.get_text(customer.bio_key) != customer.bio_key, "есть история гостя: " + customer.id)
	for ingredient in content.ingredients:
		t.check(ResourceLoader.exists(ingredient.icon_path()) or FileAccess.file_exists(ingredient.icon_path()), "есть иконка: " + ingredient.id)
	for customer in content.customers:
		t.check(FileAccess.file_exists(customer.portrait_path("calm")), "есть портрет: " + customer.id)
