class_name SaveService
extends Node
## Автозагрузка: безопасное сохранение прогресса.
## Запись атомарная (временный файл → проверка → замена), перед заменой делается копия .bak.
## Повреждённый или отсутствующий файл не роняет игру: берём резервную копию или начинаем заново.


const SAVE_VERSION: int = 7
const DEFAULT_SAVE_PATH: String = "user://tavern_kitchen/save.cfg"
## Старый путь прототипа (в нём сохранения фактически не создавались, но на всякий случай читаем).
const LEGACY_SAVE_PATH: String = "user://tavernkitch/save.cfg"
const SECTION: String = "tavern_kitchen"


signal settings_changed

var save_path: String = DEFAULT_SAVE_PATH
var save_data: SaveData = SaveData.new()
## "new" — файла нет; "ok" — загружено; "recovered" — взята копия; "corrupted" — всё повреждено, начато заново.
var last_load_status: String = "new"


func _ready() -> void:
	load_game()


func load_game() -> void:
	save_data = SaveData.new()
	last_load_status = "new"
	var main_exists: bool = FileAccess.file_exists(save_path)
	var loaded: SaveData = _try_read(save_path)
	if loaded != null:
		save_data = loaded
		last_load_status = "ok"
		return
	var backup: SaveData = _try_read(save_path + ".bak")
	if backup != null:
		save_data = backup
		last_load_status = "recovered"
		save()
		return
	if save_path == DEFAULT_SAVE_PATH:
		var legacy: SaveData = _try_read(LEGACY_SAVE_PATH)
		if legacy != null:
			save_data = legacy
			last_load_status = "recovered"
			save()
			return
	if main_exists:
		last_load_status = "corrupted"
		push_warning("Сохранение повреждено, начата новая игра.")


func _try_read(path: String) -> SaveData:
	if not FileAccess.file_exists(path):
		return null
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return null
	if not config.has_section(SECTION):
		return null
	var data: Dictionary = {}
	for key in config.get_section_keys(SECTION):
		data[key] = config.get_value(SECTION, key)
	if not data.has("version") or not data.has("coins"):
		return null
	var loaded := SaveData.new()
	loaded.from_dictionary(data)
	return loaded


func has_progress() -> bool:
	return save_data.has_progress()


func save() -> bool:
	var dir_path: String = save_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(dir_path) != OK and not DirAccess.dir_exists_absolute(dir_path):
		push_warning("Не удалось создать папку сохранения: " + dir_path)
		return false
	var tmp_path: String = save_path + ".tmp"
	var config := ConfigFile.new()
	var data: Dictionary = save_data.to_dictionary()
	for key in data:
		config.set_value(SECTION, key, data[key])
	if config.save(tmp_path) != OK:
		push_warning("Не удалось записать сохранение.")
		return false
	# Проверяем, что временный файл читается, и только потом заменяем основной.
	if _try_read(tmp_path) == null:
		DirAccess.remove_absolute(tmp_path)
		return false
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".bak")
		DirAccess.remove_absolute(save_path)
	var err: int = DirAccess.rename_absolute(tmp_path, save_path)
	if err != OK:
		push_warning("Не удалось заменить файл сохранения.")
		return false
	return true


## Новая игра: прогресс стирается, настройки остаются.
func reset_progress() -> void:
	save_data.reset_progress()
	save()


func set_master_volume(value: float) -> void:
	save_data.master_volume = clampf(value, 0.0, 1.0)
	settings_changed.emit()


func set_ambience_volume(value: float) -> void:
	save_data.ambience_volume = clampf(value, 0.0, 1.0)
	settings_changed.emit()


func set_voices_volume(value: float) -> void:
	save_data.voices_volume = clampf(value, 0.0, 1.0)
	settings_changed.emit()


func set_music_volume(value: float) -> void:
	save_data.music_volume = clampf(value, 0.0, 1.0)
	settings_changed.emit()


func set_sfx_volume(value: float) -> void:
	save_data.sfx_volume = clampf(value, 0.0, 1.0)
	settings_changed.emit()


func set_relaxed_mode(value: bool) -> void:
	save_data.relaxed_mode = value
	settings_changed.emit()
