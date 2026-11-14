class_name AudioService
extends Node
## Звуковая атмосфера таверны.
##
## Шины: Master → Music, Ambience, Environment, Characters, UI, Cooking.
##  • Music — музыкальные темы (меню / день / особый заказ / вечер) с плавным переходом;
##  • Ambience — гул зала, огонь, дождь; Environment — ветер и события помещения (шаги, дверь, посуда, стулья);
##  • Characters — голоса и реакции посетителей (позиционные, 3D); UI — клики, монеты; Cooking — котёл.
## Characters и Environment проходят через «комнатную» обработку (фильтр высоких частот + реверберация),
## поэтому звуки воспринимаются как находящиеся в помещении.
## Если файл не найден (проект не импортирован), соответствующий звук молчит; missing показывает, чего нет.


const DIR: String = "res://assets/audio/"
const BUS_MUSIC: String = "Music"
const BUS_AMBIENCE: String = "Ambience"
const BUS_ENVIRONMENT: String = "Environment"
const BUS_CHARACTERS: String = "Characters"
const BUS_UI: String = "UI"
const BUS_COOKING: String = "Cooking"
const ALL_BUSES: Array[String] = ["Music", "Ambience", "Environment", "Characters", "UI", "Cooking"]
const POOL_2D: int = 8
const POOL_3D: int = 6
const MAX_VARIANTS: int = 6

## Короткие эффекты (без позиции): имя → шина, файлы без расширения, поправка громкости.
const EFFECTS: Dictionary = {
	"ui_click": {"bus": "UI", "files": ["sfx/ui_click"], "db": 0.0},
	"buy": {"bus": "UI", "files": ["sfx/buy"], "db": 0.0},
	"coin": {"bus": "UI", "files": ["sfx/coin"], "db": 0.0},
	"order_issued": {"bus": "UI", "files": ["sfx/order_issued"], "db": -4.0},
	"ingredient_select": {"bus": "UI", "files": ["sfx/ingredient_select"], "db": 0.0},
	"ingredient_drop": {"bus": "Cooking", "files": ["sfx/ingredient_drop"], "db": 0.0},
	"splash": {"bus": "Cooking", "files": ["sfx/splash"], "db": -2.0},
	"stir": {"bus": "Cooking", "files": ["sfx/stir"], "db": 0.0},
	"lid": {"bus": "Cooking", "files": ["sfx/lid"], "db": 0.0},
	"success": {"bus": "Cooking", "files": ["sfx/success"], "db": 0.0},
	"fail": {"bus": "Cooking", "files": ["sfx/fail"], "db": 0.0},
	"serve": {"bus": "Cooking", "files": ["sfx/serve"], "db": 0.0},
	"reaction_good": {"bus": "Characters", "files": ["sfx/reaction_good"], "db": -4.0},
	"reaction_bad": {"bus": "Characters", "files": ["sfx/reaction_bad"], "db": -4.0},
}

## Позиционные события зала: несколько вариантов, чтобы звуки не повторялись.
const EVENTS: Dictionary = {
	"murmur": {"bus": "Characters", "prefix": "crowd/murmur_", "db": -9.0},
	"laugh": {"bus": "Characters", "prefix": "crowd/laugh_", "db": -7.0},
	"gasp": {"bus": "Characters", "prefix": "crowd/gasp_", "db": -7.0},
	"approve": {"bus": "Characters", "prefix": "crowd/approve_", "db": -6.0},
	"grumble": {"bus": "Characters", "prefix": "crowd/grumble_", "db": -7.0},
	"mug_clink": {"bus": "Environment", "prefix": "crowd/mug_clink_", "db": -8.0},
	"dish": {"bus": "Environment", "prefix": "env/dish_", "db": -9.0},
	"chair": {"bus": "Environment", "prefix": "env/chair_", "db": -9.0},
	"steps": {"bus": "Environment", "prefix": "env/steps_", "db": -8.0},
	"door_creak": {"bus": "Environment", "prefix": "env/door_creak_", "db": -6.0},
	"chest_open": {"bus": "Environment", "prefix": "env/chest_open", "db": -7.0},
	"bubble_pop": {"bus": "Cooking", "prefix": "env/bubble_pop_", "db": -10.0},
}

const TRACKS: Dictionary = {
	"menu": "music/menu_theme",
	"day": "music/tavern_day",
	"event": "music/event_lively",
	"evening": "music/evening",
}

