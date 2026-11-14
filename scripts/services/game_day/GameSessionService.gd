class_name GameSessionService
extends Node
## Оркестратор игрового дня: состояние сессии, заказы, готовка, награды, улучшения.
##
## Цикл: WAITING_FOR_ORDER (выбор блюда) → COOKING → RESULT (награда, кнопка «Дальше»)
##       → следующий заказ или DAY_SUMMARY → следующий день.
## Награда за заказ выдаётся ровно один раз (_grant_reward защищён флагом day.reward_granted,
## который сбрасывается при выдаче каждого нового заказа).


signal state_changed(state: int)
signal order_issued(order: OrderDefinition)
signal order_resolved(order: OrderDefinition, result: OrderEvaluation)
signal order_lost(order: OrderDefinition)
signal day_finished(summary: Dictionary)
signal dish_changed(dish: RecipeSelection)
signal cooking_progress_changed(ratio: float)
signal stirred
signal upgrade_purchased(upgrade_id: String)
signal stats_changed
signal recipe_discovered(recipe: RecipeDefinition)
signal goal_completed(goal: DailyGoalDefinition)
signal stage_changed(stage: int)
signal achievement_unlocked(achievement: AchievementDefinition)
signal special_completed(order: OrderDefinition, unlocked_id: String)

const STATE_WAITING_FOR_ORDER: int = DaySession.State.WAITING_FOR_ORDER
const STATE_COOKING: int = DaySession.State.COOKING
const STATE_RESULT: int = DaySession.State.RESULT
const STATE_DAY_SUMMARY: int = DaySession.State.DAY_SUMMARY

## Сколько единиц терпения гость теряет за секунду (меньше 1 — спокойный темп).
const PATIENCE_DECAY_PER_SECOND: float = 0.5
## Помешивание ускоряет готовку на столько секунд.
const STIR_BONUS_SECONDS: float = 1.0
const STIR_COOLDOWN: float = 0.4
## «Известная таверна» (этап 3): более дорогие заказы.
const STAGE3_REWARD_BONUS: float = 0.15


var day: DaySession
var content: GameContent
var wallet: WalletService
var save_service: SaveService
var evaluator: OrderEvaluator
var economy: EconomyService
var matcher: RecipeMatcher
## Шанс особого заказа на каждый подходящий слот дня (0..1). Тесты ставят 1.0 или 0.0.
var special_chance: float = 0.45
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var special_cursor: int = 0
var tavern_level: int = 1
## Этап таверны: 1 — скромная, 2 — популярная, 3 — известная (по числу улучшений).
var tavern_stage: int = 1
var reputation: int = 0
var combo: int = 0
var order_cursor: int = 0
var running: bool = false
## Пауза на время меню/магазина/настроек: терпение и готовка стоят.
var paused: bool = false
var effective_cooking_time: float = 12.0
var cooking_elapsed: float = 0.0
## Разбор последней награды: base, tip, counter_bonus, streak_bonus, total.
var last_payout: Dictionary = {}
var opened_ingredients: Array[String] = []
var opened_customers: Array[String] = []

var _stir_cooldown: float = 0.0
var _last_order_id: String = ""


func _ready() -> void:
	if content == null:
		setup(get_node_or_null("/root/TavernSave") as SaveService)


## Явная инициализация (для тестов и автозагрузки). Если save_service пуст — создаётся временный.
func setup(p_save: SaveService) -> void:
	save_service = p_save
	if save_service == null:
		save_service = SaveService.new()
		save_service.save_path = "user://tavern_kitchen/session_fallback.cfg"
	content = GameContent.new()
	evaluator = OrderEvaluator.new()
	economy = EconomyService.new()
	matcher = RecipeMatcher.new()
	wallet = WalletService.new()
	day = DaySession.new()
	_load_from_save()


func _process(delta: float) -> void:
	advance(delta)


# --- Загрузка / старт ----------------------------------------------------------

