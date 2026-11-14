class_name Tavern
extends Node3D
## 2.5D-диорама таверны в стиле уютного low-poly фэнтези.
##
## Система координат: пол — y=0, задняя стена — z≈-3.7, камера смотрит в сторону -Z.
## Котёл стоит на каменной площадке очага в центре; слева — полки и бочки, справа — окно с дождём и стойка.
## Камера рассчитывается из «видимой ширины» сцены в плоскости котла, поэтому композиция
## одинакова на любом соотношении сторон: на широком экране виден весь зал, на узком — котёл и очаг.


const KITCHEN_POS: Vector3 = Vector3(0.0, 0.35, 0.6)
## Всё «заднее» помещение (камин, окно, полки, стойка) строится в локальных координатах и сдвигается назад.
const BACK_Z: float = -5.0
const WALL_Z: float = -3.7
const ROOM_H: float = 5.2

var kitchen: Kitchen
var camera: Camera3D

var _back: Node3D
## Объекты, видимые только на определённых этапах таверны: {node, min, max}.
var _stage_nodes: Array[Dictionary] = []
var _stage: int = 1
var _fill_light: OmniLight3D
var _celebrating: bool = false
var _crowd: Array[Dictionary] = []
var _crowd_target: int = 2

var _groups: Dictionary = {}
var _mats: Dictionary = {}
var _time: float = 0.0
var _candle_flames: Array[Node3D] = []
var _candle_lights: Array[OmniLight3D] = []
var _lantern_nodes: Array[Node3D] = []
var _lantern_lights: Array[OmniLight3D] = []
var _hang_nodes: Array[Node3D] = []
var _window_light: SpotLight3D
var _sky_mat: StandardMaterial3D
var _lightning_timer: float = 14.0
var _back_flames: Array[MeshInstance3D] = []
var _back_flame_phase: Array[float] = []
var _back_fire_light: OmniLight3D
var _narrow: bool = false
var _menu_view: bool = true
var _cam_now: Dictionary = {}
var _cam_goal: Dictionary = {}


func _ready() -> void:
	kitchen = get_node_or_null("Kitchen") as Kitchen
	if kitchen == null:
		kitchen = Kitchen.new()
		kitchen.name = "Kitchen"
		add_child(kitchen)
	kitchen.position = KITCHEN_POS
	_back = Node3D.new()
	_back.name = "Back"
	_back.position = Vector3(0.0, 0.0, BACK_Z)
	add_child(_back)
	_make_materials()
	_build_environment()
	_build_room()
	_build_island()
	_build_hearth()
	_build_back_fire()
	_build_window()
	_build_shelves()
	_build_props()
	_build_counter()
	_build_tables()
	_build_lanterns()
	_build_decor()
	_build_candles()
	_build_crowd()
	_build_stages()
	_build_atmosphere()
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 60.0
	camera.near = 0.2
	camera.far = 60.0
	add_child(camera)
	camera.current = true
	_cam_goal = _camera_params()
	_cam_now = _cam_goal.duplicate()
	_apply_camera(0.0)
	get_viewport().size_changed.connect(func() -> void: _apply_camera(0.0))


# --- Камера ------------------------------------------------------------------------

func set_layout(narrow: bool) -> void:
	_narrow = narrow
	_cam_goal = _camera_params()


## В меню камера отъезжает и показывает весь зал; в игре — крупно котёл.
func set_menu_view(menu: bool) -> void:
	_menu_view = menu
	_cam_goal = _camera_params()


func _camera_params() -> Dictionary:
	if _celebrating and not _menu_view:
		if _narrow:
			return {"vis_w": 6.4, "frac_y": 0.42, "pitch": 12.0, "target_y": 1.8}
		return {"vis_w": 12.0, "frac_y": 0.46, "pitch": 11.0, "target_y": 1.9}
	if _menu_view:
		if _narrow:
			return {"vis_w": 7.0, "frac_y": 0.5, "pitch": 10.0, "target_y": 1.9}
		return {"vis_w": 12.5, "frac_y": 0.5, "pitch": 9.0, "target_y": 1.9}
	if _narrow:
		return {"vis_w": 4.8, "frac_y": 0.37, "pitch": 17.0, "target_y": 1.4}
	return {"vis_w": 9.0, "frac_y": 0.44, "pitch": 17.0, "target_y": 1.5}


func _apply_camera(delta: float) -> void:
	if camera == null:
		return
	if delta > 0.0:
		var k: float = 1.0 - exp(-delta * 2.5)
		for key in _cam_goal:
			_cam_now[key] = lerpf(float(_cam_now[key]), float(_cam_goal[key]), k)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return
	var vis_w: float = float(_cam_now["vis_w"])
	var vis_h: float = vis_w * viewport_size.y / viewport_size.x
	var distance: float = vis_w / (2.0 * tan(deg_to_rad(camera.fov * 0.5)))
	var pitch: float = deg_to_rad(float(_cam_now["pitch"]))
	var up: Vector3 = Vector3(0.0, cos(pitch), -sin(pitch))
	var target: Vector3 = Vector3(0.0, float(_cam_now["target_y"]), KITCHEN_POS.z)
	# Смещаем точку прицеливания, чтобы цель оказалась на нужной доле высоты экрана.
	var aim: Vector3 = target + up * (float(_cam_now["frac_y"]) - 0.5) * vis_h
	var sway: Vector3 = Vector3(sin(_time * 0.35) * 0.04, sin(_time * 0.27) * 0.025, 0.0)
	var pos: Vector3 = aim + Vector3(0.0, sin(pitch), cos(pitch)) * distance + sway
	camera.position = pos
	camera.look_at(aim + sway * 0.5, Vector3.UP)