## Громкость групп (0..1); применяется к шинам.
var master_volume: float = 0.9
var music_volume: float = 0.8
var ambience_volume: float = 0.8
var voices_volume: float = 0.8
var sfx_volume: float = 0.7
var has_music: bool = false
var has_sfx: bool = false
var missing: Array[String] = []
var current_track: String = ""
var crowd_level: int = 2
var night: bool = false

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_front: AudioStreamPlayer
var _room: AudioStreamPlayer
var _fire: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _boil: AudioStreamPlayer
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _cache: Dictionary = {}
var _variants: Dictionary = {}
var _last_variant: Dictionary = {}
var _last_played: Dictionary = {}
var _positions: Dictionary = {"seats": [], "door": Vector3(7.8, 1.0, -8.7), "counter": Vector3(3.2, 1.0, -8.1), "cauldron": Vector3(0, 1.8, 0.6)}
var _time: float = 0.0
var _event_timer: float = 6.0
var _last_event: String = ""
var _boiling: bool = false
var _pop_timer: float = 0.5
var _room_tween: Tween
var _ambient_started: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	for bus_name in ALL_BUSES:
		_ensure_bus(bus_name)
	_setup_bus_effects()
	_music_a = _make_player("MusicA", BUS_MUSIC)
	_music_b = _make_player("MusicB", BUS_MUSIC)
	_music_front = _music_a
	_room = _make_player("Room", BUS_AMBIENCE)
	_fire = _make_player("Fire", BUS_AMBIENCE)
	_rain = _make_player("Rain", BUS_AMBIENCE)
	_wind = _make_player("Wind", BUS_ENVIRONMENT)
	_boil = _make_player("Boil", BUS_COOKING)
	for i in POOL_2D:
		_pool_2d.append(_make_player("Sfx%d" % i, BUS_UI))
	for i in POOL_3D:
		var player := AudioStreamPlayer3D.new()
		player.name = "Spatial%d" % i
		player.unit_size = 8.0
		player.max_distance = 40.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_pool_3d.append(player)
	_room.stream = _load_stream("env/tavern_room", true)
	_fire.stream = _load_stream("sfx/fire_loop", true)
	_rain.stream = _load_stream("sfx/rain_loop", true)
	_wind.stream = _load_stream("env/wind_loop", true)
	_boil.stream = _load_stream("sfx/boil_loop", true)
	_room.volume_db = -16.0
	_fire.volume_db = -10.0
	_rain.volume_db = -17.0
	_wind.volume_db = -22.0
	_boil.volume_db = -8.0
	has_sfx = _load_stream("sfx/ui_click", false) != null
	has_music = _load_stream(str(TRACKS["menu"]), false) != null
	var save_service := get_node_or_null("/root/TavernSave") as SaveService
	if save_service != null:
		var data: SaveData = save_service.save_data
		set_master_volume(data.master_volume)
		set_music_volume(data.music_volume)
		set_ambience_volume(data.ambience_volume)
		set_voices_volume(data.voices_volume)
		set_sfx_volume(data.sfx_volume)
	else:
		_apply_volumes()


func _exit_tree() -> void:
	stop_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop_all()


# --- Шины -------------------------------------------------------------------------

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


## «Комната»: приглушённые верха и лёгкая реверберация — звуки не «в голове», а в помещении.
func _setup_bus_effects() -> void:
	for bus_name in [BUS_CHARACTERS, BUS_ENVIRONMENT]:
		var index: int = AudioServer.get_bus_index(bus_name)
		if index == -1 or AudioServer.get_bus_effect_count(index) > 0:
			continue
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = 5200.0
		AudioServer.add_bus_effect(index, low_pass)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.45
		reverb.damping = 0.6
		reverb.wet = 0.18
		reverb.dry = 0.92
		AudioServer.add_bus_effect(index, reverb)
	var ambience_index: int = AudioServer.get_bus_index(BUS_AMBIENCE)
	if ambience_index != -1 and AudioServer.get_bus_effect_count(ambience_index) == 0:
		var soft := AudioEffectReverb.new()
		soft.room_size = 0.3
		soft.wet = 0.1
		AudioServer.add_bus_effect(ambience_index, soft)