func _load_from_save() -> void:
	var data: SaveData = save_service.save_data
	# Убираем неизвестные улучшения (на случай чужого/повреждённого файла).
	var valid: Array[String] = []
	for upgrade_id in data.owned_upgrades:
		if content.get_upgrade(upgrade_id) != null and not valid.has(upgrade_id):
			valid.append(upgrade_id)
	data.owned_upgrades = valid
	wallet.coins = data.coins
	reputation = data.reputation
	opened_customers = _copy_strings(data.opened_customers)
	opened_ingredients = _copy_strings(data.opened_ingredients)
	day = DaySession.new()
	day.day_number = data.day_number
	combo = 0
	_refresh_tavern_level()
	_sync_opened_ingredients()
	_reset_day_counters()


func has_saved_progress() -> bool:
	return save_service.has_progress()


## Запускает игру: new_game=true стирает прогресс (настройки сохраняются).
func start_session(new_game: bool) -> void:
	if new_game:
		save_service.reset_progress()
	_load_from_save()
	running = true
	paused = false
	issue_order()
	stats_changed.emit()


func _reset_day_counters() -> void:
	day.state = STATE_WAITING_FOR_ORDER
	day.orders_per_day = economy.orders_for_day(day.day_number)
	day.orders_issued = 0
	day.lost_orders = 0
	day.served = 0
	day.perfect_count = 0
	day.suitable_count = 0
	day.wrong_count = 0
	day.coins_earned = 0
	day.reputation_start = reputation
	day.bonus_claimed = false
	day.pack_claimed = false
	day.special_issued = false
	day.daily_recipe_id = content.daily_recipe_id(day.day_number)
	_roll_daily_goals()
	day.current_order = null
	day.current_customer = null
	day.last_result = null
	day.dish = RecipeSelection.new()
	day.reward_granted = false
	day.patience_expired = false
	cooking_elapsed = 0.0
	combo = 0


# --- Игровой цикл --------------------------------------------------------------

func advance(delta: float) -> void:
	if not running or paused or day == null or day.current_order == null:
		return
	if _stir_cooldown > 0.0:
		_stir_cooldown -= delta
	if day.state == STATE_WAITING_FOR_ORDER:
		if save_service.save_data.relaxed_mode:
			return
		day.patience_seconds = maxf(0.0, day.patience_seconds - PATIENCE_DECAY_PER_SECOND * delta)
		if day.patience_seconds <= 0.0:
			_expire_patience()
	elif day.state == STATE_COOKING:
		cooking_elapsed += delta
		cooking_progress_changed.emit(cooking_progress())
		if cooking_elapsed >= effective_cooking_time:
			resolve_cooking()


func cooking_progress() -> float:
	if effective_cooking_time <= 0.0:
		return 1.0
	return clampf(cooking_elapsed / effective_cooking_time, 0.0, 1.0)


func issue_order() -> OrderDefinition:
	if day.orders_issued >= day.orders_per_day:
		return null
	var order: OrderDefinition = _pick_special_order()
	if order == null:
		order = _pick_next_order()
	if order == null:
		return null
	if order.is_special:
		day.special_issued = true
	day.current_order = order
	day.current_customer = content.get_customer(order.customer_id)
	day.dish = RecipeSelection.new()
	day.last_result = null
	day.reward_granted = false
	day.patience_expired = false
	day.patience_max = day.current_customer.patience_seconds * patience_multiplier()
	day.patience_seconds = day.patience_max
	day.orders_issued += 1
	day.state = STATE_WAITING_FOR_ORDER
	day.guest_is_new = mark_customer_opened(order.customer_id)
	day.guest_visit = _register_visit(order.customer_id)
	day.last_recipe = null
	day.last_recipe_discovered = false
	day.last_taste_points = 0
	day.last_daily_hit = false
	day.last_special_rep = 0
	day.last_unlocked = ""
	cooking_elapsed = 0.0
	_last_order_id = order.id
	order_issued.emit(order)
	dish_changed.emit(day.dish)
	state_changed.emit(day.state)
	return order