## Позиции в мире для позиционного звука: места посетителей, дверь, стойка, котёл.
func audio_positions() -> Dictionary:
	var seats: Array[Vector3] = []
	for entry in _crowd:
		seats.append((entry["base"] as Vector3) + Vector3(0, -0.3, 0))
	return {
		"seats": seats,
		"door": Vector3(7.8, 1.0, WALL_Z + BACK_Z),
		"counter": Vector3(3.2, 1.0, -3.1 + BACK_Z),
		"cauldron": kitchen.mouth_world_position() if kitchen != null else KITCHEN_POS + Vector3(0, 1.4, 0),
	}


## Экранная позиция устья котла (в логических координатах интерфейса).
func cauldron_screen_position() -> Vector2:
	if camera == null or kitchen == null:
		return Vector2(640, 260)
	return camera.unproject_position(kitchen.mouth_world_position())


# --- Материалы и окружение -----------------------------------------------------------

func _make_materials() -> void:
	_mats["planks"] = Build.textured("res://assets/textures/planks.png", Color(0.95, 0.85, 0.75), 0.33)
	_mats["plaster"] = Build.textured("res://assets/textures/plaster.png", Color(1.0, 0.88, 0.75), 0.4)
	_mats["stone"] = Build.textured("res://assets/textures/stone.png", Color(1.0, 0.92, 0.88), 0.5)
	_mats["beam"] = Build.textured("res://assets/textures/beam.png", Color(0.75, 0.6, 0.5), 0.7)
	_mats["table"] = Build.textured("res://assets/textures/table_wood.png", Color(1, 0.92, 0.85), 0.8)
	_mats["wood_dark"] = Build.mat(Color(0.28, 0.17, 0.1), 0.9)
	_mats["wood"] = Build.mat(Color(0.5, 0.33, 0.19), 0.9)
	_mats["iron"] = Build.mat(Color(0.18, 0.17, 0.17), 0.6, 0.5)
	_mats["copper"] = Build.mat(Color(0.82, 0.46, 0.22), 0.3, 0.7)
	_mats["cloth_red"] = Build.mat(Color(0.7, 0.18, 0.15), 0.95)
	_mats["cloth_cream"] = Build.mat(Color(0.93, 0.88, 0.76), 0.95)
	_mats["sack"] = Build.mat(Color(0.72, 0.6, 0.4), 1.0)
	_mats["green"] = Build.mat(Color(0.3, 0.5, 0.22), 0.95)
	_mats["glass"] = Build.mat(Color(0.5, 0.75, 0.6, 0.85), 0.2)
	(_mats["glass"] as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats["candle"] = Build.mat(Color(0.95, 0.9, 0.75), 0.8)
	_mats["flame"] = Build.glow(Color(1.0, 0.75, 0.3), 3.0)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.035, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.34, 0.4)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.36, 0.5)
	env.fog_density = 0.006
	world.environment = env
	add_child(world)
	# Мягкий общий тёплый свет зала.
	_fill_light = Build.omni(self, Vector3(0, 3.6, 1.5), Color(1.0, 0.78, 0.55), 0.8, 18.0, false)
	# Холодный свет из окна: мягкие тени от рамы.
	_window_light = SpotLight3D.new()
	add_child(_window_light)
	_window_light.light_color = Color(0.55, 0.7, 1.0)
	_window_light.light_energy = 2.3
	_window_light.spot_range = 13.0
	_window_light.spot_angle = 40.0
	_window_light.shadow_enabled = true
	_window_light.look_at_from_position(Vector3(3.2, 3.0, -8.1), Vector3(0.0, 0.0, -2.0), Vector3.UP)


func _group(group_name: String, in_world: bool = false) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	node.visible = false
	if in_world:
		add_child(node)
	else:
		_back.add_child(node)
	_groups[group_name] = node
	return node


# --- Зал ------------------------------------------------------------------------------

func _build_room() -> void:
	# Замкнутая комната: пол, потолок, три стены и невидимая передняя стена за камерой.
	# Камера всегда внутри — лучи не могут уйти в «пустоту» и дать чёрный фон.
	var z0: float = -9.0
	var z1: float = 18.0
	var depth: float = z1 - z0
	var zc: float = (z0 + z1) * 0.5
	Build.box(self, Vector3(24, 0.3, depth), Vector3(0, -0.15, zc), _mats["planks"])
	Build.box(self, Vector3(24, 0.3, depth), Vector3(0, ROOM_H + 0.15, zc), _mats["beam"])
	Build.box(self, Vector3(0.3, ROOM_H, depth), Vector3(-12.0, ROOM_H * 0.5, zc), _mats["plaster"])
	Build.box(self, Vector3(0.3, ROOM_H, depth), Vector3(12.0, ROOM_H * 0.5, zc), _mats["plaster"])
	Build.box(self, Vector3(24, ROOM_H, 0.3), Vector3(0, ROOM_H * 0.5, z1), _mats["plaster"])
	# Потолочные балки поперёк зала.
	for z in [-7.0, -3.5, 0.0, 3.5, 7.0]:
		Build.box(self, Vector3(24, 0.4, 0.4), Vector3(0, ROOM_H - 0.2, z), _mats["beam"])
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		Build.box(self, Vector3(0.36, 0.36, depth), Vector3(x, ROOM_H - 0.55, zc), _mats["beam"])
	# Задняя стена с проёмом окна (x от 2.3 до 4.1, y от 1.5 до 3.5) — в локальных координатах _back.
	var wall_z: float = WALL_Z - 0.15
	Build.box(_back, Vector3(13.3, ROOM_H, 0.3), Vector3(-4.35, ROOM_H * 0.5, wall_z), _mats["plaster"])
	Build.box(_back, Vector3(6.9, ROOM_H, 0.3), Vector3(7.55, ROOM_H * 0.5, wall_z), _mats["plaster"])
	Build.box(_back, Vector3(1.8, 1.5, 0.3), Vector3(3.2, 0.75, wall_z), _mats["plaster"])
	Build.box(_back, Vector3(1.8, ROOM_H - 3.5, 0.3), Vector3(3.2, 3.5 + (ROOM_H - 3.5) * 0.5, wall_z), _mats["plaster"])
	# Каркас задней стены.
	for x in [-9.0, -6.2, -1.9, 1.9, 4.6, 6.4, 9.0]:
		Build.box(_back, Vector3(0.34, ROOM_H, 0.36), Vector3(x, ROOM_H * 0.5, WALL_Z + 0.05), _mats["beam"])
	Build.box(_back, Vector3(24, 0.36, 0.38), Vector3(0, 4.6, WALL_Z + 0.05), _mats["beam"])
	Build.box(_back, Vector3(24, 0.3, 0.38), Vector3(0, 0.12, WALL_Z + 0.05), _mats["beam"])
	# Ковёр перед очагом приготовления.
	Build.box(self, Vector3(5.0, 0.025, 3.6), Vector3(0, 0.012, 1.0), Build.mat(Color(0.55, 0.38, 0.16), 1.0))
	Build.box(self, Vector3(4.6, 0.035, 3.2), Vector3(0, 0.02, 1.0), Build.mat(Color(0.52, 0.14, 0.13), 1.0))
	Build.box(self, Vector3(3.6, 0.04, 2.2), Vector3(0, 0.03, 1.0), Build.mat(Color(0.78, 0.55, 0.2), 1.0))
	Build.box(self, Vector3(3.2, 0.05, 1.8), Vector3(0, 0.035, 1.0), Build.mat(Color(0.4, 0.1, 0.12), 1.0))


