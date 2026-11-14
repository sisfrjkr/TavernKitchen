class_name GameContent
extends RefCounted
## Единый источник игровых данных: ингредиенты, основы, заказы, гости и улучшения.
## Все остальные модули работают через этот класс.


const UP_COPPER_CAULDRON: String = "upgrade_cauldron"
const UP_BIG_CAULDRON: String = "upgrade_big_cauldron"
const UP_COUNTER: String = "upgrade_counter"
const UP_LANTERNS: String = "upgrade_lanterns"
const UP_SHELVES: String = "upgrade_herb_shelf"
const UP_HEARTH: String = "upgrade_hearth"
const UP_DECOR: String = "upgrade_wall_decor"
const UP_TABLES: String = "upgrade_tables"

var ingredients: Array[IngredientDefinition] = []
var bases: Array[DishBaseDefinition] = []
var orders: Array[OrderDefinition] = []
var upgrades: Array[UpgradeDefinition] = []
var customers: Array[CustomerDefinition] = []
var recipes: Array[RecipeDefinition] = []
var goals: Array[DailyGoalDefinition] = []
var achievements: Array[AchievementDefinition] = []


func _init() -> void:
	_load_ingredients()
	_load_bases()
	_load_customers()
	_load_orders()
	_load_upgrades()
	_load_specials()
	_load_recipes()
	_load_goals()
	_load_achievements()


func get_ingredient(id: String) -> IngredientDefinition:
	for ingredient in ingredients:
		if ingredient.id == id:
			return ingredient
	return null


func get_base(id: String) -> DishBaseDefinition:
	for base in bases:
		if base.id == id:
			return base
	return null


func get_order(id: String) -> OrderDefinition:
	for order in orders:
		if order.id == id:
			return order
	return null


func get_upgrade(id: String) -> UpgradeDefinition:
	for upgrade in upgrades:
		if upgrade.id == id:
			return upgrade
	return null


func get_recipe(id: String) -> RecipeDefinition:
	for recipe in recipes:
		if recipe.id == id:
			return recipe
	return null


## Обычные (не особые) заказы.
func regular_orders() -> Array[OrderDefinition]:
	var result: Array[OrderDefinition] = []
	for order in orders:
		if not order.is_special:
			result.append(order)
	return result


func special_orders() -> Array[OrderDefinition]:
	var result: Array[OrderDefinition] = []
	for order in orders:
		if order.is_special:
			result.append(order)
	return result


func get_customer(id: String) -> CustomerDefinition:
	for customer in customers:
		if customer.id == id:
			return customer
	return null


func mains() -> Array[IngredientDefinition]:
	var result: Array[IngredientDefinition] = []
	for ingredient in ingredients:
		if ingredient.is_main():
			result.append(ingredient)
	return result


func herbs() -> Array[IngredientDefinition]:
	var result: Array[IngredientDefinition] = []
	for ingredient in ingredients:
		if ingredient.is_herb():
			result.append(ingredient)
	return result


func _ing(id: String, color: Color, properties: Array, unlocked_by: String = "", is_rare: bool = false) -> void:
	var ingredient := IngredientDefinition.new()
	ingredient.id = id
	var short: String = id.substr(id.find("_") + 1)
	var prefix: String = "ing" if id.begins_with("main_") else "herb"
	ingredient.display_name_key = "%s.%s.name" % [prefix, short]
	ingredient.description_key = "%s.%s.desc" % [prefix, short]
	ingredient.color = color
	ingredient.silhouette_color = color.darkened(0.45)
	ingredient.properties = PackedStringArray(properties)
	ingredient.unlocked_by_upgrade = unlocked_by
	ingredient.rare = is_rare
	ingredients.append(ingredient)


