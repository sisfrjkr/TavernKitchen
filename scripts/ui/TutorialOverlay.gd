class_name TutorialOverlay
extends Control
## Короткое обучение: подсвечивает нужную часть интерфейса и объясняет шаг одной фразой.
## Шаги: [{"text": String, "target": Control}]. Можно пропустить.


signal finished

var _steps: Array[Dictionary] = []
var _index: int = 0
var _panel: PanelContainer
var _text: Label
var _counter: Label
var _next: Button
var _skip: Button


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.parchment_panel(18))
	_panel.custom_minimum_size = Vector2(420, 0)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_counter = UiKit.label("", 15, Color(0.5, 0.35, 0.15))
	_counter.add_theme_constant_override("outline_size", 0)
	column.add_child(_counter)
	_text = UiKit.label("", 20, UiKit.INK)
	_text.add_theme_constant_override("outline_size", 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(380, 0)
	column.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	_skip = Button.new()
	_skip.text = Localization.get_text("ui.tutorial_skip")
	_skip.custom_minimum_size = Vector2(0, 50)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.pressed.connect(_finish)
	buttons.add_child(_skip)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(0, 50)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.focus_mode = Control.FOCUS_NONE
	UiKit.make_gold(_next)
	_next.pressed.connect(_on_next)
	buttons.add_child(_next)


func start(steps: Array[Dictionary]) -> void:
	_steps = steps
	_index = 0
	if _steps.is_empty():
		_finish()
		return
	visible = true
	_show_step()


func _show_step() -> void:
	var step: Dictionary = _steps[_index]
	_text.text = str(step["text"])
	_counter.text = "%d / %d" % [_index + 1, _steps.size()]
	_next.text = Localization.get_text("ui.tutorial_done") if _index == _steps.size() - 1 else Localization.get_text("ui.tutorial_next")
	_panel.reset_size()
	await get_tree().process_frame
	_place_panel()
	queue_redraw()


func _on_next() -> void:
	Audio.play_effect("ui_click")
	_index += 1
	if _index >= _steps.size():
		_finish()
	else:
		_show_step()


func _finish() -> void:
	visible = false
	finished.emit()


func _target_rect() -> Rect2:
	if _index >= _steps.size():
		return Rect2()
	var target: Control = _steps[_index].get("target") as Control
	if target == null or not is_instance_valid(target):
		return Rect2()
	return target.get_global_rect().grow(8.0)


## Окно подсказки — на противоположной от цели половине экрана.
func _place_panel() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var rect: Rect2 = _target_rect()
	var size_now: Vector2 = _panel.size
	var x: float = clampf(viewport.x * 0.5 - size_now.x * 0.5, 8.0, maxf(8.0, viewport.x - size_now.x - 8.0))
	var y: float = viewport.y * 0.5 - size_now.y * 0.5
	if rect.size != Vector2.ZERO:
		var target_center: float = rect.position.y + rect.size.y * 0.5
		y = 90.0 if target_center > viewport.y * 0.5 else viewport.y - size_now.y - 40.0
		if y + size_now.y > viewport.y - 8.0:
			y = viewport.y - size_now.y - 8.0
	_panel.position = Vector2(x, maxf(8.0, y))


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## Затемнение всего экрана, кроме выделенной области, и золотая рамка вокруг неё.
func _draw() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var dim := Color(0.04, 0.02, 0.01, 0.72)
	var rect: Rect2 = _target_rect()
	if rect.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, viewport), dim)
		return
	draw_rect(Rect2(0, 0, viewport.x, maxf(0.0, rect.position.y)), dim)
	draw_rect(Rect2(0, rect.end.y, viewport.x, maxf(0.0, viewport.y - rect.end.y)), dim)
	draw_rect(Rect2(0, rect.position.y, maxf(0.0, rect.position.x), rect.size.y), dim)
	draw_rect(Rect2(rect.end.x, rect.position.y, maxf(0.0, viewport.x - rect.end.x), rect.size.y), dim)
	draw_rect(rect, UiKit.GOLD, false, 4.0)