func _build_island() -> void:
	# Рабочее место: каменный очаг под котлом и два разделочных стола с продуктами.
	var island_z: float = KITCHEN_POS.z
	Build.box(self, Vector3(3.6, 0.35, 3.2), Vector3(0, 0.175, island_z), _mats["stone"])
	for k in 10:
		var a: float = TAU * float(k) / 10.0
		Props.place_scaled(self, "hearth_stone", Vector3(cos(a) * 1.85, 0.0, island_z + sin(a) * 1.65), -rad_to_deg(a), Vector3(0.9, 0.9, 0.9))
	# Левый стол: разделка.
	var left := Vector3(-3.4, 0.0, island_z + 0.2)
	Props.place(self, "table_long", left, 0.0, 1.0)
	Props.place(self, "steak", left + Vector3(-0.6, 0.9, 0.1), 15.0)
	Props.place(self, "tomato", left + Vector3(0.1, 0.9, -0.15))
	Props.place(self, "tomato", left + Vector3(0.28, 0.9, 0.1), 40.0)
	Props.place(self, "cabbage", left + Vector3(0.65, 0.9, -0.1))
	Props.place(self, "mushrooms", left + Vector3(-0.1, 0.9, 0.25), 20.0)
	Props.place(self, "onion", left + Vector3(0.95, 0.9, 0.2))
	Props.place(self, "carrot_bunch", left + Vector3(-0.95, 0.93, -0.15), 70.0, 1.0, Vector3(0, 0, 90))
	Props.place(self, "basket_veg", Vector3(-5.0, 0.0, island_z + 0.5), 20.0)
	# Правый стол: баночки со специями, фонарь и кружка.
	var right := Vector3(3.3, 0.0, island_z + 0.2)
	Props.place(self, "table_long", right, 0.0, 1.0)
	Props.place(self, "jar_clay", right + Vector3(-0.6, 0.9, 0.0))
	Props.place(self, "jar_glass", right + Vector3(-0.25, 0.9, 0.12))
	Props.place(self, "bottle_amber", right + Vector3(0.1, 0.9, -0.1))
	Props.place(self, "bottle_green", right + Vector3(0.3, 0.9, 0.12))
	Props.place(self, "mug", right + Vector3(0.7, 0.9, 0.05), 30.0)
	Props.place(self, "lantern", right + Vector3(-0.95, 0.9, -0.1))
	Props.place(self, "crate", Vector3(5.1, 0.0, island_z + 0.3), 12.0, 0.9)
	Props.place(self, "sack", Vector3(4.55, 0.0, island_z + 1.1), -20.0)
	Props.place(self, "logs", Vector3(-2.2, 0.0, island_z + 1.9), 90.0, 0.8)


func _build_back_fire() -> void:
	# Большой камин в глубине зала: настоящий огонь, свет и дымок.
	var base := Vector3(0.0, 0.35, -2.3)
	Props.place(_back, "logs", base + Vector3(0, 0, 0.1), 90.0, 1.2)
	Build.sphere(_back, 0.7, base + Vector3(0, 0.08, 0), Build.glow(Color(1.0, 0.35, 0.08), 2.0), Vector3(1.3, 0.22, 0.8), 8)
	var flame_a := Build.glow(Color(1.0, 0.45, 0.08), 2.4)
	var flame_b := Build.glow(Color(1.0, 0.78, 0.22), 2.8)
	for i in 6:
		var tall: float = 0.7 + 0.2 * float(i % 3)
		var flame := Build.cyl(_back, 0.0, 0.2, tall, base + Vector3(-0.7 + float(i) * 0.28, 0.15 + tall * 0.5, 0.0), flame_a if i % 2 == 0 else flame_b, 7)
		_back_flames.append(flame)
		_back_flame_phase.append(randf() * TAU)
	_back_fire_light = Build.omni(_back, base + Vector3(0, 0.9, 0.9), Color(1.0, 0.58, 0.25), 2.6, 11.0, false)
	var sparks := Build.spark_particles(_back, base + Vector3(0, 0.6, 0), Color(1.0, 0.6, 0.2, 1.0), 14, 1.8, 0.04, 1.2, 0.3, false)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(0.7, 0.05, 0.2)
	var smoke := Build.puff_particles(_back, Vector3(0, 3.3, WALL_Z + 0.6), Color(0.6, 0.58, 0.56, 0.16), 6, 4.0, 0.9, 0.25, 12.0)
	smoke.emitting = true



