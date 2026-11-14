class_name DailyGoalDefinition
extends Resource
## Ежедневная цель. kind определяет, как считается прогресс:
##  served — обслужено гостей (блюдо подошло); perfect — идеальных блюд; distinct_herbs — разных трав в блюдах;
##  special — выполнено особых заказов; no_lost — день без потерянных заказов; recipe — открыто новых рецептов;
##  streak — серия идеальных блюд подряд.


@export var id: String = ""
@export var kind: String = "served"
@export var target: int = 3
@export var reward_coins: int = 10
@export var text_key: String = ""
