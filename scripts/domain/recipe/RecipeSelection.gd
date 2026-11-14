class_name RecipeSelection
extends RefCounted
## Выбранное игроком блюдо: основа + главный ингредиент + трава (+ дополнительная трава).


var base_id: String = ""
var main_ingredient_id: String = ""
var primary_herb_id: String = ""
var optional_herb_id: String = ""


func is_complete() -> bool:
	return base_id != "" and main_ingredient_id != "" and primary_herb_id != ""


func is_empty() -> bool:
	return base_id == "" and main_ingredient_id == "" and primary_herb_id == "" and optional_herb_id == ""
