extends SceneTree
## Запуск: godot --headless --path . -s tests/run_all.gd
## Код выхода 0 — все тесты прошли, 1 — есть падения.


func _initialize() -> void:
	var runner := TestRunner.new()
	var suites: Array = [
		preload("res://tests/unit/test_evaluator.gd").new(),
		preload("res://tests/unit/test_economy_content.gd").new(),
		preload("res://tests/unit/test_save.gd").new(),
		preload("res://tests/unit/test_recipes.gd").new(),
		preload("res://tests/unit/test_session.gd").new(),
	]
	for suite in suites:
		runner.current_suite = suite.get_script().resource_path.get_file()
		print("== ", runner.current_suite)
		suite.run(runner)
	print("Проверок: %d, падений: %d" % [runner.checks, runner.failures.size()])
	for failure in runner.failures:
		printerr(failure)
	quit(0 if runner.failures.is_empty() else 1)
