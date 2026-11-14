class_name TestRunner
extends RefCounted
## Минимальный раннер: считает проверки и падения. Не использует assert(), чтобы
## результат был одинаковым в debug и release и код выхода отражал реальность.


var checks: int = 0
var failures: Array[String] = []
var current_suite: String = ""


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("[%s] %s" % [current_suite, message])
		printerr("  FAIL: " + message)


func equal(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if actual != expected:
		var text: String = "%s (ожидалось %s, получено %s)" % [message, str(expected), str(actual)]
		failures.append("[%s] %s" % [current_suite, text])
		printerr("  FAIL: " + text)
