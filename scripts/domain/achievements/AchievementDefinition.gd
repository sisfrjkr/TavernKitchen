class_name AchievementDefinition
extends Resource
## Достижение: открывается, когда статистика stat достигает target.
## Статистики: perfect_orders, orders_served, specials_done, recipes, secret_recipes, upgrades, tavern_level, days.


@export var id: String = ""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var stat: String = "perfect_orders"
@export var target: int = 1
@export var reward_coins: int = 10
