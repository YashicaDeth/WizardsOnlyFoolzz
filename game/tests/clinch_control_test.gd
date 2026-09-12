extends Node

## O5.4. A clinch was already a negotiation you could win — press, talk, lean,
## take, break. What it could not do was *move*, and a person you cannot move is
## a conversation rather than a position. This covers the two additions: walking
## them where you want them, and holding them in the way of what is shooting at
## you.

const HUNT := preload("res://bone_yard_hunt.tscn")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("O5.4 - walk them, and hold them in the way")
	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	for _settle in 100:
		await get_tree().process_frame

	# With nobody held, a bullet is a bullet.
	hunt.set("grapple_target", "")
	var unheld: Dictionary = hunt.call("grapple_shield", 30.0, Vector3(0, 1, -10))
	_check(is_equal_approx(float(unheld["damage"]), 30.0), "holding nobody shields nothing")
	_check(not bool(unheld["shielded"]), "and reports that honestly")

	# Find somebody real to take hold of.
	var player_start: Vector3 = hunt.get("player")
	hunt.call("_spawn_encounter_actor", {"title": "TEST BODY", "kind": "hostile", "instance_id": "clinch_probe"}, player_start + Vector3(0, 0, -1.2))
	for _frame in 6:
		await get_tree().process_frame
	var actors: Array = hunt.get("encounter_actors")
	_check(actors.size() > 0, "a body can be put in front of the player (%d)" % actors.size())
	if actors.is_empty():
		_finish()
		return
	var actor: Dictionary = actors[0]
	var node: Node3D = actor["node"]
	var player: Vector3 = hunt.get("player")
	# Stand them between the player and the threat.
	node.global_position = player + Vector3(0, 0, -1.2)
	hunt.set("grapple_target", str(actor["subject_id"]))
	for _frame in 3:
		await get_tree().process_frame

	var before_health := _total_health(actor["anatomy"])
	var shielded: Dictionary = hunt.call("grapple_shield", 30.0, player + Vector3(0, 1, -10))
	_check(bool(shielded["shielded"]), "somebody held in the line of fire takes it")
	_check(float(shielded["damage"]) < 30.0, "so far less reaches you (%.1f of 30)" % float(shielded["damage"]))
	_check(float(shielded["damage"]) > 0.0, "but a body is cover, not a wall")
	var after_health := _total_health(actor["anatomy"])
	_check(after_health < before_health, "and the wound lands on them, not nowhere (%.0f -> %.0f)" % [before_health, after_health])

	# Behind you is not in front of you.
	node.global_position = player + Vector3(0, 0, 1.2)
	for _frame in 3:
		await get_tree().process_frame
	var behind: Dictionary = hunt.call("grapple_shield", 30.0, player + Vector3(0, 1, -10))
	_check(not bool(behind["shielded"]), "holding somebody behind you shields nothing")
	_check(is_equal_approx(float(behind["damage"]), 30.0), "and all of it still arrives")

	# The key clash: X leans while a clinch is up, so it must not also guard.
	hunt.set("grapple_target", str(actor["subject_id"]))
	hunt.set("guarding", true)
	for _frame in 4:
		await get_tree().process_frame
	_check(not bool(hunt.get("guarding")), "the guard releases X while somebody is in your hands")

	_finish()


## Every zone added up, so the check is "they were wounded" rather than "they
## were wounded exactly where I guessed".
func _total_health(anatomy) -> float:
	var total := 0.0
	for zone_id in anatomy.zones:
		total += float((anatomy.zones[zone_id] as Dictionary)["health"])
	return total


func _finish() -> void:
	print("")
	if failures.is_empty():
		print("O5.4 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
