extends Node

## AS1.1/AS1.3/AS1.5. The handheld's light is not a torch that never runs
## out — battery drains only while actually held up, floors at zero rather
## than going negative, recharges slower while pocketed, and survives a
## reload the same way condition and the serial already do.

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
	var layer := CanvasLayer.new()
	add_child(layer)
	var device: Control = HANDHELD.new()
	layer.add_child(device)
	await get_tree().process_frame
	device.load_device()

	check(absf(device.battery - 1.0) < 0.001, "a new device starts at full charge")
	check(not device.is_lit(), "and is not lit while pocketed")
	check(absf(device.light_radius()) < 0.001, "so it throws no light yet either")

	# Raised and lit: draining, and only while actually held up.
	device.raised = 1.0
	device._drive_battery(1.0)
	check(device.battery < 1.0, "holding it up actually drains it")
	check(device.is_lit(), "and while raised with charge, it is lit")
	check(absf(device.light_radius() - HANDHELD.LAMP_RANGE) < 0.001, "reaching its full range")

	# Drain it out entirely.
	device._drive_battery(4000.0)
	check(absf(device.battery) < 0.001, "enough continuous use runs it out")
	check(device.battery >= 0.0, "and it floors at zero rather than going negative")
	check(not device.is_lit(), "an empty battery is not lit even while raised")
	check(absf(device.light_radius()) < 0.001, "so there is nothing left to give away (AS1.5)")

	# Pocketed: recharging, slower than it drained.
	device.raised = 0.0
	device._drive_battery(1.0)
	check(device.battery > 0.0, "pocketing it lets it recharge")
	var after_one_second: float = device.battery
	device._drive_battery(1.0)
	check(device.battery > after_one_second, "and it keeps climbing while left alone")
	check(device.battery < after_one_second * 4.0, "recharging noticeably slower than it drained")

	device.raised = 1.0
	device._drive_battery(0.001)
	var barely_drained: float = device.battery
	# It survives a reload, the same as condition and the serial already do.
	device.raised = 0.0
	device.close_device()
	var reloaded: Control = HANDHELD.new()
	layer.add_child(reloaded)
	await get_tree().process_frame
	reloaded.load_device()
	check(absf(reloaded.battery - barely_drained) < 0.01, "a reload keeps whatever charge was left (%.3f vs %.3f)" % [reloaded.battery, barely_drained])

	if failures.is_empty():
		print("handheld battery: a resource, not a torch")
		get_tree().quit(0)
	else:
		print("handheld battery FAILURES: ", failures)
		get_tree().quit(1)
