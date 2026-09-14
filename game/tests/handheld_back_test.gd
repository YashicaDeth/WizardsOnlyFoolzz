extends Node

## C9.1/C9.2 `v9`. The rear is reached by turning the held object, not by
## opening a seventh page. Its shell then reads the same persistent condition
## as the glass, without inventing a second cosmetic damage value.

const HANDHELD := preload("res://systems/handheld_device.gd")

var failures: Array[String] = []


func _check(condition_met: bool, what: String) -> void:
	if condition_met:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _advance(device: Control, seconds: float) -> void:
	var frames := ceili(seconds / 0.025)
	for _frame in frames:
		device._process(0.025)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})

	var device: Control = HANDHELD.new()
	add_child(device)
	device.set_process(false)
	device.size = Vector2(1280, 720)
	device.open_device()
	_advance(device, 0.3)
	var front_luminance: float = device.screen_luminance()

	print("C9.1 v9 - the same held object turns through its edge")
	device.turn_override = true
	_advance(device, 0.13)
	_check(device.turn > 0.5 and device.turn < 1.0, "holding O crosses the physical edge over time rather than swapping faces instantly")
	_check(device.showing_back(), "the reverse becomes the visible face after the edge")
	_check(not device._clip.visible and not device._overlay.visible, "hosted pages and glass faults remain on the hidden front")
	_check(device._turned_rect.get_center().is_equal_approx(device._device_rect.get_center()), "the object keeps its centre while its face turns")
	_check(device._turned_rect.size.x < device._device_rect.size.x, "a partly turned device has a narrower visible face")
	_check(device.screen_luminance() < front_luminance * 0.05, "the front glass stops lighting the holding hand as it faces away")

	_advance(device, 0.2)
	_check(is_equal_approx(device.turn, 1.0), "the gesture settles on a complete rear face")
	_check(is_equal_approx(device._turned_rect.size.x, device._device_rect.size.x), "the full rear has the same physical width as the front")

	device.turn_override = false
	_advance(device, 0.3)
	_check(is_equal_approx(device.turn, 0.0) and not device.showing_back(), "releasing O turns back to the mirror")
	_check(device._clip.visible and device._overlay.visible, "the real hosted page and its glass return on the front")

	print("C9.2 v9 - the shell reads the device's one persistent condition")
	device.condition = 0.91
	_check(is_equal_approx(device.shell_wear(), 0.09), "a sound shell reports only its small existing wear")
	device.take_wear(0.46, "rear shell test", Vector2(0.2, 0.7))
	_check(is_equal_approx(device.shell_wear(), 0.55), "real device wear increases the shell reading by the same amount")
	device.save_device()
	var reloaded: Control = HANDHELD.new()
	add_child(reloaded)
	reloaded.set_process(false)
	reloaded.load_device()
	_check(is_equal_approx(reloaded.shell_wear(), device.shell_wear()), "shell condition survives reload with the device instead of resetting cosmetically")
	_check(reloaded.impacts.size() == 1, "the rear can place its dent from the impact the device actually remembers")

	print("HANDHELD_BACK_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
