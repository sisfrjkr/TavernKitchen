class_name SaveData
extends RefCounted
## Версионированные данные сохранения прогресса.
## from_dictionary() никогда не падает на мусоре: любые поля приводятся к безопасным значениям.


const CURRENT_VERSION: int = 7
const DEFAULT_COINS: int = 20

## Улучшения старых версий, которых больше нет: возвращаем их стоимость монетами.
const LEGACY_REFUNDS: Dictionary = {
	"upgrade_stew_pot": 80,
	"upgrade_iron_kettle": 50,
	"upgrade_iron_oven": 90,
	"upgrade_big_sign": 60,
	"upgrade_barrels": 65,
}


var version: int = CURRENT_VERSION
var coins: int = DEFAULT_COINS
var reputation: int = 0
var owned_upgrades: Array[String] = []
var day_number: int = 1
var orders_served: int = 0
var lost_orders: int = 0
var tavern_level: int = 1
var opened_ingredients: Array[String] = []
var opened_customers: Array[String] = []
var orders_per_day: int = 3
var perfect_orders: int = 0
## Открытые рецепты: id -> {"count": сколько раз приготовлено, "best": лучшее качество (OrderEvaluation.Quality)}.
var discovered_recipes: Dictionary = {}
## Сколько раз гость приходил: id -> число визитов.
var guest_visits: Dictionary = {}
## Открытые редкие ингредиенты (награды за особые заказы).
var unlocked_rare: Array[String] = []
var specials_done: int = 0
## Открытые достижения и общее число выполненных ежедневных целей.
var achievements: Array[String] = []
var goals_completed_total: int = 0
## Обучение показано (чтобы не повторять).
var tutorial_seen: bool = false
## День, в который действует награда за рекламу «редкие ингредиенты на день» (0 — нет).
var ad_pack_day: int = 0

var master_volume: float = 0.9
var music_volume: float = 0.8
var ambience_volume: float = 0.8
var voices_volume: float = 0.8
var sfx_volume: float = 0.7
var relaxed_mode: bool = false


func to_dictionary() -> Dictionary:
	return {
		"version": version,
		"coins": coins,
		"reputation": reputation,
		"owned_upgrades": owned_upgrades,
		"day_number": day_number,
		"orders_served": orders_served,
		"lost_orders": lost_orders,
		"tavern_level": tavern_level,
		"opened_ingredients": opened_ingredients,
		"opened_customers": opened_customers,
		"orders_per_day": orders_per_day,
		"perfect_orders": perfect_orders,
		"discovered_recipes": discovered_recipes,
		"guest_visits": guest_visits,
		"unlocked_rare": unlocked_rare,
		"specials_done": specials_done,
		"achievements": achievements,
		"goals_completed_total": goals_completed_total,
		"tutorial_seen": tutorial_seen,
		"ad_pack_day": ad_pack_day,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"ambience_volume": ambience_volume,
		"voices_volume": voices_volume,
		"sfx_volume": sfx_volume,
		"relaxed_mode": relaxed_mode,
	}


