class_name OrderDefinition
extends Resource
## Определение заказа: какие условия должен выполнить игрок.


@export var id: String = ""
@export var customer_id: String = ""
@export var text_key: String = ""
@export var required_base_id: String = ""
@export var required_main_ids: PackedStringArray = PackedStringArray()
@export var required_main_property: String = ""
@export var required_herb_property: String = ""
@export var optional_herb_property: String = ""
@export var reward_coins: int = 10
@export var tip_coins: int = 5
## Если не пусто — заказ выдаётся только при купленном улучшении.
@export var requires_upgrade: String = ""
## Особый заказ: редкий, с большой наградой и своими условиями.
@export var is_special: bool = false
@export var title_key: String = ""
## Конкретная трава (для загадок). Если задана, подходит только она — вместо свойства.
@export var required_herb_id: String = ""
@export var min_reputation: int = 0
@export var min_day: int = 1
## Награды за идеальное выполнение особого заказа.
@export var reputation_bonus: int = 0
@export var unlocks_ingredient: String = ""


func has_required_base(base_id: String) -> bool:
	return required_base_id == "" or required_base_id == base_id


func has_required_main(main_ingredient_id: String) -> bool:
	if required_main_ids.size() > 0:
		for required_id in required_main_ids:
			if str(required_id) == main_ingredient_id:
				return true
		return false
	return true
