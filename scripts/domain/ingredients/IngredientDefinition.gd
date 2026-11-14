class_name IngredientDefinition
extends Resource
## Определение ингредиента: главный продукт или трава.
## Данные собираются в GameContent, правила оценки — в OrderEvaluator.


const PROPERTY_WARMING: String = "warming"
const PROPERTY_INVIGORATING: String = "invigorating"
const PROPERTY_CALMING: String = "calming"
const PROPERTY_EARTHY: String = "earthy"
const PROPERTY_HEARTY: String = "hearty"
const PROPERTY_SWEET: String = "sweet"
const PROPERTY_SPICY: String = "spicy"
const PROPERTY_MAGICAL: String = "magical"


@export var id: String = ""
@export var display_name_key: String = ""
@export var description_key: String = ""
@export var color: Color = Color(0.55, 0.36, 0.2)
@export var silhouette_color: Color = Color(0.28, 0.18, 0.12)
@export var properties: PackedStringArray = PackedStringArray()
## Улучшение, которое открывает ингредиент. Пустая строка — доступен с начала игры.
@export var unlocked_by_upgrade: String = ""
## Редкий ингредиент: открывается только наградой за особый заказ (см. OrderDefinition.unlocks_ingredient).
@export var rare: bool = false


func has_property(property_key: String) -> bool:
	for property in properties:
		if str(property) == property_key:
			return true
	return false


func is_herb() -> bool:
	return id.begins_with("herb_")


func is_main() -> bool:
	return id.begins_with("main_")


func icon_path() -> String:
	return "res://assets/ingredients/%s.png" % id
