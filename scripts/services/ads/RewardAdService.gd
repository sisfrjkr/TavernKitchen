class_name RewardAdService
extends Node
## Сервис добровольной rewarded-рекламы.
## Без зарегистрированного провайдера (SDK) реклама недоступна: кнопка скрыта, награды нет,
## никакой «фиктивной» рекламы не показывается. Награда выдаётся строго после подтверждения просмотра.


signal availability_changed
signal rewarded_completed
signal rewarded_failed(reason: String)

var provider: RewardAdProvider = null
var _pending_success: Callable = Callable()
var _pending_fail: Callable = Callable()
var _busy: bool = false


func register_provider(new_provider: RewardAdProvider) -> void:
	provider = new_provider
	availability_changed.emit()


func can_show_rewarded() -> bool:
	return provider != null and not _busy and provider.is_ready()


## on_success вызывается не более одного раза и только после подтверждённого просмотра.
func show_rewarded_ad(on_success: Callable, on_fail: Callable = Callable()) -> void:
	if not can_show_rewarded():
		_fail("unavailable", on_fail)
		return
	_busy = true
	_pending_success = on_success
	_pending_fail = on_fail
	provider.show(_on_provider_rewarded, _on_provider_closed, _on_provider_error)


func _on_provider_rewarded() -> void:
	if not _busy:
		return
	var callback: Callable = _pending_success
	_reset()
	rewarded_completed.emit()
	if callback.is_valid():
		callback.call()


func _on_provider_closed() -> void:
	var fail: Callable = _pending_fail
	_reset()
	_fail("closed", fail)


func _on_provider_error() -> void:
	var fail: Callable = _pending_fail
	_reset()
	_fail("error", fail)


func _fail(reason: String, on_fail: Callable) -> void:
	rewarded_failed.emit(reason)
	if on_fail.is_valid():
		on_fail.call(reason)


func _reset() -> void:
	_busy = false
	_pending_success = Callable()
	_pending_fail = Callable()
