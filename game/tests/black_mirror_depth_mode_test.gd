extends Node

## The depth camera's own environment, on the way back up.
##
## `_apply_mode` states the rule: "The depth image is data, not a picture: no
## grade, glow or tonemap on it." `set_active` breaks that rule on the second
## raise. It calls `_apply_mode` -- which, in depth mode, hands the camera the
## flat black linear environment -- and then unconditionally overwrites it with
## `sensor_environment`, the night grade with its raised exposure and contrast.
##
## It is reachable by ordinary play and not by a contrived setup: nothing ever
## resets `mode`, so raising the phone, switching to depth, lowering it and
## raising it again comes back in depth mode, and that is the raise where the
## depth image is graded like a photograph.
##
## The suite drives the real hunt through exactly that sequence, and also checks
## the night path still gets its grade -- otherwise "the camera has some
## environment" would be satisfied by the bug as easily as by the fix.

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
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.handheld.possessed = true

	print("Depth camera - first raise is night vision and gets its grade")
	hunt._toggle_black_mirror()
	var sensor: BlackMirrorCamera = hunt._mirror
	check(sensor != null and sensor.active, "raised")
	check(sensor.mode == "night", "the phone comes up on the low-light sensor")
	check(hunt.camera.environment == sensor.sensor_environment, "and the night grade is the camera's own environment")

	print("Depth camera - switching to it builds the depth image")
	check(sensor.cycle_mode() == "depth", "the mode cycles to depth")
	check(sensor.depth_quad != null and is_instance_valid(sensor.depth_quad), "the depth quad is built on the camera")
	check(sensor.depth_quad.visible, "and shown")
	check(hunt.camera.environment == sensor.depth_environment, "a flat black environment, not the night grade")
	check(hunt.camera.environment.tonemap_mode == Environment.TONE_MAPPER_LINEAR, "linear: the depth image is not tonemapped")
	check(not bool(hunt.camera.environment.adjustment_enabled), "and carries no colour grade")

	print("Depth camera - lowering and raising again is where the grade came back")
	hunt._toggle_black_mirror()
	check(not sensor.active and hunt.camera.environment == null, "lowered")
	check(sensor.mode == "depth", "the mode is remembered while the phone is down")
	hunt._toggle_black_mirror()
	check(sensor.active, "raised again, still in depth mode")
	check(sensor.depth_quad != null and is_instance_valid(sensor.depth_quad) and sensor.depth_quad.visible,
		"the depth image is what the player is looking at")
	check(hunt.camera.environment == sensor.depth_environment,
		"but the camera is still handed the depth environment, not the night grade")
	check(hunt.camera.environment.tonemap_mode == Environment.TONE_MAPPER_LINEAR,
		"still linear after the second raise")
	check(not bool(hunt.camera.environment.adjustment_enabled), "and still ungraded")
	check(hunt.camera.environment != sensor.sensor_environment,
		"the night sensor's exposure and contrast are nowhere near the depth image")

	print("Depth camera - and the night path is untouched by the fix")
	check(sensor.cycle_mode() == "night", "cycles back to night vision")
	check(not sensor.depth_quad.visible, "the depth quad is put away")
	check(hunt.camera.environment == sensor.sensor_environment, "night vision gets its grade again")

	print("BLACK_MIRROR_DEPTH_MODE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