func _build_hearth() -> void:
	# Каменная площадка и ступенька.
	Build.box(_back, Vector3(4.6, 0.35, 2.8), Vector3(0, 0.175, -2.3), _mats["stone"])
	Build.box(_back, Vector3(4.9, 0.12, 0.5), Vector3(0, 0.06, -0.78), _mats["stone"])
	# Закопчённая ниша и тёплое свечение.
	Build.box(_back, Vector3(3.2, 2.8, 0.08), Vector3(0, 1.75, WALL_Z + 0.05), Build.mat(Color(0.2, 0.13, 0.1), 1.0))
	for i in 4:
		var s: float = 2.6 - float(i) * 0.55
		Build.quad(_back, Vector2(s * 1.1, s), Vector3(0, 0.9 + float(i) * 0.12, WALL_Z + 0.12 + float(i) * 0.005), _unlit_alpha(Color(1.0, 0.5, 0.15, 0.16)))
	# Каменные косяки, перемычка, полка-мантия и дымоход.
	for side in [-1.0, 1.0]:
		Build.box(_back, Vector3(0.55, 2.9, 0.7), Vector3(side * 1.75, 1.75, WALL_Z + 0.3), _mats["stone"])
		Build.box(_back, Vector3(0.7, 0.3, 0.8), Vector3(side * 1.75, 0.5, WALL_Z + 0.35), _mats["stone"])
	Build.box(_back, Vector3(4.2, 0.55, 0.8), Vector3(0, 3.0, WALL_Z + 0.35), _mats["stone"])
	Build.box(_back, Vector3(4.8, 0.2, 1.05), Vector3(0, 3.38, WALL_Z + 0.45), _mats["wood_dark"])
	Build.box(_back, Vector3(3.0, 1.7, 0.6), Vector3(0, 4.3, WALL_Z + 0.25), _mats["stone"])
	# Предметы на полке: банки, кружки, пучки трав.
	Props.place(_back, "jar_clay", Vector3(-1.9, 3.48, WALL_Z + 0.5), 30.0)
	Props.place(_back, "bottle_blue", Vector3(-1.5, 3.48, WALL_Z + 0.55), 80.0)
	Props.place(_back, "jar_glass", Vector3(1.55, 3.48, WALL_Z + 0.5), 10.0)
	Props.place(_back, "mug", Vector3(1.1, 3.48, WALL_Z + 0.6), -30.0)
	Props.place(_back, "bowl", Vector3(-0.2, 3.48, WALL_Z + 0.6))
	for k in 3:
		var bundle := Props.place(_back, "herb_bundle", Vector3(-0.6 + float(k) * 0.55, 3.32, WALL_Z + 0.95), float(k) * 60.0)
		_hang_nodes.append(bundle)
	# Улучшение «Уютный камин»: широкая кладка, дымовой колпак, подвесной медный чайник.
	var hearth := _group("hearth")
	Build.box(hearth, Vector3(5.6, 0.4, 0.9), Vector3(0, 2.75, WALL_Z + 0.4), _mats["stone"])
	for side in [-1.0, 1.0]:
		Build.box(hearth, Vector3(0.7, 3.6, 0.9), Vector3(side * 2.35, 1.8, WALL_Z + 0.45), _mats["stone"])
		Build.box(hearth, Vector3(0.9, 0.2, 1.0), Vector3(side * 2.35, 3.7, WALL_Z + 0.5), _mats["wood_dark"])
	Build.box(hearth, Vector3(3.6, 0.12, 0.5), Vector3(0, 0.38, -0.95), _mats["stone"])
	Build.cyl(hearth, 0.04, 0.04, 1.2, Vector3(-1.45, 2.1, -3.2), _mats["iron"], 6)
	Build.box(hearth, Vector3(1.3, 0.06, 0.06), Vector3(-0.85, 2.7, -3.2), _mats["iron"])
	Props.place(hearth, "pot_hang", Vector3(-1.1, 2.35, -3.15), 0.0, 1.1)


func _unlit_alpha(color: Color) -> StandardMaterial3D:
	return Build.unlit(color)


func _build_window() -> void:
	# Вид наружу: ночной город; дождь идёт между стеной и «небом».
	var sky := Build.unlit(Color.WHITE)
	sky.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	sky.albedo_texture = UiKit.tex("res://assets/textures/window_view.png")
	_sky_mat = sky
	Build.quad(_back, Vector2(5.0, 5.2), Vector3(3.4, 2.3, -5.4), sky)
	# Рама, перекладины и подоконник.
	var frame: Material = _mats["beam"]
	Build.box(_back, Vector3(0.12, 2.1, 0.22), Vector3(2.25, 2.5, WALL_Z + 0.02), frame)
	Build.box(_back, Vector3(0.12, 2.1, 0.22), Vector3(4.15, 2.5, WALL_Z + 0.02), frame)
	Build.box(_back, Vector3(2.0, 0.12, 0.22), Vector3(3.2, 3.52, WALL_Z + 0.02), frame)
	Build.box(_back, Vector3(2.0, 0.12, 0.22), Vector3(3.2, 1.48, WALL_Z + 0.02), frame)
	Build.box(_back, Vector3(0.07, 2.0, 0.1), Vector3(3.2, 2.5, WALL_Z + 0.02), frame)
	Build.box(_back, Vector3(1.85, 0.07, 0.1), Vector3(3.2, 2.5, WALL_Z + 0.02), frame)
	Build.box(_back, Vector3(2.3, 0.1, 0.6), Vector3(3.2, 1.46, WALL_Z + 0.3), _mats["wood_dark"])
	# Стекло с лёгким голубым отблеском.
	Build.quad(_back, Vector2(1.85, 2.0), Vector3(3.2, 2.5, WALL_Z + 0.0), Build.unlit(Color(0.6, 0.75, 1.0, 0.07)))
	# Дождь за окном.
	var rain := CPUParticles3D.new()
	rain.position = Vector3(3.3, 4.2, -4.4)
	rain.amount = 110
	rain.lifetime = 0.65
	rain.preprocess = 1.0
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(2.2, 0.1, 0.5)
	rain.direction = Vector3(-0.12, -1, 0)
	rain.spread = 3.0
	rain.gravity = Vector3(0, -10, 0)
	rain.initial_velocity_min = 4.5
	rain.initial_velocity_max = 6.0
	var drop := QuadMesh.new()
	drop.size = Vector2(0.014, 0.26)
	var drop_mat := Build.unlit(Color(0.75, 0.86, 1.0, 0.55))
	drop.material = drop_mat
	rain.mesh = drop
	_back.add_child(rain)
	# Занавески по бокам окна.
	for side in [-1.0, 1.0]:
		Build.box(_back, Vector3(0.32, 2.0, 0.05), Vector3(3.2 + side * 0.98, 2.45, WALL_Z + 0.2), Build.mat(Color(0.62, 0.22, 0.2), 1.0), Vector3(0, 0, side * 3.0))


