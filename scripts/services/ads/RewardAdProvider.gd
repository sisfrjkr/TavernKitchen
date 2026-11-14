class_name RewardAdProvider
extends RefCounted
## Интерфейс адаптера rewarded-рекламы. Конкретный SDK (например, Яндекс Игры для веб-сборки)
## подключается наследником этого класса и RewardAd.register_provider(), без правок игровой логики.


## Готов ли провайдер показать рекламу прямо сейчас.
func is_ready() -> bool:
	return false


## Показывает рекламу. Ровно один из трёх колбэков должен быть вызван:
## on_rewarded — реклама просмотрена до конца (только тогда выдаётся награда);
## on_closed — игрок закрыл рекламу раньше времени; on_error — ошибка SDK.
func show(_on_rewarded: Callable, _on_closed: Callable, _on_error: Callable) -> void:
	pass
