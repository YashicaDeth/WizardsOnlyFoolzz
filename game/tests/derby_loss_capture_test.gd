extends Node

## P4.5. A lost derby heat used to leave through the exact same door a won one
## does - a relabelled "WRECKED" countdown, no captor, no consequence, nothing
## a player could point to and call interesting. `_finish_round("lost")` now
## routes the loss through `DefeatRouter`, the same mechanism a Bone Yard
## capture already uses (F5: defeat changes ownership and position, it is not
## a reload), before the scene hands off to `bone_yard_hunt.tscn`. This drives
## a real loss and then the real hunt scene it hands off to, and checks the
## captivity lands on arrival rather than a fresh walk-in.

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

	var derby: Node = load("res://rift_derby.tscn").instantiate()
	add_child(derby)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var captor_id: String = CastNames.id_for(derby.CAPTAIN_SLOT)

	derby.round_state = "active"
	derby.integrity = 0
	derby._finish_round("lost")

	var player := WorldHistory.subject("player")
	check(str(player.get("status", "")) in ["shackled", "stamped", "conscripted"],
		"a lost heat routes through the same captivity states a Bone Yard capture does")
	check(str(player.get("captor_id", "")) == captor_id, "the derby captain is recorded as the captor")
	check(int(player.get("defeats", 0)) == 1, "the loss counts as a real defeat, not just a label")
	check(WorldHistory.event_count("player_captured") == 1, "the capture is written into history")
	derby.queue_free()
	await get_tree().process_frame

	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().process_frame
	check(hunt.health == 1, "arriving already captured lands in captivity, not a fresh walk-in")
	check(hunt.prompt.text.contains("DIE DELIBERATELY"), "the captivity prompt is shown on arrival")
	check(int(WorldHistory.subject("player").get("defeats", 0)) == 1,
		"arriving at the hunt does not capture the player a second time")
	hunt.queue_free()

	print("DERBY_LOSS_CAPTURE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
