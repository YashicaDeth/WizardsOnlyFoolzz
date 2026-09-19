extends Node

## C10.15. "Somebody could pick it up and know whose it was" — `owner_name` is
## stamped once, the same moment `serial` is fixed for a new device, and never
## rewritten by `drop()`, `confiscate()` or `repossess()`. This proves the
## stamp actually survives changing hands rather than just existing as a field
## nothing reads back.

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

	# A brand new device takes the current player's name, once.
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "GRETCHEN VOSS", "kind": "person"})
	var device: Control = HANDHELD.new()
	add_child(device)
	device.size = Vector2(1280, 720)
	device.load_device()
	_check(device.owner_name == "GRETCHEN VOSS", "a fresh device is stamped with the current player's name (%s)" % device.owner_name)

	var first_serial: int = device.serial

	# Renaming the player subject afterward does not retroactively restamp a
	# device that already exists — the name was captured, not linked live.
	WorldHistory.update_subject("player", {"name": "SOMEBODY ELSE"})
	var second: Control = HANDHELD.new()
	add_child(second)
	second.size = Vector2(1280, 720)
	second.load_device()
	_check(second.owner_name == "GRETCHEN VOSS", "reloading the same device keeps the original stamp, not the player's current name (%s)" % second.owner_name)
	_check(second.serial == first_serial, "reloading found the same device, not a fresh one (sanity check on the test itself)")

	# The stamp survives every transition possession itself goes through.
	device.drop()
	_check(device.owner_name == "GRETCHEN VOSS", "dropping it does not touch the stamp")
	device.repossess()
	_check(device.owner_name == "GRETCHEN VOSS", "repossessing it does not touch the stamp")
	device.confiscate("ROBBED")
	_check(device.owner_name == "GRETCHEN VOSS", "confiscating it does not touch the stamp")
	device.repossess()
	device.save_device()
	var third: Control = HANDHELD.new()
	add_child(third)
	third.size = Vector2(1280, 720)
	third.load_device()
	_check(third.owner_name == "GRETCHEN VOSS", "the stamp round-trips through save/load across all of that (%s)" % third.owner_name)

	# A save written before C10.15 existed has no `owner_name` field at all —
	# it should read as the same fallback `carry.gd` already uses, not crash
	# or come back empty.
	WorldHistory.clear_history()
	WorldHistory.register_subject("handheld", {"serial": 555111, "condition": 0.7, "battery": 0.5, "kind": "object"})
	var legacy: Control = HANDHELD.new()
	add_child(legacy)
	legacy.size = Vector2(1280, 720)
	legacy.load_device()
	_check(legacy.owner_name == "THE HUNTER", "a pre-C10.15 save without owner_name falls back to THE HUNTER (%s)" % legacy.owner_name)

	# No player subject registered at all: the same honest fallback, not an
	# empty stamp nobody can read.
	WorldHistory.clear_history()
	var unnamed: Control = HANDHELD.new()
	add_child(unnamed)
	unnamed.size = Vector2(1280, 720)
	unnamed.load_device()
	_check(unnamed.owner_name == "THE HUNTER", "no player subject at all still stamps a readable fallback (%s)" % unnamed.owner_name)

	print("HANDHELD_OWNER_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