func _load_ingredients() -> void:
	# Продукты. Стартовые — без улучшения.
	_ing("main_chicken", Color(0.78, 0.47, 0.2), ["hearty", "savoury"])
	_ing("main_veg", Color(0.45, 0.65, 0.25), ["hearty", "earthy"])
	_ing("main_root", Color(0.88, 0.66, 0.25), ["hearty", "earthy"])
	_ing("main_mushroom", Color(0.5, 0.33, 0.22), ["earthy", "meaty"])
	_ing("main_carrot", Color(0.92, 0.46, 0.14), ["hearty", "earthy"], UP_SHELVES)
	_ing("main_onion", Color(0.8, 0.52, 0.66), ["savoury", "earthy"], UP_SHELVES)
	_ing("main_fish", Color(0.44, 0.68, 0.78), ["meaty", "hearty"], UP_SHELVES)
	_ing("main_wild", Color(0.6, 0.43, 0.28), ["hearty", "earthy"], UP_SHELVES)
	_ing("main_deer", Color(0.63, 0.24, 0.2), ["meaty", "hearty"], UP_BIG_CAULDRON)
	_ing("main_berries", Color(0.55, 0.14, 0.38), ["sweet"], UP_SHELVES)
	_ing("main_truffle", Color(0.28, 0.2, 0.17), ["earthy", "savoury"], "", true)
	# Травы.
	_ing("herb_warm", Color(0.85, 0.58, 0.22), ["warming"])
	_ing("herb_boost", Color(0.45, 0.78, 0.28), ["invigorating"])
	_ing("herb_calm", Color(0.53, 0.63, 0.7), ["calming"])
	_ing("herb_moon", Color(0.6, 0.75, 0.86), ["calming"], UP_SHELVES)
	_ing("herb_fire", Color(0.93, 0.4, 0.15), ["warming"], UP_SHELVES)
	_ing("herb_bitter", Color(0.38, 0.47, 0.22), ["earthy"], UP_SHELVES)
	_ing("herb_sage", Color(0.62, 0.7, 0.54), ["hearty"], UP_SHELVES)
	_ing("herb_pepper", Color(0.86, 0.2, 0.14), ["spicy", "warming"], UP_SHELVES)
	_ing("herb_star", Color(0.78, 0.86, 1.0), ["calming", "magical"], "", true)


func _load_bases() -> void:
	# Время готовки короткое: игра расслабляющая, а не «ожидающая».
	_base("base_broth", "base.broth", 10.0, Color(0.9, 0.62, 0.28))
	_base("base_drink", "base.drink", 14.0, Color(0.42, 0.6, 0.62))
	_base("base_stew", "base.stew", 18.0, Color(0.55, 0.33, 0.18))


func _base(id: String, key: String, cooking_time: float, color: Color) -> void:
	var base := DishBaseDefinition.new()
	base.id = id
	base.display_name_key = key + ".name"
	base.description_key = key + ".desc"
	base.cooking_time = cooking_time
	base.color = color
	bases.append(base)


func _load_customers() -> void:
	_customer("customer_road_wanderer", 45.0, 0, ["hearty", "warming"])
	_customer("customer_city_cook", 40.0, 0, ["savoury", "spicy"])
	_customer("customer_forest_nomad", 60.0, 0, ["earthy", "sweet"])
	_customer("customer_merchant", 40.0, 20, ["savoury", "meaty"])
	_customer("customer_dwarf", 50.0, 40, ["hearty", "meaty"])
	_customer("customer_hunter", 40.0, 55, ["meaty", "spicy"])
	_customer("customer_elf", 55.0, 60, ["calming", "magical"])


func _customer(id: String, patience: float, unlock_reputation: int, likes: Array = []) -> void:
	var customer := CustomerDefinition.new()
	customer.id = id
	customer.display_name_key = "%s.name" % id
	customer.mood_key = "%s.mood" % id
	customer.bio_key = "%s.bio" % id
	customer.likes = PackedStringArray(likes)
	customer.reaction_perfect = "react.%s.perfect" % id
	customer.reaction_suitable = "react.%s.suitable" % id
	customer.reaction_wrong = "react.%s.wrong" % id
	customer.patience_seconds = patience
	customer.unlock_reputation = unlock_reputation
	customers.append(customer)