func _pick_next_order() -> OrderDefinition:
	var eligible: Array[OrderDefinition] = available_orders()
	if eligible.is_empty():
		return null
	var index: int = order_cursor % eligible.size()
	order_cursor += 1
	if eligible.size() > 1 and eligible[index].id == _last_order_id:
		index = (index + 1) % eligible.size()
		order_cursor += 1
	return eligible[index]


## Заказы, которые можно выдать прямо сейчас: гость известен, улучшение куплено,
## нужные продукты и травы уже доступны игроку (иначе «идеально» было бы недостижимо).
func available_orders() -> Array[OrderDefinition]:
	var result: Array[OrderDefinition] = []
	for order in content.regular_orders():
		if is_order_available(order):
			result.append(order)
	return result


## Особые заказы, доступные сейчас (по славе, дню и открытым ингредиентам).
func available_specials() -> Array[OrderDefinition]:
	var result: Array[OrderDefinition] = []
	for order in content.special_orders():
		if is_order_available(order):
			result.append(order)
	return result


func _pick_special_order() -> OrderDefinition:
	if tavern_stage < 2 or day.special_issued or day.orders_issued < 1 or day.orders_issued >= day.orders_per_day:
		return null
	var candidates: Array[OrderDefinition] = available_specials()
	if candidates.is_empty() or rng.randf() >= special_chance:
		return null
	var order: OrderDefinition = candidates[special_cursor % candidates.size()]
	special_cursor += 1
	return order


func is_order_available(order: OrderDefinition) -> bool:
	if order.is_special:
		if reputation < order.min_reputation or day.day_number < order.min_day:
			return false
	else:
		var customer: CustomerDefinition = content.get_customer(order.customer_id)
		if customer == null or not customer.has_unlocked(reputation):
			return false
	if content.get_customer(order.customer_id) == null:
		return false
	if order.requires_upgrade != "" and not has_upgrade(order.requires_upgrade):
		return false
	for main_id in order.required_main_ids:
		if not is_ingredient_available(str(main_id)):
			return false
	if order.required_herb_id != "" and not is_ingredient_available(order.required_herb_id):
		return false
	if order.required_herb_property != "" and not _has_available_herb(order.required_herb_property):
		return false
	if order.optional_herb_property != "" and not _has_available_herb(order.optional_herb_property):
		return false
	return true


func _has_available_herb(property_key: String) -> bool:
	for herb in content.herbs():
		if herb.has_property(property_key) and is_ingredient_available(herb.id):
			return true
	return false


func _expire_patience() -> void:
	day.patience_expired = true
	day.patience_seconds = 0.0
	day.lost_orders += 1
	reputation = maxi(0, reputation - EconomyService.REPUTATION_LOST)
	combo = 0
	var data: SaveData = save_service.save_data
	data.lost_orders += 1
	data.reputation = reputation
	save_service.save()
	var lost: OrderDefinition = day.current_order
	day.dish = RecipeSelection.new()
	day.last_result = null
	day.state = STATE_RESULT
	order_lost.emit(lost)
	state_changed.emit(STATE_RESULT)
	stats_changed.emit()


## Кнопка «Дальше» на панели результата.
func continue_after_result() -> void:
	if day.state != STATE_RESULT:
		return
	if day.orders_issued >= day.orders_per_day:
		finish_day()
	else:
		issue_order()


# --- Выбор блюда ---------------------------------------------------------------

func can_edit_dish() -> bool:
	return running and day.state == STATE_WAITING_FOR_ORDER and day.current_order != null


## Возвращают true, если ингредиент был ДОБАВЛЕН (для анимации), false — снят/не принят.
func select_base(base_id: String) -> bool:
	if not can_edit_dish() or content.get_base(base_id) == null:
		return false
	var added: bool = day.dish.base_id != base_id
	day.dish.base_id = base_id if added else ""
	dish_changed.emit(day.dish)
	return added


func select_main(main_id: String) -> bool:
	if not can_edit_dish() or content.get_ingredient(main_id) == null or not is_ingredient_available(main_id):
		return false
	var added: bool = day.dish.main_ingredient_id != main_id
	day.dish.main_ingredient_id = main_id if added else ""
	dish_changed.emit(day.dish)
	return added


