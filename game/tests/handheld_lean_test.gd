extends Node

## I0.10 v2. "Panels are hosted at one fixed size inside the handheld; a map
## you cannot lean into is a picture of a map." Holding LEAN_KEY while a
## hosted panel (INDEX/MAP/WIRE) is open should grow the device's on-screen
## size — and with it the aperture the hosted panel actually renders into —
## and ease back down on release. RADIO and CARRY have no hosted panel to
## gain anything from this, so leaning there should do nothing.

const HANDHELD := preload("res://systems/handheld_device.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _settle(device: Control, frames: int) -> void:
	for _frame in frames:
		device._process(0.05)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})

	var device: Control = HANDHELD.new()
	add_child(device)
	device.size = Vector2(1280, 720)
	device.open_device()
	device.set_mode("INDEX")
	_settle(device, 10)

	var resting_size: Vector2 = device._device_rect.size
	device.lean_override = true
	_settle(device, 40)
	var leaned_size: Vector2 = device._device_rect.size
	_check(leaned_size.x > resting_size.x * 1.1, "holding lean grows the device well past its resting size (%.0f -> %.0f)" % [resting_size.x, leaned_size.x])

	# C6.2. A direction held in the braced posture travels into the physical
	# device instead of remaining an unused movement input.
	var leaned_center: Vector2 = device._device_rect.get_center()
	device.wave_input_override = Vector2(1.0, -1.0).normalized()
	_settle(device, 20)
	var waved_center: Vector2 = device._device_rect.get_center()
	_check(device.wave_vector().x > 0.6 and device.wave_vector().y < -0.6, "lean plus direction produces a full deliberate wave vector")
	_check(waved_center.x > leaned_center.x and waved_center.y < leaned_center.y, "the held object visibly follows the wrist around the edge")

	device.lean_override = false
	device.wave_input_override = Vector2.ZERO
	_settle(device, 40)
	var released_size: Vector2 = device._device_rect.size
	_check(is_equal_approx(released_size.x, resting_size.x), "letting go eases the device back down to its resting size rather than leaving it enlarged (%.0f -> %.0f)" % [leaned_size.x, released_size.x])
	_check(device.wave_vector().length() < 0.01, "releasing the brace returns the wrist and beam to centre")

	print("I0.10 v2 - leaning only does something where there is a panel to lean into")
	device.set_mode("RADIO")
	_settle(device, 10)
	var radio_resting: Vector2 = device._device_rect.size
	device.lean_override = true
	_settle(device, 40)
	var radio_leaned: Vector2 = device._device_rect.size
	_check(is_equal_approx(radio_leaned.x, radio_resting.x), "RADIO has no hosted panel, so leaning does not grow it (%.0f -> %.0f)" % [radio_resting.x, radio_leaned.x])

	print("HANDHELD_LEAN_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