func _order(
	short: String,
	customer_id: String,
	base_id: String,
	main_id: String,
	herb_property: String,
	optional_property: String,
	reward: int,
	tip: int,
	requires_upgrade: String = "",
) -> void:
	var order := OrderDefinition.new()
	order.id = "order_" + short
	order.customer_id = customer_id
	order.text_key = "order.%s.text" % short
	order.required_base_id = base_id
	order.required_main_ids = PackedStringArray([main_id])
	order.required_herb_property = herb_property
	order.optional_herb_property = optional_property
	order.reward_coins = reward
	order.tip_coins = tip
	order.requires_upgrade = requires_upgrade
	orders.append(order)


func _load_orders() -> void:
	# Стартовые заказы: только стартовые ингредиенты.
	_order("light", "customer_city_cook", "base_broth", "main_veg", "calming", "", 8, 3)
	_order("drink", "customer_forest_nomad", "base_drink", "main_root", "invigorating", "", 10, 4)
	_order("chill", "customer_road_wanderer", "base_stew", "main_chicken", "warming", "invigorating", 12, 5)
	_order("mushroom", "customer_city_cook", "base_broth", "main_mushroom", "calming", "warming", 9, 4)
	# После «Новых полок».
	_order("carrot", "customer_road_wanderer", "base_broth", "main_carrot", "calming", "warming", 9, 4)
	_order("onion", "customer_city_cook", "base_stew", "main_onion", "warming", "", 10, 4)
	_order("root", "customer_forest_nomad", "base_drink", "main_wild", "invigorating", "warming", 11, 5)
	_order("fish", "customer_road_wanderer", "base_stew", "main_fish", "warming", "invigorating", 14, 6)
	_order("forest", "customer_forest_nomad", "base_broth", "main_mushroom", "earthy", "calming", 12, 5)
	# Новые продукты и специи.
	_order("berry", "customer_forest_nomad", "base_drink", "main_berries", "calming", "warming", 12, 5)
	_order("pepper_fish", "customer_road_wanderer", "base_stew", "main_fish", "spicy", "invigorating", 15, 6)
	_order("berry_broth", "customer_city_cook", "base_broth", "main_berries", "warming", "", 11, 4)
	# Гости с высокой славой.
	_order("dwarf", "customer_dwarf", "base_stew", "main_mushroom", "hearty", "warming", 16, 8)
	_order("elf", "customer_elf", "base_drink", "main_root", "calming", "invigorating", 18, 8)
	# «Пиры»: требуют Большой котёл.
	_order("merchant", "customer_merchant", "base_stew", "main_deer", "warming", "invigorating", 30, 15, UP_BIG_CAULDRON)
	_order("dwarf_feast", "customer_dwarf", "base_stew", "main_deer", "hearty", "warming", 34, 16, UP_BIG_CAULDRON)
	_order("hunter", "customer_hunter", "base_stew", "main_deer", "warming", "hearty", 32, 15, UP_BIG_CAULDRON)
	_order("hunter_spicy", "customer_hunter", "base_stew", "main_deer", "spicy", "hearty", 36, 16, UP_BIG_CAULDRON)


func _upgrade(id: String, short: String, effect: String, value: float, cost: int, visual: String) -> void:
	var upgrade := UpgradeDefinition.new()
	upgrade.id = id
	upgrade.display_name_key = "upgrade.%s.name" % short
	upgrade.description_key = "upgrade.%s.desc" % short
	upgrade.effect_type = effect
	upgrade.value = value
	upgrade.cost_coins = cost
	upgrade.visual_id = visual
	upgrades.append(upgrade)


func _load_upgrades() -> void:
	_upgrade(UP_COPPER_CAULDRON, "cauldron", "cooking_speed", 0.7, 30, "copper_cauldron")
	_upgrade(UP_LANTERNS, "lanterns", "decor_light", 0.0, 40, "lanterns")
	_upgrade(UP_COUNTER, "counter", "reward_bonus", 0.2, 50, "counter")
	_upgrade(UP_SHELVES, "shelves", "storage", 0.0, 55, "shelves")
	_upgrade(UP_TABLES, "tables", "tables", 0.0, 60, "tables")
	_upgrade(UP_HEARTH, "hearth", "hearth", 0.25, 70, "hearth")
	_upgrade(UP_DECOR, "decor", "reputation_bonus", 2.0, 75, "decor")
	_upgrade(UP_BIG_CAULDRON, "big_cauldron", "feast_orders", 0.0, 95, "big_cauldron")


