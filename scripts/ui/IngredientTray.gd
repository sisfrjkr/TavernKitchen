class_name IngredientTray
extends VBoxContainer
## Лоток ингредиентов: вкладки «Основа / Продукт / Травы» и прокручиваемый ряд (или сетка) карточек.
## На широком экране — один горизонтальный ряд с прокруткой, на узком — сетка с вертикальной прокруткой.


signal item_pressed(kind: String, id: String, card: IngredientCard)
signal tip_requested(data: Dictionary, card: IngredientCard, from_hover: bool)
signal tip_hidden

const KINDS: Array[String] = ["base", "main", "herb"]

var session: GameSessionService
var narrow: bool = false
var current_kind: String = "base"

var _tab_buttons: Dictionary = {}
var _scroll: ScrollContainer
var _grid: GridContainer
var _cards: Dictionary = {}
var _dish: RecipeSelection = RecipeSelection.new()
var _hints: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	for kind in KINDS:
		var button := Button.new()
		button.toggle_mode = true
		button.text = Localization.get_text("ui.tab_" + kind)
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_tab_pressed.bind(kind))
		tabs.add_child(button)
		_tab_buttons[kind] = button
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)


## Подсказки для текущего заказа: сердечко — любит гость; звёздочка — подходит под заказ (если show_required).
func set_hints(order: OrderDefinition, customer: CustomerDefinition, show_required: bool) -> void:
	_hints = {
		"liked": customer.likes if customer != null else PackedStringArray(),
		"order": order,
		"show": show_required,
	}
	if session != null:
		refresh()


func _decorate(card: IngredientCard, kind: String, id: String) -> void:
	if _hints.is_empty():
		return
	var order: OrderDefinition = _hints["order"]
	var liked: bool = false
	var required: bool = false
	if kind == "base":
		required = order != null and order.required_base_id == id
	else:
		var ingredient: IngredientDefinition = session.content.get_ingredient(id)
		if ingredient != null:
			for property_key in _hints["liked"]:
				if ingredient.has_property(str(property_key)):
					liked = true
					break
			if order != null:
				if kind == "main":
					required = order.required_main_ids.has(id)
				else:
					required = id == order.required_herb_id or (order.required_herb_id == "" and order.required_herb_property != "" and ingredient.has_property(order.required_herb_property)) or (order.optional_herb_property != "" and ingredient.has_property(order.optional_herb_property))
	card.set_badges(liked, bool(_hints["show"]) and required)


func bind(p_session: GameSessionService) -> void:
	session = p_session


func set_narrow(value: bool) -> void:
	narrow = value
	if narrow:
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_grid.columns = 4
	else:
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_grid.columns = 40
	if session != null:
		refresh()


func show_tab(kind: String) -> void:
	current_kind = kind
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == kind)
	refresh()


func _on_tab_pressed(kind: String) -> void:
	Audio.play_effect("ui_click")
	tip_hidden.emit()
	show_tab(kind)


## Пересоздаёт карточки текущей вкладки.
func refresh() -> void:
	if session == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	_scroll.scroll_horizontal = 0
	_scroll.scroll_vertical = 0
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == current_kind)
	var content: GameContent = session.content
	if current_kind == "base":
		for base in content.bases:
			_add_card(base.id, "base", _base_data(base), false)
	elif current_kind == "main":
		for ingredient in content.mains():
			_add_ingredient(ingredient)
	else:
		for ingredient in content.herbs():
			_add_ingredient(ingredient)
	sync_selection(_dish)


func _add_ingredient(ingredient: IngredientDefinition) -> void:
	var is_locked: bool = not session.is_ingredient_available(ingredient.id)
	var data: Dictionary = {
		"name": Localization.get_text(ingredient.display_name_key),
		"desc": Localization.get_text(ingredient.description_key),
		"icon": ingredient.icon_path(),
		"props": Array(ingredient.properties),
		"color": ingredient.color,
	}
	if is_locked:
		var upgrade: UpgradeDefinition = session.content.get_upgrade(ingredient.unlocked_by_upgrade)
		if ingredient.rare:
			data["extra"] = Localization.get_text("ui.locked_rare")
		elif upgrade != null:
			data["extra"] = Localization.fmt("ui.locked_by", [Localization.get_text(upgrade.display_name_key)])
	_add_card(ingredient.id, current_kind, data, is_locked)


func _base_data(base: DishBaseDefinition) -> Dictionary:
	var seconds: int = int(round(base.cooking_time * session.cooking_time_multiplier()))
	return {
		"name": Localization.get_text(base.display_name_key),
		"desc": Localization.get_text(base.description_key),
		"icon": base.icon_path(),
		"props": [],
		"short": Localization.fmt("ui.cook_time", [seconds]),
		"extra": Localization.fmt("ui.cook_time", [seconds]),
		"color": base.color,
	}


func _add_card(id: String, kind: String, data: Dictionary, is_locked: bool) -> void:
	var card := IngredientCard.new()
	_grid.add_child(card)
	card.setup(id, kind, data, is_locked, narrow)
	card.pressed.connect(func() -> void:
		if is_locked:
			tip_requested.emit(data, card, false)
		else:
			item_pressed.emit(kind, id, card)
	)
	card.info_requested.connect(func(c: IngredientCard) -> void: tip_requested.emit(data, c, false))
	card.mouse_entered.connect(func() -> void: tip_requested.emit(data, card, true))
	card.mouse_exited.connect(func() -> void: tip_hidden.emit())
	_decorate(card, kind, id)
	_cards[id] = card


## Подсвечивает выбранные карточки текущей вкладки.
func sync_selection(dish: RecipeSelection) -> void:
	_dish = dish
	for id in _cards:
		var card: IngredientCard = _cards[id]
		var selected: bool = false
		if card.kind == "base":
			selected = dish.base_id == id
		elif card.kind == "main":
			selected = dish.main_ingredient_id == id
		else:
			selected = dish.primary_herb_id == id or dish.optional_herb_id == id
		card.set_selected(selected, card.is_selected() != selected)


## После добавления основы переходим к продуктам, после продукта — к травам.
func auto_advance(kind: String) -> void:
	if kind == "base":
		show_tab("main")
	elif kind == "main":
		show_tab("herb")


func card_for(id: String) -> IngredientCard:
	if _cards.has(id):
		return _cards[id]
	return null