## Трав можно выбрать до двух. Роли («основная/добавка») оценщик подбирает сам.
func toggle_herb(herb_id: String) -> bool:
	if not can_edit_dish() or content.get_ingredient(herb_id) == null or not is_ingredient_available(herb_id):
		return false
	var d: RecipeSelection = day.dish
	var added: bool = true
	if d.primary_herb_id == herb_id:
		d.primary_herb_id = d.optional_herb_id
		d.optional_herb_id = ""
		added = false
	elif d.optional_herb_id == herb_id:
		d.optional_herb_id = ""
		added = false
	elif d.primary_herb_id == "":
		d.primary_herb_id = herb_id
	else:
		d.optional_herb_id = herb_id
	dish_changed.emit(d)
	return added


func clear_dish() -> void:
	if not can_edit_dish():
		return
	day.dish = RecipeSelection.new()
	dish_changed.emit(day.dish)


# --- Готовка -------------------------------------------------------------------

func start_cooking() -> bool:
	if not can_edit_dish() or day.dish == null or not day.dish.is_complete():
		return false
	var base: DishBaseDefinition = content.get_base(day.dish.base_id)
	var cooking_time: float = 12.0
	if base != null:
		cooking_time = base.cooking_time
	effective_cooking_time = maxf(2.0, cooking_time * cooking_time_multiplier())
	cooking_elapsed = 0.0
	_stir_cooldown = 0.0
	day.state = STATE_COOKING
	state_changed.emit(STATE_COOKING)
	cooking_progress_changed.emit(0.0)
	return true


func stir() -> bool:
	if day.state != STATE_COOKING or _stir_cooldown > 0.0:
		return false
	_stir_cooldown = STIR_COOLDOWN
	cooking_elapsed = minf(effective_cooking_time, cooking_elapsed + STIR_BONUS_SECONDS)
	stirred.emit()
	return true


func resolve_cooking() -> OrderEvaluation:
	if day.state != STATE_COOKING:
		return day.last_result
	var result: OrderEvaluation = evaluator.evaluate(day.current_order, day.dish, day.current_customer, content)
	day.last_result = result
	day.state = STATE_RESULT
	cooking_elapsed = effective_cooking_time
	_grant_reward(result)
	order_resolved.emit(day.current_order, result)
	state_changed.emit(STATE_RESULT)
	stats_changed.emit()
	return result


