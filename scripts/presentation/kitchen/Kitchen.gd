class_name Kitchen
extends Node3D
## Медный котёл на очаге: кипящий суп, пузырьки, пар, помешивание, огонь и реакции на блюдо.
## Начало координат — верх каменной площадки очага. Чаша собрана из граней (low-poly) и
## двусторонних материалов, поэтому изнутри и снаружи освещается корректно.


const RIM_Y: float = 1.45
const BOWL_R: float = 0.99
const LIQUID_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 liquid_color : source_color = vec4(0.55, 0.33, 0.18, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float boil = 0.0;
uniform float wobble = 0.0;
uniform float flash = 0.0;
varying vec2 vuv;

void vertex() {
	vuv = UV;
	vec2 p = UV - vec2(0.5);
	float d = length(p);
	float speed = 2.5 + boil * 6.0;
	float w = sin(d * 26.0 - TIME * speed) * (0.012 + boil * 0.025);
	w += sin(p.x * 18.0 + TIME * 2.1) * sin(p.y * 15.0 + TIME * 1.7) * (0.008 + boil * 0.018);
	w += sin(d * 34.0 - TIME * 9.0) * wobble * 0.06 * exp(-d * 3.5);
	VERTEX.y += w;
}

void fragment() {
	vec2 p = vuv - vec2(0.5);
	float d = length(p);
	if (d > 0.5) {
		discard;
	}
	vec2 g = vuv * 10.0;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = fract(sin(dot(id, vec2(12.9898, 78.233))) * 43758.5453);
	float phase = fract(TIME * (0.25 + boil * 0.9) + h);
	float ring = smoothstep(0.05, 0.0, abs(length(f) - phase * 0.42)) * (1.0 - phase) * boil;
	float edge = smoothstep(0.36, 0.5, d);
	vec3 col = mix(liquid_color.rgb, foam_color.rgb, clamp(edge * 0.55 + ring * 0.85, 0.0, 1.0));
	col += vec3(1.0, 0.78, 0.25) * flash * (0.6 + 0.4 * sin(TIME * 12.0 + d * 20.0));
	ALBEDO = col;
	ROUGHNESS = 0.22;
	SPECULAR = 0.65;
	EMISSION = col * (0.1 + flash * 0.7);
}
"""

var _bowl: Node3D
var _liquid: MeshInstance3D
var _liquid_mat: ShaderMaterial
var _model_copper: Node3D
var _model_gold: Node3D
var _steam_soft: CPUParticles3D
var _steam_heavy: CPUParticles3D
var _bubbles: CPUParticles3D
var _splash: CPUParticles3D
var _sparks: CPUParticles3D
var _smoke: CPUParticles3D
var _embers: CPUParticles3D
var _fire_light: OmniLight3D
var _flash_light: OmniLight3D
var _flames: Array[MeshInstance3D] = []
var _flame_phase: Array[float] = []
var _spoon: Node3D

var _time: float = 0.0
var _fill_target: float = 0.0
var _fill: float = 0.0
var _color_target: Color = Color(0.55, 0.33, 0.18)
var _color: Color = Color(0.55, 0.33, 0.18)
var _boil_target: float = 0.0
var _boil: float = 0.0
var _wobble: float = 0.0
var _flash: float = 0.0
var _cooking: bool = false
var _stir_energy: float = 0.0
var _stir_angle: float = 0.0
var _fire_scale: float = 1.0
var _bowl_tween: Tween


func _ready() -> void:
	_build_fire()
	_build_bowl()
	_build_liquid()
	_build_spoon()
	_build_effects()
	_set_fill(0.0)


# --- Сборка ---------------------------------------------------------------------

func _build_bowl() -> void:
	_bowl = Node3D.new()
	_bowl.name = "Bowl"
	add_child(_bowl)
	# Готовые модели: медный и золотой котёл (с ободом, ручками, заклёпками и треножником).
	_model_copper = Props.place(_bowl, "cauldron", Vector3(0, RIM_Y, 0))
	_model_gold = Props.place(_bowl, "cauldron_gold", Vector3(0, RIM_Y, 0))
	_model_gold.visible = false
	if not Props.exists("cauldron"):
		_build_fallback_bowl()


## Запасная чаша из граней — только если модель не импортирована.
func _build_fallback_bowl() -> void:
	var copper := Build.mat(Color(0.8, 0.43, 0.2), 0.32, 0.75)
	copper.cull_mode = BaseMaterial3D.CULL_DISABLED
	var steps: Array[float] = [0.0, 15.0, 30.0, 45.0, 60.0, 75.0]
	for i in steps.size():
		var a0: float = deg_to_rad(steps[i])
		var a1: float = deg_to_rad(steps[i] + 15.0)
		var segment := Build.cyl(_bowl, BOWL_R * cos(a0), BOWL_R * cos(a1), BOWL_R * (sin(a1) - sin(a0)), Vector3(0, RIM_Y - BOWL_R * (sin(a0) + sin(a1)) * 0.5, 0), copper, 16)
		(segment.mesh as CylinderMesh).cap_top = false
		(segment.mesh as CylinderMesh).cap_bottom = false


func _build_liquid() -> void:
	var shader := Shader.new()
	shader.code = LIQUID_SHADER
	_liquid_mat = ShaderMaterial.new()
	_liquid_mat.shader = shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	_liquid = MeshInstance3D.new()
	_liquid.mesh = plane
	_liquid.material_override = _liquid_mat
	_liquid.visible = false
	_bowl.add_child(_liquid)


func _build_spoon() -> void:
	_spoon = Node3D.new()
	_spoon.position = Vector3(0, RIM_Y - 0.3, 0)
	_bowl.add_child(_spoon)
	var arm := Node3D.new()
	arm.position = Vector3(0.42, 0, 0)
	arm.rotation_degrees = Vector3(0, 0, -22)
	_spoon.add_child(arm)
	Props.place(arm, "ladle", Vector3.ZERO)


func _build_fire() -> void:
	Props.place(self, "logs", Vector3(0, 0, 0), 20.0, 0.75)
	var ember := Build.glow(Color(1.0, 0.35, 0.08), 2.2)
	Build.sphere(self, 0.42, Vector3(0, 0.08, 0), ember, Vector3(1.0, 0.25, 1.0), 8)
	var flame_a := Build.glow(Color(1.0, 0.45, 0.08), 2.6)
	var flame_b := Build.glow(Color(1.0, 0.78, 0.22), 3.0)
	flame_a.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_a.albedo_color.a = 0.85
	var positions: Array[Vector3] = [Vector3(0.0, 0, 0.62), Vector3(0.5, 0, 0.42), Vector3(-0.5, 0, 0.42), Vector3(0.0, 0, 0.1), Vector3(0.62, 0, -0.1), Vector3(-0.62, 0, -0.1), Vector3(0.0, 0, -0.55)]
	for i in positions.size():
		var tall: float = 0.55 + 0.12 * float(i % 3)
		var flame := Build.cyl(self, 0.0, 0.17 + 0.03 * float(i % 2), tall, positions[i] + Vector3(0, 0.12 + tall * 0.5, 0), flame_a if i % 2 == 0 else flame_b, 7)
		_flames.append(flame)
		_flame_phase.append(randf() * TAU)
	_fire_light = Build.omni(self, Vector3(0, 0.9, 0.7), Color(1.0, 0.6, 0.28), 3.2, 8.5, false)


func _build_effects() -> void:
	var y: float = RIM_Y
	_steam_soft = Build.puff_particles(self, Vector3(0, y, 0), Color(1, 1, 1, 0.22), 10, 3.0, 0.9, 0.35, 14.0)
	_steam_heavy = Build.puff_particles(self, Vector3(0, y, 0), Color(1, 1, 1, 0.3), 22, 2.2, 1.1, 0.7, 16.0)
	_steam_soft.emitting = false
	_steam_heavy.emitting = false
	_bubbles = Build.spark_particles(self, Vector3(0, y, 0), Color(1, 0.95, 0.8, 0.9), 26, 0.7, 0.07, 0.9, -2.4, false)
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = 0.55
	_bubbles.emitting = false
	_splash = Build.spark_particles(self, Vector3(0, y, 0), Color(1, 0.9, 0.7, 0.95), 26, 0.9, 0.09, 2.4, -7.0, true)
	_sparks = Build.spark_particles(self, Vector3(0, y, 0), Color(1.0, 0.82, 0.3, 1.0), 48, 1.3, 0.09, 4.2, -3.2, true)
	_smoke = Build.puff_particles(self, Vector3(0, y, 0), Color(0.35, 0.33, 0.32, 0.5), 12, 1.8, 1.2, 0.8, 18.0)
	_smoke.emitting = false
	_embers = Build.spark_particles(self, Vector3(0, 0.35, 0), Color(1.0, 0.5, 0.15, 1.0), 14, 1.6, 0.045, 1.1, 0.4, false)
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = 0.5
	_flash_light = Build.omni(self, Vector3(0, y + 0.8, 0.3), Color(1.0, 0.82, 0.35), 0.0, 6.0, false)


# --- Публичное API ---------------------------------------------------------------

## Показывает содержимое котла по выбранному блюду: цвет смешивается из выбранных ингредиентов.
func show_dish(dish: RecipeSelection, content: GameContent) -> void:
	var base: DishBaseDefinition = content.get_base(dish.base_id)
	if base == null:
		_fill_target = 0.0
		return
	var color: Color = base.color
	var fill: float = 0.78
	var main: IngredientDefinition = content.get_ingredient(dish.main_ingredient_id)
	if main != null:
		color = color.lerp(main.color, 0.38)
		fill = 0.86
	var herb1: IngredientDefinition = content.get_ingredient(dish.primary_herb_id)
	if herb1 != null:
		color = color.lerp(herb1.color, 0.22)
		fill = 0.93
	var herb2: IngredientDefinition = content.get_ingredient(dish.optional_herb_id)
	if herb2 != null:
		color = color.lerp(herb2.color, 0.16)
	_color_target = color.darkened(0.12)
	_fill_target = fill


## Реакция на упавший ингредиент: всплеск, пузырьки, колебание содержимого и «приседание» котла.
func on_ingredient_landed(ingredient_color: Color) -> void:
	_wobble = 1.0
	_splash.color_ramp.colors = PackedColorArray([ingredient_color.lightened(0.35), ingredient_color.lightened(0.2), Color(ingredient_color.r, ingredient_color.g, ingredient_color.b, 0.0)])
	_splash.restart()
	_splash.emitting = true
	_bubbles.emitting = true
	get_tree().create_timer(1.1).timeout.connect(func() -> void:
		if not _cooking:
			_bubbles.emitting = false)
	if _bowl_tween != null and _bowl_tween.is_valid():
		_bowl_tween.kill()
	_bowl.scale = Vector3.ONE
	_bowl_tween = create_tween()
	_bowl_tween.tween_property(_bowl, "scale", Vector3(1.04, 0.94, 1.04), 0.08)
	_bowl_tween.tween_property(_bowl, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func set_cooking(active: bool) -> void:
	_cooking = active
	_boil_target = 1.0 if active else (0.18 if _fill_target > 0.0 else 0.0)
	_bubbles.emitting = active
	_steam_heavy.emitting = active
	_stir_energy = 0.0


## Помешивание: ложка ускоряется, содержимое колышется.
func play_stir() -> void:
	_stir_energy = 1.0
	_wobble = maxf(_wobble, 0.5)


## quality — OrderEvaluation.Quality.
func play_result(quality: int) -> void:
	set_cooking(false)
	_boil_target = 0.25
	if quality == OrderEvaluation.Quality.PERFECT:
		_sparks.restart()
		_sparks.emitting = true
		_flash = 1.0
		var tween := create_tween()
		tween.tween_property(_flash_light, "light_energy", 7.0, 0.12)
		tween.tween_property(_flash_light, "light_energy", 0.0, 0.9)
		_steam_soft.emitting = true
		_color_target = _color_target.lerp(Color(1.0, 0.8, 0.35), 0.35)
	elif quality == OrderEvaluation.Quality.SUITABLE:
		_steam_heavy.emitting = true
		get_tree().create_timer(1.2).timeout.connect(func() -> void: _steam_heavy.emitting = false)
	else:
		_smoke.emitting = true
		_color_target = _color_target.lerp(Color(0.3, 0.27, 0.24), 0.6)
		get_tree().create_timer(1.6).timeout.connect(func() -> void: _smoke.emitting = false)


## Визуальные улучшения котла: блеск меди и размер большого котла.
func apply_upgrades(copper: bool, big: bool, hearth: bool) -> void:
	if _model_copper != null:
		_model_copper.visible = not copper
	if _model_gold != null:
		_model_gold.visible = copper
	scale = Vector3.ONE * (1.18 if big else 1.0)
	_fire_scale = 1.35 if hearth else 1.0


## Мировая точка над устьем котла (куда летят ингредиенты).
func mouth_world_position() -> Vector3:
	return to_global(Vector3(0, RIM_Y + 0.1, 0))


# --- Внутреннее -------------------------------------------------------------------

func _set_fill(fraction: float) -> void:
	_fill = fraction
	if fraction <= 0.01:
		_liquid.visible = false
		return
	_liquid.visible = true
	var y_rel: float = lerpf(-0.72 * BOWL_R, -0.12 * BOWL_R, clampf(fraction, 0.0, 1.0))
	var radius: float = sqrt(maxf(0.01, BOWL_R * BOWL_R - y_rel * y_rel)) * 0.97
	_liquid.position = Vector3(0, RIM_Y + y_rel, 0)
	_liquid.scale = Vector3(radius, 1.0, radius)
	_spoon.position.y = RIM_Y + y_rel
	_bubbles.position.y = RIM_Y + y_rel
	_splash.position.y = RIM_Y + y_rel + 0.05
	_steam_soft.position.y = RIM_Y + y_rel + 0.1
	_steam_heavy.position.y = RIM_Y + y_rel + 0.1
	_sparks.position.y = RIM_Y + y_rel + 0.1
	_smoke.position.y = RIM_Y + y_rel + 0.1


func _process(delta: float) -> void:
	_time += delta
	# Плавное заполнение и смена цвета.
	_fill = move_toward(_fill, _fill_target, delta * 1.4)
	if absf(_fill - _fill_target) > 0.001 or _liquid.visible != (_fill > 0.01):
		_set_fill(_fill)
	_color = _color.lerp(_color_target, clampf(delta * 3.0, 0.0, 1.0))
	_boil = move_toward(_boil, _boil_target, delta * 0.8)
	_wobble = move_toward(_wobble, 0.0, delta * 0.9)
	_flash = move_toward(_flash, 0.0, delta * 0.9)
	_liquid_mat.set_shader_parameter("liquid_color", _color)
	_liquid_mat.set_shader_parameter("foam_color", _color.lightened(0.55))
	_liquid_mat.set_shader_parameter("boil", _boil)
	_liquid_mat.set_shader_parameter("wobble", _wobble)
	_liquid_mat.set_shader_parameter("flash", _flash)
	_steam_soft.emitting = _steam_soft.emitting or (_fill > 0.3 and not _cooking)
	if _fill <= 0.01 and not _cooking:
		_steam_soft.emitting = false
	if not _cooking and _boil_target > 0.0 and _fill_target <= 0.0:
		_boil_target = 0.0
	# Ложка: медленно в варке, быстрее после помешивания.
	_stir_energy = move_toward(_stir_energy, 0.0, delta * 0.7)
	var speed: float = 0.4
	if _cooking:
		speed = 1.6 + 7.0 * _stir_energy
	elif _stir_energy > 0.0:
		speed = 0.4 + 7.0 * _stir_energy
	_stir_angle += speed * delta
	_spoon.rotation.y = _stir_angle
	_spoon.visible = _fill > 0.01
	# Огонь.
	for i in _flames.size():
		var flame: MeshInstance3D = _flames[i]
		var k: float = _time * 7.0 + _flame_phase[i]
		var s: float = (0.8 + 0.28 * sin(k) + 0.14 * sin(k * 2.3 + 1.3)) * _fire_scale
		flame.scale = Vector3(1.0, s, 1.0)
		flame.position.y = 0.12 + (flame.mesh as CylinderMesh).height * 0.5 * s
	var flicker: float = 1.0 + 0.16 * sin(_time * 11.0) + 0.1 * sin(_time * 17.3 + 2.0)
	_fire_light.light_energy = 3.2 * flicker * _fire_scale
