extends Node

## C1.8 / C5.5 / C2.6 `v2`. The handheld was a screen with a fixed condition and
## one hardcoded crack seed — every device in the game cracked in exactly the
## same places and arrived at the same wear no matter what its owner had been
## through.

const HANDHELD := preload("res://systems/handheld_device.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("C v2 - the device remembers")
	WorldHistory.clear_history()
	var layer := CanvasLayer.new()
	add_child(layer)
	var device: Control = HANDHELD.new()
	layer.add_child(device)
	await get_tree().process_frame

	device.load_device()
	var serial: int = device.serial
	var fresh: float = device.condition
	_check(serial != 0, "a new device gets its own serial (%d)" % serial)
	_check(serial != 90211, "which is not the hardcoded one every device used to share")
	_check(fresh > 0.9, "and starts nearly intact (%.2f)" % fresh)

	# C1.8. Wear accumulates and only goes one way.
	device.take_wear(0.15, "quarry impact")
	_check(device.condition < fresh, "damage lowers the condition (%.2f)" % device.condition)
	device.take_wear(0.1, "dropped on the ramp")
	var worn: float = device.condition
	_check(worn < fresh - 0.2, "and accumulates rather than replacing (%.2f)" % worn)
	device.take_wear(-5.0, "nonsense")
	_check(is_equal_approx(device.condition, worn), "a cracked screen does not heal")

	_check(device.wear_log.size() == 2, "the device remembers what happened to it (%d entries)" % device.wear_log.size())
	_check(str(device.wear_log[0]) == "quarry impact", "in its own words, not as a percentage")

	# It survives a reload, which is the whole point of C1.8.
	var reloaded: Control = HANDHELD.new()
	layer.add_child(reloaded)
	await get_tree().process_frame
	reloaded.load_device()
	_check(reloaded.serial == serial, "a second load is the same device, not a new one")
	_check(is_equal_approx(reloaded.condition, worn), "and it is still as broken as you left it (%.2f)" % reloaded.condition)
	_check(reloaded.wear_log.size() == 2, "with its history intact")

	# C2.6. Reaching a page directly rather than walking past the others.
	reloaded.open_device()
	await get_tree().process_frame
	_check(reloaded.jump_to_mode(3), "a known page can be reached directly")
	_check(str(reloaded.current_mode()) == HANDHELD.MODES[3], "and it is the page asked for (%s)" % reloaded.current_mode())
	_check(not reloaded.jump_to_mode(99), "a page that does not exist is refused")

	print("")
	if failures.is_empty():
		print("C v2 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