func _make_player(player_name: String, bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus_name
	add_child(player)
	return player


func _set_bus(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func _apply_volumes() -> void:
	_set_bus("Master", master_volume)
	_set_bus(BUS_MUSIC, music_volume * 0.85)
	_set_bus(BUS_AMBIENCE, ambience_volume)
	_set_bus(BUS_ENVIRONMENT, ambience_volume)
	_set_bus(BUS_CHARACTERS, voices_volume)
	_set_bus(BUS_UI, sfx_volume)
	_set_bus(BUS_COOKING, sfx_volume)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


func set_ambience_volume(value: float) -> void:
	ambience_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


func set_voices_volume(value: float) -> void:
	voices_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


# --- Загрузка ----------------------------------------------------------------------

## Ищет res://assets/audio/<name>.ogg (или .wav). Результат кешируется.
func _load_stream(name_no_ext: String, loop: bool, record_missing: bool = true) -> AudioStream:
	if _cache.has(name_no_ext):
		return _cache[name_no_ext]
	var stream: AudioStream = null
	for extension in [".ogg", ".wav"]:
		var path: String = DIR + name_no_ext + extension
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	if stream != null and loop and stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	if stream == null and record_missing and not missing.has(name_no_ext):
		missing.append(name_no_ext)
	_cache[name_no_ext] = stream
	return stream


## Список файлов-вариантов: prefix1, prefix2, ... (или одиночный файл).
func _variant_list(prefix: String) -> Array[AudioStream]:
	if _variants.has(prefix):
		return _variants[prefix]
	var list: Array[AudioStream] = []
	var single: AudioStream = _load_stream(prefix, false, false) if not prefix.ends_with("_") else null
	if single != null:
		list.append(single)
	else:
		for i in range(1, MAX_VARIANTS + 1):
			var stream: AudioStream = _load_stream("%s%d" % [prefix, i], false, false)
			if stream != null:
				list.append(stream)
	if list.is_empty() and not missing.has(prefix):
		missing.append(prefix)
	_variants[prefix] = list
	return list


func _pick_variant(prefix: String) -> AudioStream:
	var list: Array[AudioStream] = _variant_list(prefix)
	if list.is_empty():
		return null
	var index: int = rng.randi() % list.size()
	if list.size() > 1 and _last_variant.get(prefix, -1) == index:
		index = (index + 1) % list.size()
	_last_variant[prefix] = index
	return list[index]


# --- Музыка ------------------------------------------------------------------------

## Плавно переключает музыкальную тему: menu, day, event, evening.
func play_track(track: String, fade: float = 1.6) -> void:
	if track == current_track or not TRACKS.has(track):
		return
	var stream: AudioStream = _load_stream(str(TRACKS[track]), true)
	if stream == null:
		return
	current_track = track
	var incoming: AudioStreamPlayer = _music_b if _music_front == _music_a else _music_a
	var outgoing: AudioStreamPlayer = _music_front
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	_music_front = incoming
	var tween := create_tween().set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0, fade)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -40.0, fade)
		tween.chain().tween_callback(outgoing.stop)


## Совместимость: основная тема.
func play_music() -> void:
	play_track("menu")


func stop_music() -> void:
	_music_a.stop()
	_music_b.stop()
	current_track = ""


# --- Атмосфера ---------------------------------------------------------------------

## Запускает постоянные слои: гул зала, огонь, дождь, ветер.
func play_ambience() -> void:
	for player in [_room, _fire, _rain, _wind]:
		if player != null and player.stream != null and not player.playing:
			player.play()
	_ambient_started = true
	_update_room_volume(0.1)


## Передаёт позиции в мире: seats (Array[Vector3]), door, counter, cauldron.
func set_world_positions(positions: Dictionary) -> void:
	for key in positions:
		_positions[key] = positions[key]


## Сколько посетителей в зале: от этого зависят громкость гула и частота событий.
func set_crowd_level(count: int) -> void:
	crowd_level = clampi(count, 0, 6)
	_update_room_volume(2.0)


## Вечер: тише голоса, ближе огонь и дождь.
func set_night(value: bool) -> void:
	if night == value:
		return
	night = value
	_update_room_volume(3.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_fire, "volume_db", -7.0 if night else -10.0, 3.0)
	tween.tween_property(_wind, "volume_db", -17.0 if night else -22.0, 3.0)


func _update_room_volume(duration: float) -> void:
	if _room == null:
		return
	var target: float = lerpf(-26.0, -11.0, float(crowd_level) / 6.0) - (5.0 if night else 0.0)
	if _room_tween != null and _room_tween.is_valid():
		_room_tween.kill()
	if duration <= 0.0:
		_room.volume_db = target
		return
	_room_tween = create_tween()
	_room_tween.tween_property(_room, "volume_db", target, duration)


func set_boiling(active: bool) -> void:
	_boiling = active
	if _boil == null or _boil.stream == null:
		return
	if active and not _boil.playing:
		_boil.play()
	elif not active and _boil.playing:
		_boil.stop()