func _grant_reward(result: OrderEvaluation) -> void:
	if day.reward_granted:
		return
	day.reward_granted = true
	var data: SaveData = save_service.save_data
	var recipe: RecipeDefinition = matcher.match_dish(day.dish, content)
	day.last_recipe = recipe
	var extras: Dictionary = {}
	if not result.is_wrong():
		day.last_taste_points = taste_points(day.dish, day.current_customer)
		extras["taste"] = day.last_taste_points * 2
		if recipe != null:
			extras["recipe_pct"] = recipe.reward_bonus
			if recipe.id == day.daily_recipe_id:
				extras["daily_pct"] = 0.25
				day.last_daily_hit = true
	# Новый рецепт открывается и за неудачный заказ: игрок экспериментирует.
	var discovered_now: bool = false
	if recipe != null:
		var entry: Dictionary = data.discovered_recipes.get(recipe.id, {})
		if entry.is_empty():
			discovered_now = true
			extras["discovery"] = recipe.discovery_bonus
			entry = {"count": 1, "best": result.quality}
		else:
			entry = {"count": int(entry.get("count", 0)) + 1, "best": mini(int(entry.get("best", 2)), result.quality)}
		data.discovered_recipes[recipe.id] = entry
	day.last_recipe_discovered = discovered_now
	last_payout = economy.calculate_reward(day.current_order, result.quality, reward_bonus_percent(), combo, extras)
	var total: int = int(last_payout["total"])
	wallet.add(total)
	day.coins_earned += total
	day.served += 1
	if result.is_perfect():
		combo += 1
		day.perfect_count += 1
		data.perfect_orders += 1
		reputation = mini(EconomyService.REPUTATION_MAX, reputation + EconomyService.REPUTATION_PERFECT + perfect_reputation_bonus())
	elif result.is_suitable():
		combo = 0
		day.suitable_count += 1
		reputation = mini(EconomyService.REPUTATION_MAX, reputation + EconomyService.REPUTATION_SUITABLE)
	else:
		combo = 0
		day.wrong_count += 1
		reputation = maxi(0, reputation + EconomyService.REPUTATION_WRONG)
	# Особый заказ: идеальное выполнение даёт славу и может открыть редкий ингредиент.
	var order: OrderDefinition = day.current_order
	if order.is_special and not result.is_wrong():
		data.specials_done += 1
		if result.is_perfect():
			day.last_special_rep = order.reputation_bonus
			reputation = mini(EconomyService.REPUTATION_MAX, reputation + order.reputation_bonus)
			if order.unlocks_ingredient != "" and not data.unlocked_rare.has(order.unlocks_ingredient):
				data.unlocked_rare.append(order.unlocks_ingredient)
				day.last_unlocked = order.unlocks_ingredient
				_sync_opened_ingredients()
	# Прогресс ежедневных целей.
	if not result.is_wrong():
		for herb_id in [day.dish.primary_herb_id, day.dish.optional_herb_id]:
			if str(herb_id) != "" and not day.herbs_used.has(str(herb_id)):
				day.herbs_used.append(str(herb_id))
		if order.is_special:
			day.specials_today += 1
	if discovered_now:
		day.new_recipes_today += 1
	day.best_streak_today = maxi(day.best_streak_today, combo)
	_refresh_goals(false)
	data.coins = wallet.coins
	data.reputation = reputation
	data.orders_served += 1
	data.opened_customers = opened_customers
	data.opened_ingredients = opened_ingredients
	save_service.save()
	_check_achievements()
	if discovered_now:
		recipe_discovered.emit(recipe)
	if order.is_special and not result.is_wrong():
		special_completed.emit(order, day.last_unlocked)


## Сколько ингредиентов блюда (продукт и травы) нравится гостю.
func taste_points(dish: RecipeSelection, customer: CustomerDefinition) -> int:
	if customer == null or customer.likes.is_empty():
		return 0
	var points: int = 0
	for ingredient_id in [dish.main_ingredient_id, dish.primary_herb_id, dish.optional_herb_id]:
		var ingredient: IngredientDefinition = content.get_ingredient(str(ingredient_id))
		if ingredient == null:
			continue
		for liked in customer.likes:
			if ingredient.has_property(str(liked)):
				points += 1
				break
	return points


func _register_visit(customer_id: String) -> int:
	var visits: Dictionary = save_service.save_data.guest_visits
	var count: int = int(visits.get(customer_id, 0)) + 1
	visits[customer_id] = count
	return count


func is_recipe_known(recipe_id: String) -> bool:
	return save_service.save_data.discovered_recipes.has(recipe_id)


func known_recipe_count() -> int:
	return save_service.save_data.discovered_recipes.size()


func finish_day() -> void:
	_refresh_goals(true)
	var goals_done: int = 0
	for goal in day.goals:
		if bool(goal["done"]):
			goals_done += 1
	var summary: Dictionary = {
		"goals_done": goals_done,
		"goals_total": day.goals.size(),
		"goal_coins": day.goal_coins,
		"day_number": day.day_number,
		"served": day.served,
		"perfect": day.perfect_count,
		"suitable": day.suitable_count,
		"wrong": day.wrong_count,
		"lost_orders": day.lost_orders,
		"coins_earned": day.coins_earned,
		"reputation": reputation,
		"reputation_delta": reputation - day.reputation_start,
		"coins": wallet.coins,
	}
	day.state = STATE_DAY_SUMMARY
	var data: SaveData = save_service.save_data
	data.day_number = day.day_number + 1
	data.orders_per_day = economy.orders_for_day(data.day_number)
	save_service.save()
	_check_achievements()
	summary["coins"] = wallet.coins
	day_finished.emit(summary)
	state_changed.emit(STATE_DAY_SUMMARY)


