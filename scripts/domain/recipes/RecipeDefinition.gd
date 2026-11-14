class_name RecipeDefinition
extends Resource
## Рецепт: названное блюдо, которое можно открыть сочетанием ингредиентов.
## Обычные видны в книге сразу как подсказка, редкие и секретные — только как «???» с намёком.


const RARITY_COMMON: String = "common"
const RARITY_RARE: String = "rare"
const RARITY_SECRET: String = "secret"

@export var id: String = ""
@export var name_key: String = ""
@export var desc_key: String = ""
@export var hint_key: String = ""
@export var rarity: String = RARITY_COMMON
@export var base_id: String = ""
@export var main_id: String = ""
## Свойства трав: на каждое нужна отдельная трава с таким свойством.
@export var herb_props: PackedStringArray = PackedStringArray()
## Конкретные травы (для секретных рецептов): все должны быть в блюде.
@export var herb_ids: PackedStringArray = PackedStringArray()
## Монеты за первое открытие рецепта.
@export var discovery_bonus: int = 5
## Прибавка к награде за заказ, если блюдо — этот рецепт (0.1 = +10%).
@export var reward_bonus: float = 0.1


## Сколько условий в рецепте: чем больше, тем он «специфичнее» и приоритетнее при совпадении.
func specificity() -> int:
	return 2 + herb_props.size() + herb_ids.size() * 2
