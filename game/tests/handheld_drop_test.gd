extends Node

## C1.7 `v2`. `drop()`/`confiscate()`/`possessed` were all built and none of
## them were reachable from a real game session — nothing anywhere called
## them. This wires the player-facing half: DROP_KEY, edge-detected against
## `possessed` rather than `is_open` (a pocketed device is still yours to
## drop), calls `drop()` and emits `dropped(payload)` for whoever owns 3D
## space to spawn something pickable. Confiscation still has no caller — that
## half is a robbery/defeat event this file cannot originate on its own — and
## stays open.

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
	device.load_device()
	device.open_device()
	_settle(device, 5)
	_check(device.is_open, "the device opens normally before any of this")

	var payloads: Array[Dictionary] = []
	device.dropped.connect(func(payload: Dictionary) -> void: payloads.append(payload))

	device.drop_key_override = false
	_settle(device, 3)
	_check(device.possessed and device.is_open, "the key starting unpressed does nothing on its own")

	device.drop_key_override = true
	_settle(device, 1)
	_check(not device.possessed, "pressing the drop key actually drops it")
	_check(not device.is_open, "and closes it — the identical end state confiscation reaches")
	_check(payloads.size() == 1, "the dropped signal fired exactly once (%d)" % payloads.size())
	_check(int(payloads[0].get("serial", -1)) == device.serial, "carrying this device's own real serial, not a placeholder (%d)" % int(payloads[0].get("serial", -1)))

	# Held down rather than tapped: the edge-detect has to mean this, not "at
	# most one drop a second" by luck of the frame rate.
	_settle(device, 30)
	_check(payloads.size() == 1, "holding the key down after the drop does not keep firing it (%d)" % payloads.size())

	device.open_device()
	_check(not device.is_open, "a dropped device refuses to reopen — open_device()'s own possessed check still holds")

	device.drop_key_override = false
	_settle(device, 3)
	device.drop_key_override = true
	_settle(device, 1)
	_check(payloads.size() == 1, "pressing drop again while already not possessed is a no-op, not a second event (%d)" % payloads.size())

	device.repossess()
	device.drop_key_override = false
	_settle(device, 3)
	device.drop_key_override = true
	_settle(device, 1)
	_check(payloads.size() == 2, "repossessing it makes it droppable again — this is the physical object coming back, not a new one (%d)" % payloads.size())

	print("HANDHELD_DROP_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
