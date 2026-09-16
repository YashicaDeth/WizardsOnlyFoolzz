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
	var index_energy: float = lamp.light_energy
	hunt.handheld.set_mode("MAP")
	hunt._update_handheld_lamp(0.016)
	check(lamp.spot_range > hunt.handheld.LAMP_RANGE, "the satellite map's greater exposure expands the real rendered beam")
	check(lamp.light_energy > index_energy, "and its extra battery draw appears as more world light rather than an invisible tax")

	# C6.2. The same gesture moving the drawn phone steers the real 3D source.
	var base_position: Vector3 = lamp.position
	var base_rotation: Vector3 = lamp.rotation_degrees
	hunt.handheld.lean_override = true
	hunt.handheld.wave_input_override = Vector2(1.0, -1.0).normalized()
	for _frame in 20:
		hunt.handheld._process(0.05)
	hunt._update_handheld_lamp(0.016)
	check(lamp.position.x > base_position.x and lamp.position.y > base_position.y, "waving up-right physically carries the world light up-right")
	check(lamp.rotation_degrees.y < base_rotation.y and lamp.rotation_degrees.x > base_rotation.x, "the beam yaws and pitches around the corner with the wrist")

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