func _special(short: String, customer_id: String, base_id: String, main_id: String, herb_property: String, optional_property: String, reward: int, tip: int, min_rep: int, min_day: int, rep_bonus: int, unlocks: String, herb_id: String = "") -> void:
	var order := OrderDefinition.new()
	order.id = "special_" + short
	order.customer_id = customer_id
	order.text_key = "special.%s.text" % short
	order.title_key = "special.%s.title" % short
	order.is_special = true
	order.required_base_id = base_id
	order.required_main_ids = PackedStringArray([main_id])
	order.required_herb_property = herb_property
	order.required_herb_id = herb_id
	order.optional_herb_property = optional_property
	order.reward_coins = reward
	order.tip_coins = tip
	order.min_reputation = min_rep
	order.min_day = min_day
	order.reputation_bonus = rep_bonus
	order.unlocks_ingredient = unlocks
	orders.append(order)


## Особые заказы: редкие, с большой наградой; идеальное выполнение открывает редкие ингредиенты.
func _load_specials() -> void:
	_special("merchant", "customer_merchant", "base_stew", "main_chicken", "warming", "invigorating", 40, 20, 10, 2, 6, "main_truffle")
	_special("odd", "customer_forest_nomad", "base_drink", "main_berries", "calming", "spicy", 34, 16, 5, 2, 5, "")
	_special("traveller", "customer_elf", "base_drink", "main_wild", "", "spicy", 38, 18, 15, 3, 6, "herb_star", "herb_moon")
	_special("hunters", "customer_hunter", "base_stew", "main_fish", "spicy", "warming", 55, 25, 20, 3, 8, "")
	_special("rare_soup", "customer_city_cook", "base_broth", "main_truffle", "", "", 80, 40, 30, 5, 10, "", "herb_star")


func _recipe(id: String, rarity: String, base_id: String, main_id: String, herb_props: Array, herb_ids: Array, discovery: int, bonus: float) -> void:
	var recipe := RecipeDefinition.new()
	recipe.id = id
	recipe.name_key = "recipe.%s.name" % id
	recipe.desc_key = "recipe.%s.desc" % id
	recipe.hint_key = "recipe.%s.hint" % id
	recipe.rarity = rarity
	recipe.base_id = base_id
	recipe.main_id = main_id
	recipe.herb_props = PackedStringArray(herb_props)
	recipe.herb_ids = PackedStringArray(herb_ids)
	recipe.discovery_bonus = discovery
	recipe.reward_bonus = bonus
	recipes.append(recipe)


func _load_recipes() -> void:
	var c: String = RecipeDefinition.RARITY_COMMON
	var r: String = RecipeDefinition.RARITY_RARE
	var x: String = RecipeDefinition.RARITY_SECRET
	# Обычные: основа + продукт + одно свойство травы.
	_recipe("home_chicken", c, "base_stew", "main_chicken", ["warming"], [], 5, 0.1)
	_recipe("veg_mist", c, "base_broth", "main_veg", ["calming"], [], 5, 0.1)
	_recipe("root_vigor", c, "base_drink", "main_root", ["invigorating"], [], 5, 0.1)
	_recipe("mushroom_whisper", c, "base_broth", "main_mushroom", ["calming"], [], 5, 0.1)
	_recipe("onion_roast", c, "base_stew", "main_onion", ["warming"], [], 6, 0.1)
	_recipe("carrot_morning", c, "base_broth", "main_carrot", ["calming"], [], 6, 0.1)
	_recipe("fisher_soup", c, "base_stew", "main_fish", ["warming"], [], 8, 0.1)
	_recipe("wild_tea", c, "base_drink", "main_wild", ["invigorating"], [], 6, 0.1)
	_recipe("berry_dusk", c, "base_drink", "main_berries", ["calming"], [], 8, 0.1)
	# Редкие: две травы с разными свойствами.
	_recipe("fire_rooster", r, "base_stew", "main_chicken", ["warming", "invigorating"], [], 15, 0.2)
	_recipe("quiet_fish", r, "base_broth", "main_fish", ["calming", "warming"], [], 15, 0.2)
	_recipe("hunter_flame", r, "base_stew", "main_deer", ["spicy", "hearty"], [], 25, 0.25)
	_recipe("berry_sunset", r, "base_drink", "main_berries", ["calming", "warming"], [], 18, 0.2)
	_recipe("forest_feast", r, "base_stew", "main_mushroom", ["hearty", "warming"], [], 18, 0.2)
	# Секретные: конкретные редкие травы и продукты.
	_recipe("moon_roast", x, "base_stew", "main_mushroom", [], ["herb_moon", "herb_fire"], 30, 0.3)
	_recipe("truffle_broth", x, "base_broth", "main_truffle", [], ["herb_star"], 40, 0.35)
	_recipe("star_drink", x, "base_drink", "main_berries", [], ["herb_star"], 40, 0.35)


