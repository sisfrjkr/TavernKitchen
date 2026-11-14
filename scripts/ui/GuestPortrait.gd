class_name GuestPortrait
extends Control
## Живой 2D-портрет гостя: моргание, покачивание, нетерпение, радость и разочарование.
## Работает на готовых PNG-выражениях (calm / blink / happy / sad / surprised), без скелетной анимации.


var customer_id: String = ""
var _image: TextureRect
var _time: float = 0.0
var _blink_timer: float = 2.5
var _blink_until: float = -1.0
var _reaction_until: float = -1.0
var _reaction_expression: String = "calm"
var _impatience: float = 0.0
var _current_expression: String = ""
# Анимируемые смещения (меняются Tween-ами).
var _extra_y: float = 0.0
var _extra_scale: float = 1.0
var _extra_rot: float = 0.0
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(140, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	if _image == null:
		return
	_image.size = size
	_image.pivot_offset = size * Vector2(0.5, 0.95)


func set_guest(customer: CustomerDefinition) -> void:
	customer_id = customer.id
	_impatience = 0.0
	_reaction_until = -1.0
	_current_expression = ""
	_blink_timer = randf_range(1.5, 3.5)
	_apply_expression("calm")
	_extra_y = 24.0
	_extra_scale = 0.9
	_extra_rot = 0.0
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "_extra_y", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_extra_scale", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## ratio: 0 — гость спокоен, 1 — терпение на исходе.
func set_impatience(ratio: float) -> void:
	_impatience = clampf(ratio, 0.0, 1.0)


## kind: "happy", "sad" или "surprised".
func react(kind: String) -> void:
	_reaction_expression = kind
	_reaction_until = _time + 3.0
	_kill_tween()
	_tween = create_tween()
	if kind == "happy":
		_tween.tween_property(self, "_extra_y", -20.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "_extra_y", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "_extra_y", -10.0, 0.12).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "_extra_y", 0.0, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	elif kind == "sad":
		_tween.set_parallel(true)
		_tween.tween_property(self, "_extra_scale", 0.93, 0.35)
		_tween.tween_property(self, "_extra_rot", -0.06, 0.35)
		_tween.tween_property(self, "_extra_y", 8.0, 0.35)
	else:
		_tween.tween_property(self, "_extra_scale", 1.1, 0.12)
		_tween.tween_property(self, "_extra_scale", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func reset_pose() -> void:
	_kill_tween()
	_extra_y = 0.0
	_extra_scale = 1.0
	_extra_rot = 0.0
	_reaction_until = -1.0


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _process(delta: float) -> void:
	if _image == null or customer_id == "":
		return
	_time += delta
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_until = _time + 0.13
		_blink_timer = randf_range(2.2, 4.6)
	var expression: String = "calm"
	if _time < _reaction_until:
		expression = _reaction_expression
	elif _time < _blink_until:
		expression = "blink"
	elif _impatience > 0.7:
		expression = "sad"
	_apply_expression(expression)
	# Дыхание, покачивание головой; при нетерпении движения чаще.
	var rate: float = 1.0 + _impatience * 3.0
	var bob: float = sin(_time * 1.7 * rate) * (2.0 + _impatience * 1.5)
	var sway: float = sin(_time * 0.9 * rate) * (0.025 + _impatience * 0.03)
	_image.position = Vector2(0.0, bob + _extra_y)
	_image.rotation = sway + _extra_rot
	_image.scale = Vector2.ONE * (_extra_scale * (1.0 + sin(_time * 1.7) * 0.008))


func _apply_expression(expression: String) -> void:
	if expression == _current_expression:
		return
	_current_expression = expression
	_image.texture = UiKit.tex("res://assets/guests/%s_%s.png" % [customer_id, expression])
