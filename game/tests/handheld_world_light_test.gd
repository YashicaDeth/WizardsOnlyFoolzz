extends Node

## C4.1 `v4`. The handheld's own unit test can prove that it asks for light,
## but not that the running Hunt Grounds turns that answer into illumination.
## This integration check guards the world-space half: a real shadow-casting
## SpotLight3D, carried by the camera, whose visibility follows the device.

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
	await get_tree().process_frame

	var lamp = hunt.handheld_lamp
	check(lamp is SpotLight3D, "the handheld drives a real world-space SpotLight3D")
	check(lamp.get_parent() == hunt.camera, "the light travels with the held viewpoint")
	check(lamp.shadow_enabled, "the light casts real shadows")
	check(lamp.position.x > 0.0 and lamp.position.y < 0.0, "the source sits off-centre where the raised device is held")
	check(is_equal_approx(lamp.spot_range, hunt.handheld.LAMP_RANGE), "the rendered beam and device visibility radius share one range")

	hunt.handheld.battery = 1.0
	hunt.handheld.open_device()
	hunt.handheld.raised = 1.0
	hunt._update_handheld_lamp(0.016)
	check(hunt.handheld.is_lit(), "a charged raised screen reports itself lit")
	check(lamp.visible and lamp.light_energy > 0.0, "raising it puts real light into the running world")

	hunt.handheld.close_device()
	hunt.handheld.raised = 0.0
	hunt._update_handheld_lamp(0.016)
	check(not lamp.visible, "pocketing it removes the world light")

	if failures.is_empty():
		print("handheld world light: screen state reaches a real 3D lamp")
		get_tree().quit(0)
	else:
		print("handheld world light FAILURES: ", failures)
		get_tree().quit(1)