func _build_shelves() -> void:
	var x0: float = -3.9
	var bottles: Array[String] = ["bottle_green", "bottle_red", "bottle_blue", "bottle_amber", "bottle_purple"]
	for y in [2.45, 3.25]:
		Props.place(_back, "shelf", Vector3(x0, y, WALL_Z + 0.3))
	for i in 8:
		Props.place(_back, bottles[i % bottles.size()], Vector3(x0 - 1.25 + float(i) * 0.36, 2.485, WALL_Z + 0.36), float(i) * 37.0)
	for i in 5:
		Props.place(_back, "jar_clay" if i % 2 == 0 else "jar_glass", Vector3(x0 - 1.1 + float(i) * 0.55, 3.285, WALL_Z + 0.36), float(i) * 23.0)
	# Улучшение «Новые полки»: ещё ярус, корзины, ящик и кувшины.
	var more := _group("shelves")
	Props.place(more, "shelf", Vector3(x0, 1.65, WALL_Z + 0.3))
	for i in 4:
		Props.place(more, ["basket_veg", "basket_apples", "basket_bread", "basket_veg"][i], Vector3(x0 - 1.0 + float(i) * 0.7, 1.685, WALL_Z + 0.36), float(i) * 31.0, 0.75)
	Props.place(more, "crate", Vector3(x0 - 2.1, 0.0, WALL_Z + 0.4), 8.0, 0.9)
	Props.place(more, "jug", Vector3(x0 - 2.1, 0.66, WALL_Z + 0.4), 20.0)
	Props.place(more, "barrel", Vector3(x0 - 2.9, 0.0, WALL_Z + 0.45), 0.0, 0.9)


func _build_props() -> void:
	for p in [Vector3(-5.8, 0.0, -2.9), Vector3(-5.0, 0.0, -3.05)]:
		Props.place(_back, "barrel", p, p.x * 40.0)
	Props.place(_back, "sack", Vector3(-3.0, 0.0, -3.1), 15.0)
	Props.place(_back, "sack", Vector3(-2.5, 0.0, -2.8), -40.0, 0.9)
	Props.place(_back, "crate", Vector3(-6.7, 0.0, -2.9), 12.0)
	_stage_reg(Props.place(_back, "crate", Vector3(-6.65, 0.66, -2.9), -22.0, 0.8), 2)
	Props.place(_back, "crate", Vector3(5.7, 0.0, -3.0), -8.0)
	Props.place(_back, "basket_veg", Vector3(-1.9, 0.0, -1.1), 25.0)
	_stage_reg(Props.place(_back, "basket_apples", Vector3(5.1, 0.0, -1.5), -15.0), 2)
	Props.place(_back, "broom", Vector3(-6.4, 0.0, -3.4), 0.0, 1.0, Vector3(0, 0, 6))
	Props.place(_back, "bucket", Vector3(6.4, 0.0, -2.2), 0.0)
	Props.place(_back, "door", Vector3(7.8, 0.0, WALL_Z + 0.16))
	_stage_reg(Props.place(_back, "plant", Vector3(5.1, 0.0, -3.2)), 2)
	_stage_reg(Props.place(_back, "plant", Vector3(-1.5, 0.0, -3.3), 40.0, 0.9), 2)
	_stage_reg(Props.place(_back, "pan", Vector3(2.0, 2.7, WALL_Z + 0.14), 0.0, 1.0, Vector3(90, 0, 0)), 2)
	_stage_reg(Props.place(_back, "pot_hang", Vector3(2.0, 2.1, WALL_Z + 0.2), 0.0, 1.0, Vector3(90, 0, 0)), 2)


func _build_counter() -> void:
	# Стойка под окном — архитектура (доски), на ней — модели посуды и еды.
	Build.box(_back, Vector3(2.4, 0.95, 0.8), Vector3(3.2, 0.475, -3.15), _mats["wood"])
	Build.box(_back, Vector3(2.6, 0.1, 0.95), Vector3(3.2, 0.98, -3.12), _mats["table"])
	var top: float = 1.03
	Props.place(_back, "mug", Vector3(2.4, top, -3.0), 20.0)
	Props.place(_back, "mug", Vector3(2.7, top, -3.15), -30.0)
	Props.place(_back, "jug", Vector3(3.0, top, -3.3), 10.0)
	Props.place(_back, "bowl", Vector3(3.5, top, -3.0))
	Props.place(_back, "bread", Vector3(3.9, top, -3.2), 25.0)
	Props.place(_back, "cheese", Vector3(3.75, top, -2.85), 0.0, 0.8)
	var nice := _group("counter")
	Build.box(nice, Vector3(2.8, 0.06, 1.05), Vector3(3.2, 1.06, -3.1), _mats["copper"])
	Build.box(nice, Vector3(2.5, 0.2, 0.06), Vector3(3.2, 0.55, -2.72), _mats["wood_dark"])
	Props.place(nice, "stool", Vector3(2.4, 0.0, -2.2), 0.0, 1.1)
	Props.place(nice, "stool", Vector3(4.0, 0.0, -2.2), 0.0, 1.1)
	Props.place(nice, "basket_bread", Vector3(2.6, 1.12, -3.35), 15.0, 0.6)
	Props.place(nice, "candle", Vector3(3.0, 1.12, -2.9))
	_add_flame(nice, Vector3(3.0, 1.12 + 0.34, -2.9))


