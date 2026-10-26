extends SceneTree
## Runs every tests/test_*.gd file and each of its test_* methods.
## Usage: godot --headless --path . -s res://tests/run_tests.gd
## A test fails on a failed assertion or on any engine error (script errors,
## push_error) while it runs, unless it set expected_errors to that exact count.
## A test file that fails to load counts as a failure. Exits with code 1 if any test fails.

const TEST_DIR: String = "res://tests"


## Collects engine errors. A script error aborts the test method without
## failing an assertion, so the runner checks this after each test.
class ErrorCollector extends Logger:
	var errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var message := rationale if not rationale.is_empty() else code
		errors.append("%s (%s:%d in %s)" % [message, file, line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _started := false


## Runs on the first frame, when the scene tree is live (tests can add nodes to it).
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run_all()
	return false


func _run_all() -> void:
	var collector := ErrorCollector.new()
	OS.add_logger(collector)
	var passed := 0
	var failed := 0
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		if file_name == "test_case.gd":
			continue
		collector.errors.clear()
		var script: GDScript = load(TEST_DIR.path_join(file_name))
		if script == null or not script.can_instantiate() or not collector.errors.is_empty():
			# A file that fails to compile has no methods; without this it would be silently skipped.
			failed += 1
			print("FAIL %s (does not load)" % file_name)
			for error: String in collector.errors:
				print("    " + error)
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			collector.errors.clear()
			var test_case: TestCase = script.new()
			test_case.tree = self
			test_case.call(method_name)
			var failures := test_case.failures
			if collector.errors.size() != test_case.expected_errors:
				failures.append("expected %d engine error(s), got %d:" % [test_case.expected_errors, collector.errors.size()])
				failures.append_array(collector.errors)
			if failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FAIL %s::%s" % [file_name, method_name])
				for failure: String in failures:
					print("    " + failure)
	OS.remove_logger(collector)
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
