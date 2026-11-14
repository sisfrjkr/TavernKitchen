class_name OrderEvaluation extends RefCounted
## Результат оценки заказа: качество, выполненные условия, награда, реакция.


## Качество результата блюда. Меньшее число — лучший результат.
enum Quality {
	PERFECT = 0,
	SUITABLE = 1,
	WRONG = 2,
}


var quality: int = Quality.WRONG
var base_satisfied: bool = false
var main_satisfied: bool = false
var herb_satisfied: bool = false
var optional_satisfied: bool = false
var failed_conditions: Array[String] = []
var reward_coins: int = 0
var tip_coins: int = 0
var reaction_key: String = ""
## Какая трава была засчитана как основная и как дополнительная (после подбора ролей).
var used_primary_herb_id: String = ""
var used_optional_herb_id: String = ""


func is_perfect() -> bool:
	return quality == Quality.PERFECT


func is_suitable() -> bool:
	return quality == Quality.SUITABLE


func is_wrong() -> bool:
	return quality == Quality.WRONG