func _build_tables() -> void:
	# Столы с посетителями (мировые координаты).
	for x in [-2.4, 2.4]:
		var t := Vector3(x, 0.0, -4.2)
		Props.place(self, "table_round", t)
		_stage_reg(Props.place(self, "chair", t + Vector3(-0.5, 0.0, -0.95), 0.0), 1, 2)
		_stage_reg(Props.place(self, "chair", t + Vector3(0.5, 0.0, -0.95), 0.0), 1, 2)
		Props.place(self, "stool", t + Vector3(-0.7, 0.0, 0.85), 0.0)
		Props.place(self, "stool", t + Vector3(0.7, 0.0, 0.85), 0.0)
		Props.place(self, "mug", t + Vector3(-0.3, 0.9, 0.1), 40.0)
		Props.place(self, "mug", t + Vector3(0.3, 0.9, -0.05), -20.0)
		Props.place(self, "plate", t + Vector3(0.0, 0.9, 0.3))
		Props.place(self, "candle", t + Vector3(0.0, 0.9, -0.2))
		_add_flame(self, t + Vector3(0.0, 0.9 + 0.34, -0.2))
	# Улучшение «Улучшенные столы»: скатерти и ещё один стол.
	var upgraded := _group("tables", true)
	for x in [-2.4, 2.4]:
		Props.place(upgraded, "table_round_cloth", Vector3(x, 0.0, -4.2))
	var extra := Vector3(-6.4, 0.0, -5.6)
	Props.place(upgraded, "table_round_cloth", extra)
	Props.place(upgraded, "chair", extra + Vector3(-0.5, 0.0, -0.95), 0.0)
	Props.place(upgraded, "chair", extra + Vector3(0.5, 0.0, -0.95), 0.0)
	Props.place(upgraded, "mug", extra + Vector3(0.1, 0.93, 0.1), 30.0)
	Props.place(upgraded, "basket_bread", extra + Vector3(-0.3, 0.93, 0.0), 0.0, 0.5)


func _build_lanterns() -> void:
	var group := _group("lanterns", true)
	for x in [-2.8, 2.8]:
		var lantern := Node3D.new()
		lantern.position = Vector3(x, 3.4, -3.5)
		group.add_child(lantern)
		Props.place(lantern, "lantern", Vector3(0, 0, 0))
		Build.cyl(lantern, 0.012, 0.012, 1.0, Vector3(0, 1.12, 0), _mats["iron"], 4)
		var light := Build.omni(lantern, Vector3(0, 0.25, 0.1), Color(1.0, 0.74, 0.4), 1.2, 6.0, false)
		_lantern_nodes.append(lantern)
		_lantern_lights.append(light)


func _build_crowd() -> void:
	var seats: Array[Vector3] = [Vector3(-2.9, 1.42, -4.9), Vector3(1.9, 1.42, -4.9), Vector3(-1.8, 1.42, -4.9), Vector3(3.0, 1.42, -4.9), Vector3(-7.0, 1.42, -6.3), Vector3(-5.8, 1.42, -6.3)]
	var ids: Array[String] = ["customer_hunter", "customer_dwarf", "customer_merchant", "customer_forest_nomad", "customer_elf", "customer_city_cook"]
	for i in seats.size():
		var sprite := Sprite3D.new()
		sprite.texture = UiKit.tex("res://assets/guests/%s_calm.png" % ids[i])
		sprite.pixel_size = 0.0058
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.shaded = true
		sprite.double_sided = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.position = seats[i]
		sprite.visible = i < _crowd_target
		add_child(sprite)
		var mug := Build.cyl(self, 0.08, 0.065, 0.13, seats[i] + Vector3(0.28, -0.4, 0.55), Build.mat(Color(0.7, 0.55, 0.4), 0.7), 8)
		mug.visible = sprite.visible
		_crowd.append({"sprite": sprite, "mug": mug, "id": ids[i], "base": seats[i], "phase": randf() * TAU,
			"blink_at": randf_range(1.0, 4.0), "blink_until": 0.0, "react_until": 0.0, "react": "happy", "expr": "calm"})


## Сколько посетителей сидит в зале (0..6). Меняется плавно: новые «заходят» появлением.
func set_crowd(count: int) -> void:
	_crowd_target = clampi(mini(count, crowd_capacity()), 0, _crowd.size())
	for i in _crowd.size():
		var entry: Dictionary = _crowd[i]
		var sprite: Sprite3D = entry["sprite"]
		var show_it: bool = i < _crowd_target
		(entry["mug"] as Node3D).visible = show_it
		if show_it and not sprite.visible:
			sprite.visible = true
			sprite.modulate = Color(1, 1, 1, 0)
			create_tween().tween_property(sprite, "modulate:a", 1.0, 0.8)
		elif not show_it:
			sprite.visible = false


## Сколько мест занято максимум: скромная таверна — 2 посетителя, популярная — 4, известная — 6.
func crowd_capacity() -> int:
	return 2 * clampi(_stage, 1, 3)


## Реакция зала на блюдо: «happy» (радость) или «surprised».
func react_crowd(kind: String) -> void:
	for entry in _crowd:
		entry["react"] = kind
		entry["react_until"] = _time + randf_range(1.2, 2.6)


