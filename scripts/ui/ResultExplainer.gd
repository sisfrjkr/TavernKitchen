class_name ResultExplainer
extends RefCounted
## Понятное объяснение результата: что именно совпало, а что нет.
## Возвращает список строк {ok: bool, text: String}.


static func build(order: OrderDefinition, dish: RecipeSelection, result: OrderEvaluation, content: GameContent) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var none_text: String = Localization.get_text("ui.expl_none")

	# Основа.
	var wanted_base: DishBaseDefinition = content.get_base(order.required_base_id)
	var got_base: DishBaseDefinition = content.get_base(dish.base_id)
	var wanted_base_name: String = Localization.get_text(wanted_base.display_name_key) if wanted_base != null else none_text
	var got_base_name: String = Localization.get_text(got_base.display_name_key) if got_base != null else none_text
	if result.base_satisfied:
		lines.append({"ok": true, "text": Localization.fmt("ui.expl_base_ok", [got_base_name])})
	else:
		lines.append({"ok": false, "text": Localization.fmt("ui.expl_base_bad", [wanted_base_name, got_base_name])})

	# Продукт.
	var wanted_main: IngredientDefinition = null
	if order.required_main_ids.size() > 0:
		wanted_main = content.get_ingredient(str(order.required_main_ids[0]))
	var got_main: IngredientDefinition = content.get_ingredient(dish.main_ingredient_id)
	var wanted_main_name: String = Localization.get_text(wanted_main.display_name_key) if wanted_main != null else none_text
	var got_main_name: String = Localization.get_text(got_main.display_name_key) if got_main != null else none_text
	if result.main_satisfied:
		lines.append({"ok": true, "text": Localization.fmt("ui.expl_main_ok", [got_main_name])})
	else:
		lines.append({"ok": false, "text": Localization.fmt("ui.expl_main_bad", [wanted_main_name, got_main_name])})

	# Обязательная трава.
	if order.required_herb_id != "":
		var wanted: IngredientDefinition = content.get_ingredient(order.required_herb_id)
		var wanted_name: String = Localization.get_text(wanted.display_name_key) if wanted != null else "?"
		var used: IngredientDefinition = content.get_ingredient(result.used_primary_herb_id)
		if result.herb_satisfied:
			lines.append({"ok": true, "text": Localization.fmt("ui.expl_herb_id", [wanted_name])})
		else:
			var got: String = Localization.get_text(used.display_name_key) if used != null else Localization.get_text("ui.expl_none")
			lines.append({"ok": false, "text": "%s (%s)" % [Localization.fmt("ui.expl_herb_id", [wanted_name]), got]})
	elif order.required_herb_property != "":
		var adjective: String = Localization.property_adjective(order.required_herb_property)
		var herb: IngredientDefinition = content.get_ingredient(result.used_primary_herb_id)
		if result.herb_satisfied and herb != null:
			lines.append({"ok": true, "text": Localization.fmt("ui.expl_herb_ok", [Localization.get_text(herb.display_name_key), Localization.property_name(order.required_herb_property)])})
		elif herb == null:
			lines.append({"ok": false, "text": Localization.fmt("ui.expl_herb_none", [adjective])})
		else:
			lines.append({"ok": false, "text": Localization.fmt("ui.expl_herb_bad", [adjective, Localization.get_text(herb.display_name_key)])})

	# Дополнительная трава (по желанию гостя).
	if order.optional_herb_property != "":
		var adjective2: String = Localization.property_adjective(order.optional_herb_property)
		var extra: IngredientDefinition = content.get_ingredient(result.used_optional_herb_id)
		if result.optional_satisfied and extra != null:
			lines.append({"ok": true, "text": Localization.fmt("ui.expl_opt_ok", [Localization.get_text(extra.display_name_key), Localization.property_name(order.optional_herb_property)])})
		else:
			lines.append({"ok": false, "text": Localization.fmt("ui.expl_opt_missing", [adjective2])})
	return lines


## Читаемое название блюда: название рецепта или запасное «Основа · Продукт».
static func dish_name(dish: RecipeSelection, content: GameContent, matcher: RecipeMatcher) -> String:
	var recipe: RecipeDefinition = matcher.match_dish(dish, content)
	if recipe != null:
		return Localization.get_text(recipe.name_key)
	var base: DishBaseDefinition = content.get_base(dish.base_id)
	var main: IngredientDefinition = content.get_ingredient(dish.main_ingredient_id)
	var base_name: String = Localization.get_text(base.display_name_key) if base != null else "?"
	var main_name: String = Localization.get_text(main.display_name_key) if main != null else "?"
	return "%s · %s" % [base_name, main_name]
