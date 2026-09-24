extends Node

## Phone night vision is the phone's camera: with no phone in hand there is
## nothing to raise, and with the phone possessed the sensor node comes up
## visible on the HUD layer.

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

	hunt.handheld.possessed = false
	hunt._toggle_black_mirror()
	check(not hunt.black_mirror_active, "no phone in hand, no night vision")
	check(hunt.camera.environment == null, "the camera keeps the naked-eye view")
	check(hunt.prompt.text == "NO PHONE IN HAND", "and says why")

	hunt.handheld.possessed = true
	hunt._toggle_black_mirror()
	check(hunt.black_mirror_active, "phone in hand raises the lens")
	check(hunt._mirror != null and hunt._mirror.visible, "the sensor node is up on the HUD layer")

	# Item 2: the depth camera is the phone's second mode.
	var sensor = hunt._mirror
	check(sensor.cycle_mode() == "depth", "the raised phone cycles to its depth camera")
	check(sensor.depth_quad != null and sensor.depth_quad.visible and not sensor.effect.visible, "depth mode draws the depth pass instead of the low-light one")
	check(sensor.cycle_mode() == "night" and not sensor.depth_quad.visible and sensor.effect.visible, "and cycles back to night vision")

	print("PHONE_NIGHT_VISION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
