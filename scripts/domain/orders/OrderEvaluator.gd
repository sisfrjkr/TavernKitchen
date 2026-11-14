class_name OrderEvaluator
extends RefCounted
## Чистая оценка заказа: не зависит от сцены и UI.
## Игрок выбирает до двух трав без ролей — оценщик сам подбирает лучшее распределение
## «основная / дополнительная», чтобы порядок выбора не влиял на результат.


func evaluate(
	order: OrderDefinition,
	dish: RecipeSelection,
	customer: CustomerDefinition,
	content: GameContent,
) -> OrderEvaluation:
	var best := _evaluate_roles(order, dish, dish.primary_herb_id, dish.optional_herb_id, customer, content)
	if dish.optional_herb_id != "" and dish.primary_herb_id != "":
		var swapped := _evaluate_roles(order, dish, dish.optional_herb_id, dish.primary_herb_id, customer, content)
		if swapped.quality < best.quality:
			best = swapped
	return best


func _evaluate_roles(
	order: OrderDefinition,
	dish: RecipeSelection,
	primary_herb_id: String,
	optional_herb_id: String,
	customer: CustomerDefinition,
	content: GameContent,
) -> OrderEvaluation:
	var result := OrderEvaluation.new()
	result.used_primary_herb_id = primary_herb_id
	result.used_optional_herb_id = optional_herb_id

	result.base_satisfied = order.has_required_base(dish.base_id) and dish.base_id != ""
	if not result.base_satisfied:
		result.failed_conditions.append("base")

	result.main_satisfied = _main_satisfied(order, dish, content)
	if not result.main_satisfied:
		result.failed_conditions.append("main")

	if order.required_herb_id != "":
		result.herb_satisfied = primary_herb_id == order.required_herb_id
	else:
		result.herb_satisfied = _herb_satisfied(primary_herb_id, order.required_herb_property, content)
	if (order.required_herb_property != "" or order.required_herb_id != "") and not result.herb_satisfied:
		result.failed_conditions.append("herb")

	result.optional_satisfied = _herb_satisfied(optional_herb_id, order.optional_herb_property, content)

	if not result.base_satisfied or not result.main_satisfied or not result.herb_satisfied:
		result.quality = OrderEvaluation.Quality.WRONG
	elif order.optional_herb_property != "" and not result.optional_satisfied:
		result.quality = OrderEvaluation.Quality.SUITABLE
	else:
		result.quality = OrderEvaluation.Quality.PERFECT

	if result.quality == OrderEvaluation.Quality.PERFECT:
		result.reward_coins = order.reward_coins + order.tip_coins
		result.tip_coins = order.tip_coins
	elif result.quality == OrderEvaluation.Quality.SUITABLE:
		result.reward_coins = order.reward_coins
	else:
		result.reward_coins = 0
		result.tip_coins = 0

	result.reaction_key = customer.reaction_key_for(result.quality)
	return result


func _main_satisfied(
	order: OrderDefinition,
	dish: RecipeSelection,
	content: GameContent,
) -> bool:
	if dish.main_ingredient_id == "":
		return false
	if order.required_main_ids.size() > 0:
		for required_id in order.required_main_ids:
			if str(required_id) == dish.main_ingredient_id:
				return true
		return false
	if order.required_main_property != "":
		var ingredient := content.get_ingredient(dish.main_ingredient_id)
		if ingredient == null:
			return false
		return ingredient.has_property(order.required_main_property)
	return true


func _herb_satisfied(herb_id: String, property_key: String, content: GameContent) -> bool:
	if herb_id == "":
		return false
	if property_key == "":
		return true
	var herb := content.get_ingredient(herb_id)
	if herb == null:
		return false
	return herb.has_property(property_key)
