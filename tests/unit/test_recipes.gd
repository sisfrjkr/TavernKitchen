extends RefCounted
## Тесты рецептов: сопоставление блюд, приоритет специфичных рецептов, экономика бонусов, сохранение.


func _dish(base: String, main: String, herb1: String, herb2: String = "") -> RecipeSelection:
	var dish := RecipeSelection.new()
	dish.base_id = base
	dish.main_ingredient_id = main
	dish.primary_herb_id = herb1
	dish.optional_herb_id = herb2
	return dish


func run(t: TestRunner) -> void:
	var content := GameContent.new()
	var matcher := RecipeMatcher.new()
	t.equal(content.recipes.size(), 17, "в игре 17 рецептов")

	t.equal(matcher.match_dish(_dish("base_stew", "main_chicken", "herb_warm"), content).id, "home_chicken", "обычный рецепт: курица по-домашнему")
	t.equal(matcher.match_dish(_dish("base_stew", "main_chicken", "herb_warm", "herb_boost"), content).id, "fire_rooster", "две травы — редкий рецепт приоритетнее")
	t.equal(matcher.match_dish(_dish("base_stew", "main_chicken", "herb_boost", "herb_warm"), content).id, "fire_rooster", "порядок трав не важен")
	t.equal(matcher.match_dish(_dish("base_stew", "main_chicken", "herb_fire", "herb_warm"), content).id, "home_chicken", "две согревающие травы — не редкий рецепт")
	t.equal(matcher.match_dish(_dish("base_stew", "main_mushroom", "herb_moon", "herb_fire"), content).id, "moon_roast", "секретное лунное жаркое")
	t.equal(matcher.match_dish(_dish("base_broth", "main_truffle", "herb_star"), content).id, "truffle_broth", "секретный трюфельный бульон")
	t.check(matcher.match_dish(_dish("base_broth", "main_chicken", "herb_warm"), content) == null, "случайное сочетание — не рецепт")
	t.check(matcher.match_dish(_dish("base_stew", "main_chicken", ""), content) == null, "без травы рецепта нет")
	t.check(matcher.match_dish(_dish("", "main_chicken", "herb_warm"), content) == null, "без основы рецепта нет")

	# Каждый рецепт достижим: существуют ингредиенты нужных свойств.
	for recipe in content.recipes:
		t.check(content.get_base(recipe.base_id) != null, "основа рецепта есть: " + recipe.id)
		t.check(content.get_ingredient(recipe.main_id) != null, "продукт рецепта есть: " + recipe.id)
		for herb_id in recipe.herb_ids:
			t.check(content.get_ingredient(str(herb_id)) != null, "трава рецепта есть: " + recipe.id)
		for property_key in recipe.herb_props:
			var found: bool = false
			for herb in content.herbs():
				if herb.has_property(str(property_key)):
					found = true
			t.check(found, "есть трава со свойством %s для %s" % [property_key, recipe.id])
		for key in [recipe.name_key, recipe.desc_key, recipe.hint_key]:
			t.check(Localization.get_text(key) != key, "есть текст: " + key)

	# Экономика бонусов.
	var economy := EconomyService.new()
	var order: OrderDefinition = content.get_order("order_chill")
	var plain: Dictionary = economy.calculate_reward(order, OrderEvaluation.Quality.PERFECT)
	var rich: Dictionary = economy.calculate_reward(order, OrderEvaluation.Quality.PERFECT, 0.0, 0, {"recipe_pct": 0.2, "daily_pct": 0.25, "taste": 4, "discovery": 15})
	t.check(int(rich["total"]) > int(plain["total"]) + 19, "бонусы рецепта, дня, вкуса и открытия складываются")
	var wrong: Dictionary = economy.calculate_reward(order, OrderEvaluation.Quality.WRONG, 0.2, 3, {"recipe_pct": 0.2, "daily_pct": 0.25, "taste": 4, "discovery": 15})
	t.equal(int(wrong["total"]), 15, "за неверное блюдо — только открытие рецепта")
	t.equal(int(wrong["taste"]), 0, "вкус за неверное блюдо не платится")

	# Блюдо дня существует и меняется.
	var seen: Dictionary = {}
	for day in range(1, 12):
		seen[content.daily_recipe_id(day)] = true
		t.check(content.get_recipe(content.daily_recipe_id(day)) != null, "блюдо дня %d существует" % day)
	t.check(seen.size() >= 3, "блюдо дня разнообразно")

	# Сохранение v4 и миграция v3.
	var v3 := SaveData.new()
	v3.from_dictionary({"version": 3, "coins": 50, "day_number": 4})
	t.equal(v3.version, SaveData.CURRENT_VERSION, "v3 → v4")
	t.equal(v3.discovered_recipes.size(), 0, "у старого сохранения нет рецептов")
	t.equal(v3.coins, 50, "монеты старого сохранения целы")
	var junk := SaveData.new()
	junk.from_dictionary({"version": 4, "discovered_recipes": {"a": {"count": "x", "best": 99}, "b": 5, "c": {"count": 3, "best": 0}}, "guest_visits": {"customer_elf": -4, "customer_dwarf": 2}, "unlocked_rare": "строка"})
	t.equal(junk.discovered_recipes.size(), 2, "мусорные записи рецептов отброшены")
	t.equal(int(junk.discovered_recipes["c"]["best"]), 0, "корректная запись сохранена")
	t.equal(int(junk.discovered_recipes["a"]["best"]), 2, "лучшее качество ограничено 0..2")
	t.equal(int(junk.guest_visits["customer_elf"]), 0, "отрицательные визиты обнулены")
	t.equal(junk.unlocked_rare.size(), 0, "не-массив редких ингредиентов игнорируется")
	var round_trip := SaveData.new()
	round_trip.discovered_recipes = {"home_chicken": {"count": 3, "best": 0}}
	round_trip.guest_visits = {"customer_hunter": 4}
	round_trip.unlocked_rare.append("main_truffle")
	var copy := SaveData.new()
	copy.from_dictionary(round_trip.to_dictionary())
	t.equal(int(copy.discovered_recipes["home_chicken"]["count"]), 3, "рецепты переживают сохранение")
	t.equal(int(copy.guest_visits["customer_hunter"]), 4, "визиты переживают сохранение")
	t.check(copy.unlocked_rare.has("main_truffle"), "редкие ингредиенты переживают сохранение")
