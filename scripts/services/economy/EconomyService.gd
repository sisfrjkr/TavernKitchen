class_name EconomyService
extends RefCounted
## Чистые правила экономики: награда, чаевые, бонусы и репутация.


const START_COINS: int = 20
const BASE_ORDERS_PER_DAY: int = 3
const ORDERS_PER_DAY: int = 3
const PATIENCE_SECONDS: float = 45.0
const REPUTATION_WRONG: int = -5
const REPUTATION_SUITABLE: int = 5
const REPUTATION_PERFECT: int = 10
const REPUTATION_LOST: int = 2
const REPUTATION_MAX: int = 100
## Каждое идеальное блюдо подряд даёт +10% к следующей награде, максимум +50%.
const STREAK_STEP: float = 0.1
const STREAK_MAX: float = 0.5


## Количество заказов растёт мягко: +1 каждые три дня, но не больше 5.
func orders_for_day(day_number: int) -> int:
	return BASE_ORDERS_PER_DAY + mini(2, int(floor(float(maxi(0, day_number - 1)) / 3.0)))


func streak_bonus_percent(streak: int) -> float:
	return minf(STREAK_MAX, STREAK_STEP * float(maxi(0, streak)))


## streak — сколько идеальных блюд подряд было ДО этого заказа.
## extras: "taste" (монеты за вкус гостя), "recipe_pct" (бонус рецепта), "daily_pct" (блюдо дня), "discovery" (монеты за новый рецепт).
## Бонусы рецепта, блюда дня и вкуса не начисляются за неверное блюдо.
func calculate_reward(order: OrderDefinition, quality: int, counter_bonus: float = 0.0, streak: int = 0, extras: Dictionary = {}) -> Dictionary:
	var base: int = 0
	var tip: int = 0
	if quality == OrderEvaluation.Quality.PERFECT:
		base = order.reward_coins
		tip = order.tip_coins
	elif quality == OrderEvaluation.Quality.SUITABLE:
		base = order.reward_coins
	var subtotal: int = base + tip
	var counter: int = 0
	var streak_coins: int = 0
	var recipe_coins: int = 0
	var daily_coins: int = 0
	var taste: int = 0
	if subtotal > 0:
		counter = int(round(float(subtotal) * maxf(0.0, counter_bonus)))
		if quality == OrderEvaluation.Quality.PERFECT:
			streak_coins = int(round(float(subtotal) * streak_bonus_percent(streak)))
		recipe_coins = int(round(float(subtotal) * maxf(0.0, float(extras.get("recipe_pct", 0.0)))))
		daily_coins = int(round(float(subtotal) * maxf(0.0, float(extras.get("daily_pct", 0.0)))))
		taste = maxi(0, int(extras.get("taste", 0)))
	var discovery: int = maxi(0, int(extras.get("discovery", 0)))
	return {
		"base": base,
		"tip": tip,
		"counter_bonus": counter,
		"streak_bonus": streak_coins,
		"recipe_bonus": recipe_coins,
		"daily_bonus": daily_coins,
		"taste": taste,
		"discovery": discovery,
		"total": subtotal + counter + streak_coins + recipe_coins + daily_coins + taste + discovery,
	}