func from_dictionary(data: Dictionary) -> void:
	var loaded_version: int = _to_int(data.get("version", 1), 1)
	coins = maxi(0, _to_int(data.get("coins", DEFAULT_COINS), DEFAULT_COINS))
	reputation = clampi(_to_int(data.get("reputation", 0), 0), 0, 100)
	owned_upgrades = _unique(_read_string_array(data.get("owned_upgrades", [])))
	day_number = maxi(1, _to_int(data.get("day_number", 1), 1))
	orders_served = maxi(0, _to_int(data.get("orders_served", 0), 0))
	lost_orders = maxi(0, _to_int(data.get("lost_orders", 0), 0))
	tavern_level = clampi(_to_int(data.get("tavern_level", 1), 1), 1, 5)
	opened_ingredients = _unique(_read_string_array(data.get("opened_ingredients", [])))
	opened_customers = _unique(_read_string_array(data.get("opened_customers", [])))
	orders_per_day = clampi(_to_int(data.get("orders_per_day", 3), 3), 1, 10)
	perfect_orders = maxi(0, _to_int(data.get("perfect_orders", 0), 0))
	discovered_recipes = _read_recipes(data.get("discovered_recipes", {}))
	guest_visits = _read_counts(data.get("guest_visits", {}))
	unlocked_rare = _unique(_read_string_array(data.get("unlocked_rare", [])))
	specials_done = maxi(0, _to_int(data.get("specials_done", 0), 0))
	achievements = _unique(_read_string_array(data.get("achievements", [])))
	goals_completed_total = maxi(0, _to_int(data.get("goals_completed_total", 0), 0))
	ad_pack_day = maxi(0, _to_int(data.get("ad_pack_day", 0), 0))
	tutorial_seen = typeof(data.get("tutorial_seen", false)) == TYPE_BOOL and bool(data.get("tutorial_seen", false))
	master_volume = clampf(_to_float(data.get("master_volume", 0.9), 0.9), 0.0, 1.0)
	music_volume = clampf(_to_float(data.get("music_volume", 0.8), 0.8), 0.0, 1.0)
	ambience_volume = clampf(_to_float(data.get("ambience_volume", 0.8), 0.8), 0.0, 1.0)
	voices_volume = clampf(_to_float(data.get("voices_volume", 0.8), 0.8), 0.0, 1.0)
	sfx_volume = clampf(_to_float(data.get("sfx_volume", 0.7), 0.7), 0.0, 1.0)
	relaxed_mode = bool(data.get("relaxed_mode", false)) if typeof(data.get("relaxed_mode", false)) == TYPE_BOOL else false
	if loaded_version < 3:
		_migrate_legacy_upgrades()
	version = CURRENT_VERSION


func has_progress() -> bool:
	return day_number > 1 or orders_served > 0 or lost_orders > 0 or owned_upgrades.size() > 0 or coins != DEFAULT_COINS


## Сбрасывает прогресс, сохраняя настройки (громкость, расслабленный режим).
func reset_progress() -> void:
	var keep_master: float = master_volume
	var keep_ambience: float = ambience_volume
	var keep_voices: float = voices_volume
	var keep_music: float = music_volume
	var keep_sfx: float = sfx_volume
	var keep_relaxed: bool = relaxed_mode
	var keep_tutorial: bool = tutorial_seen
	from_dictionary({})
	tutorial_seen = keep_tutorial
	master_volume = keep_master
	ambience_volume = keep_ambience
	voices_volume = keep_voices
	music_volume = keep_music
	sfx_volume = keep_sfx
	relaxed_mode = keep_relaxed


func _migrate_legacy_upgrades() -> void:
	var kept: Array[String] = []
	for id in owned_upgrades:
		if LEGACY_REFUNDS.has(id):
			coins += int(LEGACY_REFUNDS[id])
		else:
			kept.append(id)
	owned_upgrades = kept


static func _to_int(value: Variant, fallback: int) -> int:
	var t: int = typeof(value)
	if t == TYPE_INT:
		return value
	if t == TYPE_FLOAT:
		if is_nan(value) or is_inf(value):
			return fallback
		return int(value)
	if t == TYPE_STRING and String(value).is_valid_int():
		return String(value).to_int()
	return fallback


static func _to_float(value: Variant, fallback: float) -> float:
	var t: int = typeof(value)
	if t == TYPE_FLOAT:
		if is_nan(value) or is_inf(value):
			return fallback
		return value
	if t == TYPE_INT:
		return float(value)
	if t == TYPE_STRING and String(value).is_valid_float():
		return String(value).to_float()
	return fallback


static func _read_recipes(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value:
		var entry: Variant = value[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		result[str(key)] = {
			"count": maxi(1, _to_int(entry.get("count", 1), 1)),
			"best": clampi(_to_int(entry.get("best", 2), 2), 0, 2),
		}
	return result


static func _read_counts(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value:
		result[str(key)] = maxi(0, _to_int(value[key], 0))
	return result


static func _read_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY and typeof(value) != TYPE_PACKED_STRING_ARRAY:
		return result
	for item in value:
		if typeof(item) == TYPE_STRING or typeof(item) == TYPE_STRING_NAME:
			result.append(str(item))
	return result


static func _unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for item in values:
		if not result.has(item):
			result.append(item)
	return result
