class_name CustomerDefinition
extends Resource
## Определение гостя: характер, реакции на качество блюда, порог славы.


@export var id: String = ""
@export var display_name_key: String = ""
@export var mood_key: String = ""
@export var reaction_perfect: String = "reaction.perfect"
@export var reaction_suitable: String = "reaction.suitable"
@export var reaction_wrong: String = "reaction.wrong"
@export var patience_seconds: float = 45.0
@export var unlock_reputation: int = 0
## Свойства ингредиентов, которые гость любит: за каждый такой ингредиент в блюде — бонус вкуса.
@export var likes: PackedStringArray = PackedStringArray()
@export var bio_key: String = ""


func reaction_key_for(quality: int) -> String:
	if quality == OrderEvaluation.Quality.PERFECT:
		return reaction_perfect
	if quality == OrderEvaluation.Quality.SUITABLE:
		return reaction_suitable
	return reaction_wrong


func has_unlocked(reputation: int) -> bool:
	return reputation >= unlock_reputation


func portrait_path(expression: String) -> String:
	return "res://assets/guests/%s_%s.png" % [id, expression]
