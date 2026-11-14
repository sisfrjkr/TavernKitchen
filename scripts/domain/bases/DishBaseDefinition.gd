class_name DishBaseDefinition
extends Resource
## Определение основы блюда: бульон, жаркое или напиток.


@export var id: String = ""
@export var display_name_key: String = ""
@export var description_key: String = ""
@export var cooking_time: float = 12.0
@export var color: Color = Color(0.5, 0.32, 0.18)


func is_valid_cooking_time() -> bool:
	return cooking_time > 0.0


func icon_path() -> String:
	return "res://assets/ingredients/%s.png" % id
