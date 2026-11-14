extends RefCounted
## Тесты оценки блюда.


func _dish(base: String, main: String, herb1: String, herb2: String = "") -> RecipeSelection:
	var dish := RecipeSelection.new()
	dish.base_id = base
	dish.main_ingredient_id = main
	dish.primary_herb_id = herb1
	dish.optional_herb_id = herb2
	return dish


func run(t: TestRunner) -> void:
	var content := GameContent.new()
	var evaluator := OrderEvaluator.new()
	var order: OrderDefinition = content.get_order("order_chill")
	var customer: CustomerDefinition = content.get_customer(order.customer_id)

	var perfect := evaluator.evaluate(order, _dish("base_stew", "main_chicken", "herb_warm", "herb_boost"), customer, content)
	t.equal(perfect.quality, OrderEvaluation.Quality.PERFECT, "идеальное блюдо")
	t.equal(perfect.reward_coins, order.reward_coins + order.tip_coins, "награда идеального блюда включает чаевые")

	var suitable := evaluator.evaluate(order, _dish("base_stew", "main_chicken", "herb_warm"), customer, content)
	t.equal(suitable.quality, OrderEvaluation.Quality.SUITABLE, "без добавки — подходит")
	t.equal(suitable.reward_coins, order.reward_coins, "награда без чаевых")

	var wrong_main := evaluator.evaluate(order, _dish("base_stew", "main_veg", "herb_warm", "herb_boost"), customer, content)
	t.equal(wrong_main.quality, OrderEvaluation.Quality.WRONG, "не тот продукт")
	t.check(wrong_main.failed_conditions.has("main"), "причина: продукт")
	t.equal(wrong_main.reward_coins, 0, "за неверное блюдо награды нет")

	var wrong_base := evaluator.evaluate(order, _dish("base_broth", "main_chicken", "herb_warm"), customer, content)
	t.equal(wrong_base.quality, OrderEvaluation.Quality.WRONG, "не та основа")

	var no_base := evaluator.evaluate(order, _dish("", "main_chicken", "herb_warm"), customer, content)
	t.equal(no_base.quality, OrderEvaluation.Quality.WRONG, "пустая основа не засчитывается")

	# Порядок выбора трав не должен влиять на результат.
	var swapped := evaluator.evaluate(order, _dish("base_stew", "main_chicken", "herb_boost", "herb_warm"), customer, content)
	t.equal(swapped.quality, OrderEvaluation.Quality.PERFECT, "порядок трав не важен")
	t.equal(swapped.used_primary_herb_id, "herb_warm", "основной травой засчитан Огонёк")

	var no_herb := evaluator.evaluate(order, _dish("base_stew", "main_chicken", ""), customer, content)
	t.equal(no_herb.quality, OrderEvaluation.Quality.WRONG, "без травы — неверно")
	t.check(no_herb.failed_conditions.has("herb"), "причина: трава")

	# Заказ без дополнительной травы: добавка не мешает.
	var light: OrderDefinition = content.get_order("order_light")
	var light_customer: CustomerDefinition = content.get_customer(light.customer_id)
	var light_result := evaluator.evaluate(light, _dish("base_broth", "main_veg", "herb_calm"), light_customer, content)
	t.equal(light_result.quality, OrderEvaluation.Quality.PERFECT, "заказ без добавки достижим идеальным")
