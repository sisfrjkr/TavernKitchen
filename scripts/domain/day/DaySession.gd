class_name DaySession
extends RefCounted
## Состояния игрового дня и текущая сессия заказов.


enum State {
	WAITING_FOR_ORDER = 0,
	COOKING = 1,
	RESULT = 2,
	DAY_SUMMARY = 3,
}


var state: int = State.WAITING_FOR_ORDER
var day_number: int = 1
var orders_per_day: int = 3
var orders_issued: int = 0
var lost_orders: int = 0
var current_order: OrderDefinition
var current_customer: CustomerDefinition
var dish: RecipeSelection = RecipeSelection.new()
var patience_seconds: float = 45.0
var patience_max: float = 45.0
var last_result: OrderEvaluation
var reward_granted: bool = false
var patience_expired: bool = false
## Гость показан впервые за всю игру.
var guest_is_new: bool = false

# Статистика дня.
var served: int = 0
var perfect_count: int = 0
var suitable_count: int = 0
var wrong_count: int = 0
var coins_earned: int = 0
var reputation_start: int = 0
var bonus_claimed: bool = false

# Разнообразие дня.
var special_issued: bool = false
var daily_recipe_id: String = ""
## Какой по счёту визит этого гостя (1 — первый).
var guest_visit: int = 1
# Подробности последней оценки (для панели результата).
var last_recipe: RecipeDefinition
var last_recipe_discovered: bool = false
var last_taste_points: int = 0
var last_daily_hit: bool = false
var last_special_rep: int = 0
var last_unlocked: String = ""

# Ежедневные цели: [{id, progress, target, done, reward}].
var goals: Array[Dictionary] = []
var herbs_used: Array[String] = []
var new_recipes_today: int = 0
var specials_today: int = 0
var best_streak_today: int = 0
var goal_coins: int = 0
var pack_claimed: bool = false
