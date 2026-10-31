extends Node

## Third person strikes where you push; first person, and a still stick, keep
## the camera's aim exactly as before.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var view := Vector3(0, 0, 1)
	var behind := Vector3(0, 0, -1)
	check(StrikeHeading.heading(view, behind, true).is_equal_approx(behind), "third person strikes behind when you push behind")
	check(StrikeHeading.heading(view, Vector3(1, 0, 0), true).is_equal_approx(Vector3(1, 0, 0)), "and to the side when you push sideways")
	check(StrikeHeading.heading(view, behind, false).is_equal_approx(view), "first person keeps the precise camera aim")
	check(StrikeHeading.heading(view, Vector3(0.05, 0, 0), true).is_equal_approx(view), "a stick at rest leaves aim with the camera")
	check(StrikeHeading.heading(Vector3(0, 0.9, 0.2), Vector3.ZERO, true).is_equal_approx(Vector3(0, 0, 1)), "pitch never decides the heading")
	check(StrikeHeading.heading(Vector3.UP, Vector3.ZERO, false).is_equal_approx(Vector3.FORWARD), "a straight-up view still yields a real heading")
	print("STRIKE_HEADING_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
