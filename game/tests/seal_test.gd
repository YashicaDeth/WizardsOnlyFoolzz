extends Node

## E2.1. The seal vocabulary is independent from any roster: E2.2 can add
## marks without changing the renderer, and E2.3 can add original marks without
## inheriting real-world correspondences.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var bridge := [[-1.0, 0.0], [0.0, 0.0], [1.0, 0.0]]
	var points := CellOutzType.seal_stroke_points(bridge, Vector2(40, 50), 20.0)
	check(points.size() == 3, "a seal stroke retains every authored point")
	check(points[0].is_equal_approx(Vector2(20, 50)) and points[2].is_equal_approx(Vector2(60, 50)), "the centred seal grid maps to its requested radius")
	var turned := CellOutzType.seal_stroke_points(bridge, Vector2.ZERO, 10.0, PI * 0.5)
	check(turned[0].is_equal_approx(Vector2(0, -10)) and turned[2].is_equal_approx(Vector2(0, 10)), "the same mark can be turned without changing its authored path")
	var broken := CellOutzType.seal_stroke_points([[0.0], [1.0, 1.0]], Vector2.ZERO, 10.0)
	check(broken.size() == 1, "malformed points are ignored instead of corrupting the mark")
	print("SEAL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