## Бонус за просмотр рекламы: удваивает заработок дня. Вызывается ТОЛЬКО после подтверждённого просмотра.
func grant_ad_bonus() -> int:
	if day.state != STATE_DAY_SUMMARY or day.bonus_claimed or day.coins_earned <= 0:
		return 0
	day.bonus_claimed = true
	wallet.add(day.coins_earned)
	save_service.save_data.coins = wallet.coins
	save_service.save()
	stats_changed.emit()
	return day.coins_earned


## Награда за рекламу: на следующий день доступны редкие ингредиенты. Вызывается только после подтверждённого просмотра.
func grant_ad_pack() -> bool:
	if day.state != STATE_DAY_SUMMARY or day.pack_claimed:
		return false
	day.pack_claimed = true
	save_service.save_data.ad_pack_day = save_service.save_data.day_number
	save_service.save()
	return true


func next_day() -> void:
	if day.state != STATE_DAY_SUMMARY:
		return
	day.day_number = save_service.save_data.day_number
	_reset_day_counters()
	issue_order()


# --- Улучшения -----------------------------------------------------------------

func has_upgrade(upgrade_id: String) -> bool:
	return save_service.save_data.owned_upgrades.has(upgrade_id)


func can_buy_upgrade(upgrade_id: String) -> bool:
	var upgrade: UpgradeDefinition = content.get_upgrade(upgrade_id)
	return upgrade != null and not has_upgrade(upgrade_id) and wallet.has(upgrade.cost_coins)


func buy_upgrade(upgrade_id: String) -> bool:
	var upgrade: UpgradeDefinition = content.get_upgrade(upgrade_id)
	if upgrade == null or has_upgrade(upgrade_id):
		return false
	if not wallet.spend(upgrade.cost_coins):
		return false
	save_service.save_data.owned_upgrades.append(upgrade_id)
	save_service.save_data.coins = wallet.coins
	_refresh_tavern_level()
	_sync_opened_ingredients()
	save_service.save()
	_check_achievements()
	upgrade_purchased.emit(upgrade_id)
	stats_changed.emit()
	return true


func _upgrades_with_effect(effect_type: String) -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	for upgrade_id in save_service.save_data.owned_upgrades:
		var upgrade: UpgradeDefinition = content.get_upgrade(upgrade_id)
		if upgrade != null and upgrade.effect_type == effect_type:
			result.append(upgrade)
	return result


func cooking_time_multiplier() -> float:
	var multiplier: float = 1.0
	for upgrade in _upgrades_with_effect("cooking_speed"):
		multiplier *= upgrade.value
	return maxf(0.4, multiplier)


func reward_bonus_percent() -> float:
	var total: float = 0.0
	for upgrade in _upgrades_with_effect("reward_bonus"):
		total += upgrade.value
	if tavern_stage >= 3:
		total += STAGE3_REWARD_BONUS
	return total


func patience_multiplier() -> float:
	var total: float = 1.0
	for upgrade in _upgrades_with_effect("hearth"):
		total += upgrade.value
	return total


func perfect_reputation_bonus() -> int:
	var total: int = 0
	for upgrade in _upgrades_with_effect("reputation_bonus"):
		total += int(upgrade.value)
	return total


func is_ingredient_available(ingredient_id: String) -> bool:
	var ingredient: IngredientDefinition = content.get_ingredient(ingredient_id)
	if ingredient == null:
		return false
	if ingredient.rare:
		# Открыт наградой за особый заказ или временно — наградой за рекламу на этот день.
		return save_service.save_data.unlocked_rare.has(ingredient_id) or (save_service.save_data.ad_pack_day > 0 and save_service.save_data.ad_pack_day == day.day_number)
	return ingredient.unlocked_by_upgrade == "" or has_upgrade(ingredient.unlocked_by_upgrade)


static func stage_for_upgrades(count: int) -> int:
	if count >= 6:
		return 3
	if count >= 3:
		return 2
	return 1