func _process(delta: float) -> void:
	_time += delta
	if not _ambient_started:
		return
	# Дождь и ветер слегка «дышат».
	if _rain != null:
		_rain.volume_db = (-14.0 if night else -17.0) + 2.5 * sin(_time * 0.11) + 1.0 * sin(_time * 0.37)
	_event_timer -= delta
	if _event_timer <= 0.0:
		_play_random_event()
		var base: float = rng.randf_range(5.0, 12.0) / (0.6 + 0.25 * float(crowd_level))
		_event_timer = base * (1.6 if night else 1.0)
	if _boiling:
		_pop_timer -= delta
		if _pop_timer <= 0.0:
			play_event("bubble_pop", _positions["cauldron"])
			_pop_timer = rng.randf_range(0.35, 1.1)


## Случайное событие помещения с учётом числа посетителей и времени суток.
func _play_random_event() -> void:
	var weights: Dictionary = {"murmur": 4.0, "mug_clink": 3.0, "dish": 2.0, "chair": 1.5, "steps": 1.0, "door_creak": 0.35, "chest_open": 0.15}
	if crowd_level >= 2:
		weights["laugh"] = 1.4
		weights["grumble"] = 0.4
		weights["gasp"] = 0.3
	if crowd_level == 0:
		weights.erase("murmur")
		weights.erase("laugh")
		weights.erase("mug_clink")
	if night:
		weights["laugh"] = 0.3
	weights.erase(_last_event)
	var total: float = 0.0
	for key in weights:
		total += float(weights[key])
	if total <= 0.0:
		return
	var roll: float = rng.randf() * total
	for key in weights:
		roll -= float(weights[key])
		if roll <= 0.0:
			_last_event = str(key)
			var pos: Vector3 = _event_position(str(key))
			play_event(str(key), pos)
			return


func _event_position(event: String) -> Vector3:
	if event == "door_creak" or event == "steps":
		return _positions["door"]
	if event == "dish" or event == "chest_open":
		return _positions["counter"]
	var seats: Array = _positions["seats"]
	if seats.is_empty():
		return _positions["counter"]
	return seats[rng.randi() % seats.size()]


# --- Эффекты -----------------------------------------------------------------------

func play_effect(effect: String) -> void:
	if not EFFECTS.has(effect):
		return
	var spec: Dictionary = EFFECTS[effect]
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(effect, -10.0)) < 0.05:
		return
	_last_played[effect] = now
	var stream: AudioStream = _pick_variant(str(spec["files"][0]))
	if stream == null:
		return
	var player: AudioStreamPlayer = _free_player_2d()
	player.bus = str(spec["bus"])
	player.stream = stream
	player.volume_db = float(spec["db"]) + rng.randf_range(-1.0, 0.5)
	player.pitch_scale = rng.randf_range(0.97, 1.04)
	player.play()


func _free_player_2d() -> AudioStreamPlayer:
	for player in _pool_2d:
		if not player.playing:
			return player
	return _pool_2d[0]


## Позиционный звук зала. Если все каналы заняты — событие пропускается (без наложения).
func play_event(event: String, pos: Vector3 = Vector3.INF) -> void:
	if not EVENTS.has(event):
		return
	var spec: Dictionary = EVENTS[event]
	var stream: AudioStream = _pick_variant(str(spec["prefix"]))
	if stream == null:
		return
	var player: AudioStreamPlayer3D = null
	for candidate in _pool_3d:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		return
	player.bus = str(spec["bus"])
	player.stream = stream
	player.global_position = pos if pos != Vector3.INF else _event_position(event)
	player.volume_db = float(spec["db"]) + rng.randf_range(-1.5, 1.0)
	player.pitch_scale = rng.randf_range(0.94, 1.06)
	player.play()


## Реакция зала на блюдо: quality — OrderEvaluation.Quality.
func react_crowd(quality: int) -> void:
	if quality == OrderEvaluation.Quality.PERFECT:
		play_event("approve")
		get_tree().create_timer(0.5).timeout.connect(func() -> void: play_event("laugh"))
	elif quality == OrderEvaluation.Quality.SUITABLE:
		play_event("murmur")
	else:
		play_event("gasp")
		get_tree().create_timer(0.7).timeout.connect(func() -> void: play_event("grumble"))


## Появление гостя: скрип двери и шаги.
func guest_arrives() -> void:
	play_event("door_creak", _positions["door"])
	get_tree().create_timer(0.6).timeout.connect(func() -> void: play_event("steps", _positions["door"]))


func stop_all() -> void:
	for player in [_music_a, _music_b, _room, _fire, _rain, _wind, _boil]:
		if player != null:
			player.stop()
	for player in _pool_2d:
		player.stop()
	for player in _pool_3d:
		player.stop()
	_ambient_started = false