## Блюдо дня: по номеру дня выбирается один из обычных рецептов — за него +25% к награде.
func daily_recipe_id(day_number: int) -> String:
	var commons: Array[RecipeDefinition] = []
	for recipe in recipes:
		if recipe.rarity == RecipeDefinition.RARITY_COMMON:
			commons.append(recipe)
	if commons.is_empty():
		return ""
	return commons[(maxi(1, day_number) * 5) % commons.size()].id


func get_goal(id: String) -> DailyGoalDefinition:
	for goal in goals:
		if goal.id == id:
			return goal
	return null


func _goal(id: String, kind: String, target: int, reward: int) -> void:
	var goal := DailyGoalDefinition.new()
	goal.id = id
	goal.kind = kind
	goal.target = target
	goal.reward_coins = reward
	goal.text_key = "goal.%s" % id
	goals.append(goal)


func _load_goals() -> void:
	_goal("serve_3", "served", 3, 8)
	_goal("perfect_2", "perfect", 2, 12)
	_goal("herbs_3", "distinct_herbs", 3, 10)
	_goal("no_lost", "no_lost", 1, 12)
	_goal("new_recipe", "recipe", 1, 15)
	_goal("streak_3", "streak", 3, 15)
	_goal("special_1", "special", 1, 20)


## Три цели на день: детерминированно по номеру дня. «Особый заказ» предлагается, только если он вообще возможен.
func pick_daily_goals(day_number: int, special_possible: bool) -> Array[DailyGoalDefinition]:
	var pool: Array[DailyGoalDefinition] = []
	for goal in goals:
		if goal.kind == "special" and not special_possible:
			continue
		pool.append(goal)
	var result: Array[DailyGoalDefinition] = []
	var step: int = 0
	var start: int = maxi(1, day_number) * 2
	while result.size() < 3 and step < pool.size() * 2:
		var candidate: DailyGoalDefinition = pool[(start + step * 5) % pool.size()]
		if not result.has(candidate):
			result.append(candidate)
		step += 1
	return result


func _achievement(id: String, stat: String, target: int, reward: int) -> void:
	var a := AchievementDefinition.new()
	a.id = id
	a.stat = stat
	a.target = target
	a.reward_coins = reward
	a.name_key = "ach.%s.name" % id
	a.desc_key = "ach.%s.desc" % id
	achievements.append(a)


func _load_achievements() -> void:
	_achievement("first_perfect", "perfect_orders", 1, 10)
	_achievement("guests_10", "orders_served", 10, 15)
	_achievement("first_upgrade", "upgrades", 1, 10)
	_achievement("recipes_5", "recipes", 5, 20)
	_achievement("first_special", "specials_done", 1, 25)
	_achievement("perfect_10", "perfect_orders", 10, 30)
	_achievement("level_3", "tavern_level", 3, 40)
	_achievement("secret_one", "secret_recipes", 1, 40)
	_achievement("days_5", "days", 5, 25)
