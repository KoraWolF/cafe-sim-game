class_name TestCase
extends RefCounted
## Minimal base for tests run by tests/run_tests.gd. Swap for GUT if adopted.

var failures: PackedStringArray = []
## Engine errors (push_error etc.) this test deliberately causes.
var expected_errors: int = 0
## The scene tree running the tests (for tests that need nodes in a tree).
var tree: SceneTree


func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])
