extends RefCounted
## Тесты сохранений: круговая запись, повреждённые файлы, миграция.

const PATH: String = "user://tests_tavern/save.cfg"


func _clean() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _service() -> SaveService:
	var service := SaveService.new()
	service.save_path = PATH
	return service


func run(t: TestRunner) -> void:
	_clean()
	# Новый игрок.
	var fresh := _service()
	fresh.load_game()
	t.equal(fresh.last_load_status, "new", "нет файла — новая игра")
	t.equal(fresh.save_data.coins, SaveData.DEFAULT_COINS, "стартовые монеты")
	t.check(not fresh.has_progress(), "у нового игрока нет прогресса")

	# Круговая запись.
	fresh.save_data.coins = 77
	fresh.save_data.reputation = 33
	fresh.save_data.day_number = 4
	fresh.save_data.owned_upgrades.append("upgrade_cauldron")
	fresh.save_data.music_volume = 0.25
	fresh.save_data.relaxed_mode = true
	t.check(fresh.save(), "сохранение успешно")
	var loaded := _service()
	loaded.load_game()
	t.equal(loaded.last_load_status, "ok", "загрузка прошла")
	t.equal(loaded.save_data.coins, 77, "монеты сохранены")
	t.equal(loaded.save_data.reputation, 33, "слава сохранена")
	t.equal(loaded.save_data.day_number, 4, "день сохранён")
	t.check(loaded.save_data.owned_upgrades.has("upgrade_cauldron"), "улучшение сохранено")
	t.check(absf(loaded.save_data.music_volume - 0.25) < 0.001, "громкость сохранена")
	t.check(loaded.save_data.relaxed_mode, "расслабленный режим сохранён")
	t.check(loaded.has_progress(), "прогресс обнаружен")

	# Резервная копия при повреждении основного файла.
	loaded.save_data.coins = 99
	loaded.save()  # теперь .bak содержит предыдущее состояние (77)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("это не конфиг [[[ {{{")
	f.close()
	var recovered := _service()
	recovered.load_game()
	t.equal(recovered.last_load_status, "recovered", "взята резервная копия")
	t.equal(recovered.save_data.coins, 77, "из копии восстановлены монеты")

	# Всё повреждено — игра не падает.
	_clean()
	var broken := FileAccess.open(PATH, FileAccess.WRITE)
	broken.store_string("мусор")
	broken.close()
	var corrupted := _service()
	corrupted.load_game()
	t.equal(corrupted.last_load_status, "corrupted", "повреждённый файл распознан")
	t.equal(corrupted.save_data.coins, SaveData.DEFAULT_COINS, "после повреждения — значения по умолчанию")

	# Мусорные типы внутри корректного файла.
	var junk := SaveData.new()
	junk.from_dictionary({"version": 3, "coins": "abc", "reputation": 9999, "owned_upgrades": "строка", "day_number": -5, "music_volume": 7.5, "relaxed_mode": "да"})
	t.equal(junk.coins, SaveData.DEFAULT_COINS, "нечисловые монеты → по умолчанию")
	t.equal(junk.reputation, 100, "слава ограничена 100")
	t.equal(junk.owned_upgrades.size(), 0, "не-массив улучшений игнорируется")
	t.equal(junk.day_number, 1, "день не меньше 1")
	t.equal(junk.music_volume, 1.0, "громкость ограничена")
	t.check(not junk.relaxed_mode, "не-bool режим → false")

	# Миграция старой версии: удалённые улучшения возвращают монеты, дубли убираются.
	var old := SaveData.new()
	old.from_dictionary({"version": 2, "coins": 10, "owned_upgrades": ["upgrade_cauldron", "upgrade_cauldron", "upgrade_stew_pot", "upgrade_iron_oven"], "day_number": 3})
	t.equal(old.version, SaveData.CURRENT_VERSION, "версия обновлена")
	t.equal(old.owned_upgrades.size(), 1, "остался один Медный котёл")
	t.equal(old.coins, 10 + 80 + 90, "стоимость удалённых улучшений возвращена")
	t.equal(old.day_number, 3, "день сохранён при миграции")

	# Новые группы громкости: значения по умолчанию, ограничение и сохранение при сбросе.
	var volumes := SaveData.new()
	volumes.from_dictionary({"version": 5, "coins": 25})
	t.check(absf(volumes.master_volume - 0.9) < 0.001 and absf(volumes.ambience_volume - 0.8) < 0.001 and absf(volumes.voices_volume - 0.8) < 0.001, "громкость по умолчанию для старого сохранения")
	volumes.from_dictionary({"version": 6, "master_volume": 5, "ambience_volume": -3, "voices_volume": "тихо"})
	t.equal(volumes.master_volume, 1.0, "общая громкость ограничена сверху")
	t.equal(volumes.ambience_volume, 0.0, "громкость атмосферы ограничена снизу")
	t.check(absf(volumes.voices_volume - 0.8) < 0.001, "нечисловая громкость голосов → по умолчанию")
	volumes.voices_volume = 0.3
	volumes.ambience_volume = 0.6
	volumes.reset_progress()
	t.check(absf(volumes.voices_volume - 0.3) < 0.001 and absf(volumes.ambience_volume - 0.6) < 0.001, "сброс прогресса не меняет громкость")

	# Сброс прогресса сохраняет настройки.
	var settings := SaveData.new()
	settings.coins = 500
	settings.music_volume = 0.1
	settings.relaxed_mode = true
	settings.reset_progress()
	t.equal(settings.coins, SaveData.DEFAULT_COINS, "сброс: монеты")
	t.check(absf(settings.music_volume - 0.1) < 0.001, "сброс не трогает громкость")
	t.check(settings.relaxed_mode, "сброс не трогает режим")
	_clean()
