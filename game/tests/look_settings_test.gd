extends Node

## Mouse sensitivity, invert Y and FOV (the checklist's B5), set from the
## pause menu's CAMERA page and read by the mouse look in every scene.

const LOOK := preload("res://systems/look_settings.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var gate = get_node("/root/PauseGate")
	WorldHistory.register_subject("settings", {})
	check(is_equal_approx(LOOK.sensitivity(), 1.0) and not LOOK.invert_y() and LOOK.fov_offset() == 0.0, "the defaults change nothing")
	gate.open_gate()
	gate.page = "camera"
	gate._build_rows()
	check(gate._rows.size() == 4, "the CAMERA page has sensitivity, invert Y, FOV and back")
	gate.highlighted = 0
	for _step in 5:
		gate._nudge(1)
	check(is_equal_approx(LOOK.sensitivity(), 1.5), "right raises the sensitivity (%.2f)" % LOOK.sensitivity())
	gate.highlighted = 1
	gate._activate()
	check(LOOK.invert_y(), "enter flips invert Y")
	gate.highlighted = 2
	gate._nudge(1)
	gate._nudge(1)
	check(LOOK.fov_offset() == 10.0, "FOV steps by five degrees (%+d)" % roundi(LOOK.fov_offset()))
	check(is_equal_approx(LOOK.dx(Vector2(10, 0)), 15.0) and is_equal_approx(LOOK.dy(Vector2(0, 10)), -15.0), "the mouse look scales and inverts")
	for _step in 100:
		gate.highlighted = 0
		gate._nudge(1)
	check(LOOK.sensitivity() <= LOOK.SENSITIVITY_RANGE.y, "sensitivity stops at its limit")
	gate.close()
	get_tree().paused = false
	# Every scene's mouse look reads it. Headless Godot can't capture the mouse,
	# which every look handler requires, so this reads the handlers themselves.
	for scene in ["vat_chamber", "buried_city", "service_arcade", "old_drains", "blood_waterfall_exit", "support_unit", "doctor_vehicle_bay", "bone_yard_hunt", "rift_derby"]:
		var source := FileAccess.get_file_as_string("res://%s.gd" % scene)
		check(source.contains("LOOK.dx(") and source.contains("LOOK.dy(") and not source.contains("relative.x * 0.00"), "%s's mouse look uses the setting" % scene)
	print("LOOK_SETTINGS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
