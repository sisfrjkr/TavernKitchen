class_name RecipeBook
extends Control
## Книга рецептов: известные рецепты с составом и статистикой, неизвестные — «???» с намёком.


signal closed

var session: GameSessionService
var _panel: PanelContainer
var _list: VBoxContainer
var _count_label: Label
var _scroll: ScrollContainer
var _narrow: bool = false


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.dim_background(0.78))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.dark_panel(20))
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	head.add_child(UiKit.icon_rect("icon_book", 40))
	var title := UiKit.label(Localization.get_text("ui.recipe_book"), 32, UiKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count_label = UiKit.label("", 20, UiKit.CREAM)
	head.add_child(_count_label)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var close := Button.new()
	close.text = Localization.get_text("ui.close_book")
	close.custom_minimum_size = Vector2(0, 54)
	close.focus_mode = Control.FOCUS_NONE
	UiKit.make_gold(close)
	close.pressed.connect(close_book)
	column.add_child(close)


func bind(p_session: GameSessionService) -> void:
	session = p_session


func set_narrow(narrow: bool) -> void:
	_narrow = narrow
	_apply_size()


func _apply_size() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var width: float = minf(viewport.x - 24.0, 700.0)
	_panel.custom_minimum_size = Vector2(width, 0)
	_scroll.custom_minimum_size = Vector2(width - 40.0, maxf(240.0, viewport.y - 250.0))


func open_book() -> void:
	_apply_size()
	_rebuild()
	visible = true
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)


func close_book() -> void:
	Audio.play_effect("ui_click")
	visible = false
	closed.emit()


func _rebuild() -> void:
	var recipes: Array[RecipeDefinition] = []
	for recipe in session.content.recipes:
		recipes.append(recipe)
	# Обычные → редкие → секретные.
	var order: Dictionary = {"common": 0, "rare": 1, "secret": 2}
	recipes.sort_custom(func(a: RecipeDefinition, b: RecipeDefinition) -> bool:
		return int(order[a.rarity]) < int(order[b.rarity]))
	_count_label.text = Localization.fmt("ui.recipes_known", [session.known_recipe_count(), recipes.size()])
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for recipe in recipes:
		_list.add_child(_make_card(recipe))


func _rarity_color(rarity: String) -> Color:
	if rarity == RecipeDefinition.RARITY_SECRET:
		return Color(0.6, 0.5, 0.95)
	if rarity == RecipeDefinition.RARITY_RARE:
		return Color(0.9, 0.6, 0.15)
	return Color(0.5, 0.7, 0.4)


func _make_card(recipe: RecipeDefinition) -> Control:
	var known: bool = session.is_recipe_known(recipe.id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box("card_selected" if known else "card_locked", 16, Color(0.3, 0.2, 0.15), 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icons := HFlowContainer.new()
	icons.custom_minimum_size = Vector2(150, 0)
	icons.add_theme_constant_override("h_separation", 2)
	row.add_child(icons)
	var content: GameContent = session.content
	var base: DishBaseDefinition = content.get_base(recipe.base_id)
	var main: IngredientDefinition = content.get_ingredient(recipe.main_id)
	for entry in [base.icon_path() if base != null else "", main.icon_path() if main != null else ""]:
		icons.add_child(_icon(str(entry), known))
	if known:
		for herb_id in recipe.herb_ids:
			var herb: IngredientDefinition = content.get_ingredient(str(herb_id))
			if herb != null:
				icons.add_child(_icon(herb.icon_path(), true))
		for property_key in recipe.herb_props:
			icons.add_child(UiKit.chip(Localization.property_name(str(property_key)), Localization.property_color(str(property_key)), 12))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	top.add_child(UiKit.label(Localization.get_text(recipe.name_key) if known else "???", 22, UiKit.GOLD if known else Color(0.7, 0.65, 0.6)))
	top.add_child(UiKit.chip(Localization.get_text("ui.rarity_" + recipe.rarity), _rarity_color(recipe.rarity), 13))
	var desc := UiKit.label(Localization.get_text(recipe.desc_key) if known else Localization.get_text(recipe.hint_key), 15, UiKit.CREAM if known else Color(0.75, 0.7, 0.62))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(220, 0)
	col.add_child(desc)
	if known:
		var stats: Dictionary = session.save_service.save_data.discovered_recipes.get(recipe.id, {})
		var quality_names: Array[String] = [Localization.get_text("result.perfect.title"), Localization.get_text("result.suitable.title"), Localization.get_text("result.wrong.title")]
		var best: int = clampi(int(stats.get("best", 2)), 0, 2)
		var line := "%s · %s · %s" % [Localization.fmt("ui.recipe_cooked", [int(stats.get("count", 1))]), Localization.fmt("ui.quality_best", [quality_names[best]]), Localization.fmt("ui.recipe_bonus_line", [int(round(recipe.reward_bonus * 100.0))])]
		var stat_label := UiKit.label(line, 13, Color(0.9, 0.8, 0.55))
		stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat_label.custom_minimum_size = Vector2(220, 0)
		col.add_child(stat_label)
	return card


func _icon(path: String, visible_icon: bool) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = UiKit.tex(path)
	rect.custom_minimum_size = Vector2(48, 48)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not visible_icon:
		rect.modulate = Color(0.1, 0.1, 0.12, 0.85)
	return rect
