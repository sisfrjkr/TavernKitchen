class_name UpgradeDefinition
extends Resource
## Определение улучшения таверны. Каждое улучшение имеет игровой и/или видимый эффект.


## Типы эффектов (effect_type):
##  cooking_speed    — value: множитель времени готовки (0.75 = на 25% быстрее)
##  feast_orders     — открывает «пиры» (заказы с requires_upgrade) и крупную дичь
##  reward_bonus     — value: прибавка к награде (0.2 = +20%)
##  decor_light      — светильники в зале (визуальный эффект)
##  storage          — открывает ингредиенты на новых полках
##  hearth           — value: прибавка к терпению гостей (0.25 = +25%) и тёплый камин
##  reputation_bonus — value: дополнительная слава за идеальное блюдо
##  tables           — скатерти и новые столы (визуальный эффект)
@export var id: String = ""
@export var display_name_key: String = ""
@export var description_key: String = ""
@export var effect_type: String = "decor_light"
@export var value: float = 0.0
@export var cost_coins: int = 30
## Что показывать в зале: ключ для Tavern.apply_upgrades().
@export var visual_id: String = ""