func _refresh_tavern_level() -> void:
	tavern_level = clampi(1 + int(floor(float(save_service.save_data.owned_upgrades.size()) / 2.0)), 1, 5)
	save_service.save_data.tavern_level = tavern_level
	var new_stage: int = stage_for_upgrades(save_service.save_data.owned_upgrades.size())
	var changed: bool = new_stage != tavern_stage
	tavern_stage = new_stage
	if changed and running:
		stage_changed.emit(tavern_stage)


func _sync_opened_ingredients() -> void:
	for ingredient in content.ingredients:
		if is_ingredient_available(ingredient.id) and not opened_ingredients.has(ingredient.id):
			opened_ingredients.append(ingredient.id)
	save_service.save_data.opened_ingredients = opened_ingredients


# --- Коллекция ------------------------------------------------------------------

## Возвращает true, если гость открыт впервые.
func mark_customer_opened(customer_id: String) -> bool:
	if opened_customers.has(customer_id):
		return false
	opened_customers.append(customer_id)
	save_service.save_data.opened_customers = opened_customers
	save_service.save()
	return true


func _copy_strings(source: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for item in source:
		result.append(item)
	return result


# --- Ежедневные цели и достижения -------------------------------------------------

func _roll_daily_goals() -> void:
	day.goals = []
	day.herbs_used = []
	day.new_recipes_today = 0
	day.specials_today = 0
	day.best_streak_today = 0
	day.goal_coins = 0
	var special_possible: bool = not available_specials().is_empty()
	for goal in content.pick_daily_goals(day.day_number, special_possible):
		day.goals.append({"id": goal.id, "progress": 0, "target": goal.target, "done": false, "reward": goal.reward_coins})


## Пересчитывает прогресс целей из счётчиков дня; выполненная цель сразу платит монеты.
func _refresh_goals(day_end: bool) -> void:
	for goal in day.goals:
		if bool(goal["done"]):
			continue
		var definition: DailyGoalDefinition = content.get_goal(str(goal["id"]))
		if definition == null:
			continue
		var value: int = 0
		match definition.kind:
			"served":
				value = day.perfect_count + day.suitable_count
			"perfect":
				value = day.perfect_count
			"distinct_herbs":
				value = day.herbs_used.size()
			"special":
				value = day.specials_today
			"recipe":
				value = day.new_recipes_today
			"streak":
				value = day.best_streak_today
			"no_lost":
				value = 1 if (day_end and day.lost_orders == 0 and day.served > 0) else 0
		goal["progress"] = mini(value, int(goal["target"]))
		if value >= int(goal["target"]):
			goal["done"] = true
			var reward: int = int(goal["reward"])
			wallet.add(reward)
			day.goal_coins += reward
			var data: SaveData = save_service.save_data
			data.coins = wallet.coins
			data.goals_completed_total += 1
			goal_completed.emit(definition)
	stats_changed.emit()


func stat_value(stat: String) -> int:
	var data: SaveData = save_service.save_data
	match stat:
		"perfect_orders":
			return data.perfect_orders
		"orders_served":
			return data.orders_served
		"specials_done":
			return data.specials_done
		"recipes":
			return data.discovered_recipes.size()
		"secret_recipes":
			var count: int = 0
			for recipe_id in data.discovered_recipes:
				var recipe: RecipeDefinition = content.get_recipe(str(recipe_id))
				if recipe != null and recipe.rarity == RecipeDefinition.RARITY_SECRET:
					count += 1
			return count
		"upgrades":
			return data.owned_upgrades.size()
		"tavern_level":
			return tavern_level
		"days":
			return maxi(0, data.day_number - 1)
	return 0


func _check_achievements() -> void:
	var data: SaveData = save_service.save_data
	var unlocked_now: Array[AchievementDefinition] = []
	for achievement in content.achievements:
		if data.achievements.has(achievement.id):
			continue
		if stat_value(achievement.stat) >= achievement.target:
			data.achievements.append(achievement.id)
			wallet.add(achievement.reward_coins)
			unlocked_now.append(achievement)
	if unlocked_now.is_empty():
		return
	data.coins = wallet.coins
	save_service.save()
	for achievement in unlocked_now:
		achievement_unlocked.emit(achievement)
	stats_changed.emit()
