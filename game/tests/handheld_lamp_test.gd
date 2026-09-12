extends Node

## AS1. "The light can become really warped at night... having light coming
## off the phone when you have it in your hand, then you can wave it around
## or pocket it." A real 3D light bolted to the camera, on exactly when the
## device is actually open, drained by a real independent battery (AS1.3 -
## the status page's "CELL %" used to be device condition wearing a
## battery's name) rather than the device's own structural damage.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("AS1.1 - a real light exists, bolted to the camera, off by default")
	check(hunt.handheld_light != null, "the torch exists")
	check(hunt.handheld_light.get_parent() == hunt.camera, "and it is bolted to the camera, not the world or the HUD")
	check(not hunt.handheld_light.visible, "off while the device is closed")

	print("AS1.2/AS1.4 - it comes on with the device and goes with it into a pocket")
	hunt.handheld.open_device()
	hunt._update_handheld_light(0.016)
	check(hunt.handheld_light.visible, "raising the device lights the torch")
	hunt.handheld.close_device()
	hunt._update_handheld_light(0.016)
	check(not hunt.handheld_light.visible, "pocketing it takes the light with it")

	print("AS1.3 - a real battery, independent of device condition")
	hunt.handheld.open_device()
	hunt.handheld.condition = 1.0
	hunt.handheld.battery = 1.0
	var before: float = hunt.handheld.battery_percent()
	for _tick in 30:
		hunt.handheld._process(1.0)
	check(hunt.handheld.battery_percent() < before, "the battery actually drains while the device is held up (%.3f -> %.3f)" % [before, hunt.handheld.battery_percent()])
	check(is_equal_approx(hunt.handheld.condition, 1.0), "and draining it does not touch the device's own structural condition")

	hunt.handheld.close_device()
	var closed_battery: float = hunt.handheld.battery_percent()
	for _tick in 30:
		hunt.handheld._process(1.0)
	check(is_equal_approx(hunt.handheld.battery_percent(), closed_battery), "it does not drain while the device sits closed")

	print("AS1.3 - it can actually run out")
	hunt.handheld.open_device()
	hunt.handheld.battery = 0.0
	check(not hunt.handheld.torch_active(), "at zero charge the torch reports itself off even though the device is open")
	hunt._update_handheld_light(0.016)
	check(not hunt.handheld_light.visible, "and the real light in the world goes dark with it")

	hunt.queue_free()
	print("HANDHELD_LAMP_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
