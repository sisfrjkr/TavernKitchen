class_name RecipeMatcher
extends RefCounted
## Определяет, какому рецепту соответствует блюдо. Чистая логика, без сцен.


## Возвращает самый специфичный подходящий рецепт или null.
func match_dish(dish: RecipeSelection, content: GameContent) -> RecipeDefinition:
	if dish.base_id == "" or dish.main_ingredient_id == "" or dish.primary_herb_id == "":
		return null
	var best: RecipeDefinition = null
	for recipe in content.recipes:
		if not matches(recipe, dish, content):
			continue
		if best == null or recipe.specificity() > best.specificity():
			best = recipe
	return best


func matches(recipe: RecipeDefinition, dish: RecipeSelection, content: GameContent) -> bool:
	if recipe.base_id != dish.base_id or recipe.main_id != dish.main_ingredient_id:
		return false
	var herbs: Array[String] = _dish_herbs(dish)
	for herb_id in recipe.herb_ids:
		if not herbs.has(str(herb_id)):
			return false
	# Каждому требуемому свойству — своя трава (перебор небольшой: до двух трав).
	return _assign(recipe.herb_props, 0, herbs, [], content)


func _dish_herbs(dish: RecipeSelection) -> Array[String]:
	var herbs: Array[String] = []
	if dish.primary_herb_id != "":
		herbs.append(dish.primary_herb_id)
	if dish.optional_herb_id != "":
		herbs.append(dish.optional_herb_id)
	return herbs


func _assign(props: PackedStringArray, index: int, herbs: Array[String], used: Array, content: GameContent) -> bool:
	if index >= props.size():
		return true
	for herb_id in herbs:
		if used.has(herb_id):
			continue
		var herb: IngredientDefinition = content.get_ingredient(herb_id)
		if herb != null and herb.has_property(str(props[index])):
			var next_used: Array = used.duplicate()
			next_used.append(herb_id)
			if _assign(props, index + 1, herbs, next_used, content):
				return true
	return false
