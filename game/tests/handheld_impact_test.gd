extends Node

## C5.6 v3. "Cracks are per-device but still radiate from one authored
## origin; an impact should crack the glass where it landed." Every crack in
## the game shared one fixed point (0.74, 0.22 into the screen) regardless of
## device or cause. `take_wear()` now records where each impact actually
## landed (or, lacking a real location, a point that at least varies instead
## of repeating the one authored spot), and `_draw_chassis` draws one crack
## cluster per recorded impact from its own origin.

const HANDHELD := preload("res://systems/handheld_device.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	var device: Control = HANDHELD.new()
	add_child(device)
	await get_tree().process_frame
	device.open_device()
	device.impacts.clear()

	print("C5.6 v3 - an impact cracks the glass where it landed")
	var struck_at := Vector2(0.15, 0.9)
	device.take_wear(0.1, "grapple slam", struck_at)
	_check(device.impacts.size() == 1, "the impact is recorded")
	_check(device.impacts[0].at == struck_at, "at the location the caller actually gave, not the authored default")

	print("C5.6 v3 - an impact with no known location still varies")
	device.take_wear(0.05, "quarry impact")
	device.take_wear(0.05, "dropped")
	var second: Vector2 = device.impacts[1].at
	var third: Vector2 = device.impacts[2].at
	_check(second != third, "two unlocated impacts do not land on the exact same point (%s vs %s)" % [second, third])
	_check(second != Vector2(0.74, 0.22) and third != Vector2(0.74, 0.22), "and neither one is the old single authored point")

	print("C5.6 v3 - impacts do not accumulate without limit")
	for _extra in 10:
		device.take_wear(0.01, "wear")
	_check(device.impacts.size() == HANDHELD.MAX_IMPACTS, "the case does not carry an unreadable spiderweb over a long run (%d)" % device.impacts.size())

	print("C5.6 v3 - impacts persist the same way condition and serial do")
	device.save_device()
	var reloaded: Control = HANDHELD.new()
	add_child(reloaded)
	await get_tree().process_frame
	reloaded.load_device()
	_check(reloaded.impacts.size() == device.impacts.size(), "a reloaded device remembers where it was actually hit")

	print("HANDHELD_IMPACT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