func _update_crowd() -> void:
	for entry in _crowd:
		var sprite: Sprite3D = entry["sprite"]
		if not sprite.visible:
			continue
		var base: Vector3 = entry["base"]
		var k: float = _time * 1.5 + float(entry["phase"])
		sprite.position = base + Vector3(0.0, sin(k) * 0.018, 0.0)
		var expression: String = "calm"
		if _time < float(entry["react_until"]):
			expression = str(entry["react"])
		else:
			if _time > float(entry["blink_at"]):
				entry["blink_until"] = _time + 0.13
				entry["blink_at"] = _time + randf_range(2.5, 6.0)
			if _time < float(entry["blink_until"]):
				expression = "blink"
		if expression != str(entry["expr"]):
			entry["expr"] = expression
			sprite.texture = UiKit.tex("res://assets/guests/%s_%s.png" % [str(entry["id"]), expression])


func _build_decor() -> void:
	# Люстра и травы под потолком — всегда; остальное — после улучшения «Украшения».
	var chandelier := Props.place(self, "chandelier", Vector3(0.0, 4.2, -2.8))
	_stage_reg(chandelier, 2)
	_hang_nodes.append(chandelier)
	for i in 5:
		var bundle := Props.place(_back, "herb_bundle", Vector3(-4.0 + float(i) * 0.7, 4.5, WALL_Z + 0.3), float(i) * 50.0)
		_stage_reg(bundle, 2)
		_hang_nodes.append(bundle)
	var decor := _group("decor")
	Props.place(decor, "picture_a", Vector3(-7.6, 2.5, WALL_Z + 0.1))
	Props.place(decor, "picture_b", Vector3(5.8, 3.0, WALL_Z + 0.1))
	Props.place(decor, "wreath", Vector3(6.4, 2.0, WALL_Z + 0.12))
	Props.place(decor, "banner", Vector3(-6.3, 3.9, WALL_Z + 0.12))
	Props.place(decor, "banner", Vector3(1.8, 3.9, WALL_Z + 0.12), 0.0, 0.8)
	Props.place(decor, "plant", Vector3(-1.0, 0.0, WALL_Z + 0.5), 0.0, 1.2)


func _build_candles() -> void:
	for pos in [Vector3(-1.9, 3.48, WALL_Z + 0.65), Vector3(1.9, 3.48, WALL_Z + 0.65), Vector3(-3.0, 3.28, WALL_Z + 0.5)]:
		Props.place(_back, "candle", pos)
		_add_flame(_back, pos + Vector3(0, 0.34, 0))
		if _candle_lights.size() < 1:
			_candle_lights.append(Build.omni(_back, pos + Vector3(0, 0.45, 0.15), Color(1.0, 0.78, 0.45), 0.55, 3.4, false))


func _add_flame(parent: Node, pos: Vector3) -> void:
	var flame := Props.place(parent, "flame", pos)
	_candle_flames.append(flame)


## Деревянные панели на стене, лучи света из окна и пылинки в луче.
func _build_atmosphere() -> void:
	Build.box(_back, Vector3(24, 1.05, 0.08), Vector3(0, 0.525, WALL_Z + 0.04), _mats["beam"])
	Build.box(_back, Vector3(24, 0.09, 0.14), Vector3(0, 1.08, WALL_Z + 0.07), _mats["wood_dark"])
	var window_z: float = WALL_Z + BACK_Z + 0.2
	_beam(Vector3(2.6, 3.3, window_z), Vector3(0.2, 0.0, -5.4), 0.9, 0.16)
	_beam(Vector3(3.2, 3.4, window_z), Vector3(1.4, 0.0, -5.0), 1.1, 0.13)
	_beam(Vector3(3.8, 3.3, window_z), Vector3(2.8, 0.0, -5.2), 0.8, 0.14)
	var dust := Build.spark_particles(self, Vector3(1.6, 1.8, -6.6), Color(1.0, 0.95, 0.8, 0.6), 36, 9.0, 0.03, 0.06, 0.0, false)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.8, 1.6, 1.4)
	dust.spread = 180.0
	dust.preprocess = 9.0


## Полупрозрачный луч света (аддитивный): ярче у окна, затухает к полу.
func _beam(from: Vector3, to: Vector3, width: float, alpha: float) -> void:
	var direction: Vector3 = to - from
	var length: float = direction.length()
	var y_axis: Vector3 = direction.normalized()
	var facing := Vector3(0.0, 0.0, 1.0)
	var z_axis: Vector3 = (facing - y_axis * facing.dot(y_axis)).normalized()
	var x_axis: Vector3 = y_axis.cross(z_axis).normalized()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, alpha)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 8
	texture.height = 64
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.6, 0.74, 1.0, 1.0)
	material.albedo_texture = texture
	var quad := QuadMesh.new()
	quad.size = Vector2(width, length)
	var shaft := MeshInstance3D.new()
	shaft.mesh = quad
	shaft.material_override = material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shaft)
	shaft.global_transform = Transform3D(Basis(x_axis, y_axis, z_axis), (from + to) * 0.5)


func _stage_reg(node: Node3D, min_stage: int, max_stage: int = 3) -> Node3D:
	_stage_nodes.append({"node": node, "min": min_stage, "max": max_stage})
	return node


