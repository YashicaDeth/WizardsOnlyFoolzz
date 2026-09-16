extends Node

## C10.1, first seam only. Switching apps must not switch the physical area
## they occupy: hosted documents and device-native instruments share one 16:9
## aperture inside the wider black glass.

const HANDHELD := preload("res://systems/handheld_device.gd")

var failures: Array[String] = []


func _check(condition_met: bool, what: String) -> void:
	if condition_met:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


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
	for _frame in 20:
		device._process(0.05)

	var aperture: Rect2 = device._page_rect
	WorldHistory.world_minute = 0.0
	var shared_date: String = device._calendar_header_text()
	_check(shared_date == "ASHWAKE 01 // DECAN I // YEAR 1 // 00:00", "the chassis owns one in-world calendar header")
	_check(is_equal_approx(aperture.size.x / aperture.size.y, 16.0 / 9.0), "the working aperture is 16:9 inside the wider glass")
	_check(aperture.position.x > device._screen_rect.position.x and aperture.end.x < device._screen_rect.end.x, "the physical mirror remains visible as side gutters")
	_check(device._clip.position.is_equal_approx(aperture.position) and device._clip.size.is_equal_approx(aperture.size), "hosted controls are clipped to the shared aperture")

	for mode in device.MODES:
		_check(device.jump_to_mode(device.MODES.find(mode)), "%s is reachable through the device mode interaction" % mode)
		device._process(0.05)
		_check(device._page_rect.is_equal_approx(aperture), "%s keeps the same working aperture" % mode)
		_check(device._calendar_header_text() == shared_date, "%s keeps the same calendar registration" % mode)

	print("HANDHELD_APERTURE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
