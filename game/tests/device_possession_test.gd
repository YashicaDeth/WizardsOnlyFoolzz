extends Node

## C1.7 `v2`. "It can be dropped, and it can be taken off you." A drop and a
## confiscation are the same underlying transition — unraisable, closed,
## `possessed` false — reached through two different callers and recorded
## as two different event types, so the world can tell them apart later even
## though the player cannot use the device either way in the meantime.

const HANDHELD := preload("res://systems/handheld_device.gd")
const ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("C1.7 - dropped, taken, and got back")
	WorldHistory.clear_history()
	var layer := CanvasLayer.new()
	add_child(layer)
	var device: Control = HANDHELD.new()
	layer.add_child(device)
	await get_tree().process_frame

	device.load_device()
	_check(device.possessed, "a fresh device starts in your hand")

	device.open_device()
	await get_tree().process_frame
	_check(device.is_open, "and can be raised while it is")

	var dropped: Dictionary = device.drop()
	_check(bool(dropped.get("ok", false)), "dropping it while you have it succeeds")
	_check(not device.possessed, "and it is genuinely not in your hand any more")
	_check(not device.is_open, "closed by the same act, not left hanging open with nothing holding it")
	_check(int(dropped.get("serial", -1)) == device.serial, "the drop hands back this exact device's own identity")

	device.open_device()
	await get_tree().process_frame
	_check(not device.is_open, "raising a dropped device is refused, not a silent no-op")

	var again: Dictionary = device.drop()
	_check(not bool(again.get("ok", false)), "dropping what is already gone is refused, not a phantom second drop")

	device.repossess()
	_check(device.possessed, "picking it back up actually restores possession")
	device.open_device()
	await get_tree().process_frame
	_check(device.is_open, "and it can be raised again")

	# It survives a reload — the device's own condition matters more when it
	# has just changed hands than at any other time.
	device.take_wear(0.2, "dropped on the ramp")
	var worn_condition: float = device.condition
	var confiscated: Dictionary = device.confiscate("robbed at the checkpoint")
	_check(bool(confiscated.get("ok", false)), "confiscation works the same way a drop does")
	_check(not device.possessed, "and leaves it out of your hand the same way")

	var reloaded: Control = HANDHELD.new()
	layer.add_child(reloaded)
	await get_tree().process_frame
	reloaded.load_device()
	_check(not reloaded.possessed, "a reload remembers it is still gone")
	_check(is_equal_approx(reloaded.condition, worn_condition), "carrying the same wear, not a fresh replacement")
	reloaded.open_device()
	await get_tree().process_frame
	_check(not reloaded.is_open, "and it still cannot be raised after the reload")

	var events: Array[String] = []
	for event in WorldHistory.events:
		events.append(str(event.get("type", "")))
	_check(events.count("device_dropped") == 1, "a real drop is a real, distinct event")
	_check(events.count("device_taken") == 1, "and a confiscation is a different one, not the same event relabelled")
	_check(events.count("device_repossessed") == 1, "getting it back is its own event too")
	_check(ACTION_LEDGER.count("device_dropped") == 1, "a deliberate drop receives one player-action receipt")
	_check(ACTION_LEDGER.count("device_repossessed") == 1, "deliberate recovery receives one player-action receipt")
	_check(ACTION_LEDGER.count("device_taken") == 0, "confiscation is not falsely credited as the player's act")
	var drop_event: Dictionary = WorldHistory.events.filter(func(event: Dictionary): return str(event.get("type", "")) == "device_dropped")[0]
	_check(not str((drop_event.get("details", {}) as Dictionary).get("action_id", "")).is_empty(), "the established drop event carries its stable action id")
	_check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "drop, confiscation and recovery all close their nested device transactions")

	print("")
	if failures.is_empty():
		print("C1.7 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