## Этап 2: бра, подсвечники, люстра (выше); этап 3: гобелены, кресла, вазы, полка с кубками.
func _build_stages() -> void:
	var back_wall: float = WALL_Z + 0.12
	# Этап 2 — «Популярная таверна».
	for x in [-2.5, 6.6, 9.0]:
		_stage_reg(Props.place(_back, "sconce", Vector3(x, 2.3, back_wall)), 2)
		_stage_reg(_flame_at(_back, Vector3(x, 2.3 + 0.14, back_wall + 0.16)), 2)
	_stage_reg(Props.place(_back, "candelabra", Vector3(0.4, 3.48, WALL_Z + 0.6)), 2)
	_stage_reg(Props.place(_back, "barrel", Vector3(6.3, 0.0, -2.6), 20.0, 0.9), 2)
	_stage_reg(Props.place(_back, "crate", Vector3(6.9, 0.0, -2.9), -25.0, 0.85), 2)
	# Этап 3 — «Известная таверна».
	for x in [-4.0, 4.0]:
		_stage_reg(Props.place(self, "tapestry", Vector3(x, 4.55, -6.4)), 3)
	_stage_reg(Props.place(_back, "trophy_shelf", Vector3(5.7, 1.9, WALL_Z + 0.25)), 3)
	_stage_reg(Props.place(_back, "candelabra", Vector3(3.9, 1.03, -3.0), 0.0, 0.9), 3)
	for x in [-2.4, 2.4]:
		var t := Vector3(x, 0.0, -4.2)
		_stage_reg(Props.place(self, "fancy_chair", t + Vector3(-0.5, 0.0, -0.95), 0.0), 3)
		_stage_reg(Props.place(self, "fancy_chair", t + Vector3(0.5, 0.0, -0.95), 0.0), 3)
		_stage_reg(Props.place(self, "vase_flowers", t + Vector3(0.0, 0.9, 0.0)), 3)
	_stage_reg(Props.place(_back, "vase_flowers", Vector3(2.7, 1.03, -3.35)), 3)
	_stage_reg(Props.place(self, "chandelier", Vector3(0.0, 4.2, -6.2), 0.0, 0.9), 3)
	# Золотая дорожка к очагу.
	_stage_reg(Build.box(self, Vector3(1.4, 0.03, 4.5), Vector3(0, 0.045, 3.2), Build.mat(Color(0.72, 0.5, 0.15), 0.9)), 3)
	_apply_stage(1)


func _flame_at(parent: Node, pos: Vector3) -> Node3D:
	var flame := Props.place(parent, "flame", pos)
	_candle_flames.append(flame)
	return flame


## Показывает или скрывает предметы по этапу и подстраивает свет.
func _apply_stage(stage: int) -> void:
	_stage = clampi(stage, 1, 3)
	for entry in _stage_nodes:
		var node: Node3D = entry["node"]
		node.visible = _stage >= int(entry["min"]) and _stage <= int(entry["max"])
	if _fill_light != null:
		_fill_light.light_energy = 0.8 + 0.2 * float(_stage - 1)
	set_crowd(_crowd_target)


## Короткий «облёт»: камера отъезжает, чтобы показать выросшую таверну, затем возвращается.
func celebrate_stage() -> void:
	_celebrating = true
	_cam_goal = _camera_params()
	await get_tree().create_timer(2.6).timeout
	_celebrating = false
	_cam_goal = _camera_params()


# --- Улучшения ----------------------------------------------------------------------------

func apply_upgrades(session: GameSessionService) -> void:
	for visual_id in ["lanterns", "counter", "shelves", "tables", "hearth", "decor"]:
		if _groups.has(visual_id):
			(_groups[visual_id] as Node3D).visible = session.has_upgrade(_upgrade_for_visual(session, visual_id))
	_apply_stage(session.tavern_stage)
	var copper: bool = session.has_upgrade(GameContent.UP_COPPER_CAULDRON)
	var big: bool = session.has_upgrade(GameContent.UP_BIG_CAULDRON)
	var hearth: bool = session.has_upgrade(GameContent.UP_HEARTH)
	kitchen.apply_upgrades(copper, big, hearth)


func _upgrade_for_visual(session: GameSessionService, visual_id: String) -> String:
	for upgrade in session.content.upgrades:
		if upgrade.visual_id == visual_id:
			return upgrade.id
	return ""


# --- Жизнь в таверне -----------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_apply_camera(delta)
	for i in _candle_flames.size():
		var flame: Node3D = _candle_flames[i]
		var k: float = _time * 9.0 + float(i) * 1.7
		flame.scale = Vector3(1.0 + 0.1 * sin(k), 1.6 + 0.3 * sin(k * 1.3 + 1.0), 1.0 + 0.1 * cos(k))
	for i in _candle_lights.size():
		_candle_lights[i].light_energy = 0.55 + 0.12 * sin(_time * 8.0 + float(i) * 2.1) + 0.05 * sin(_time * 19.0 + float(i))
	for i in _lantern_nodes.size():
		_lantern_nodes[i].rotation.z = sin(_time * 0.8 + float(i) * 1.9) * 0.035
		_lantern_lights[i].light_energy = 1.2 + 0.1 * sin(_time * 6.0 + float(i))
	for i in _hang_nodes.size():
		_hang_nodes[i].rotation.z = sin(_time * 0.9 + float(i) * 1.3) * 0.05
	_update_crowd()
	for i in _back_flames.size():
		var bf: MeshInstance3D = _back_flames[i]
		var bk: float = _time * 6.5 + _back_flame_phase[i]
		var bs: float = 0.8 + 0.3 * sin(bk) + 0.15 * sin(bk * 2.1 + 0.7)
		bf.scale = Vector3(1.0, bs, 1.0)
		bf.position.y = 0.5 + (bf.mesh as CylinderMesh).height * 0.5 * bs
	if _back_fire_light != null:
		_back_fire_light.light_energy = 2.6 * (1.0 + 0.15 * sin(_time * 10.0) + 0.08 * sin(_time * 16.0 + 1.0))
	# Далёкие вспышки молнии: холодный блик в комнате и на небе за окном.
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(14.0, 28.0)
		var tween := create_tween()
		tween.tween_property(_window_light, "light_energy", 6.0, 0.05)
		tween.tween_property(_window_light, "light_energy", 2.3, 0.09)
		tween.tween_property(_window_light, "light_energy", 5.0, 0.05)
		tween.tween_property(_window_light, "light_energy", 2.3, 0.5)
