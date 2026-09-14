extends Node

## C4.2 `v4`. The hand's illumination must come from the screen state itself:
## lowering the device, exhausting the cell, or losing the backlight removes
## the spill without any world-scene lamp being present in this test.

const HANDHELD := preload("res://systems/handheld_device.gd")

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
	var device: Control = HANDHELD.new()
	add_child(device)
	await get_tree().process_frame

	device.raised = 0.0
	device.battery = 1.0
	device.backlight = 1.0
	check(is_zero_approx(device.screen_luminance()), "a pocketed screen casts no hand light")

	device.raised = 1.0
	check(is_equal_approx(device.screen_luminance(), 1.0), "a sound charged screen reaches full hand luminance")
	device.battery = 0.4
	check(is_equal_approx(device.screen_luminance(), 0.4), "hand light follows the screen's remaining charge")
	device.backlight = 0.5
	check(is_equal_approx(device.screen_luminance(), 0.2), "panel sag dims the hand spill too")
	device.battery = 0.0
	check(is_zero_approx(device.screen_luminance()), "an empty screen cannot leave the hand lit")

	print("HANDHELD_SCREEN_LIGHT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
