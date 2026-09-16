extends Node

## AE1.1, live rather than just the formula: a real hostile, at a real
## distance, under real daylight, has to actually move player_unseen/
## player_visibility — and a real wall between them has to actually count
## as cover, not just a parameter nobody wires up.

const HUNT := preload("res://bone_yard_hunt.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var hunt: Node = HUNT.instantiate()
	add_child(hunt)
	for _settle in 30:
		await get_tree().process_frame

	WorldClock.set_hour(13.0)
	hunt.set("player", Vector3(0, 1.5, 0))
	hunt.player_body.position = Vector3(0, 0.9, 0)

	# No hostile hunting at all: nothing to be seen by.
	hunt.encounter_actors.clear()
	hunt.call("_update_perception", 0.1)
	check(absf(hunt.get("player_visibility")) < 0.001, "with nobody hunting you, there is nothing to be seen by")
	check(bool(hunt.get("player_unseen")), "and you read as unseen by default")

	# A real hostile, close, in daylight, with a clear line of sight.
	hunt._spawn_encounter_actor({"instance_id": "perception_probe", "kind": "hostile"}, Vector3(3, 0.9, 0))
	hunt.call("_update_perception", 0.1)
	var close_visibility: float = hunt.get("player_visibility")
	check(close_visibility > 0.0, "a real hostile nearby actually produces a real verdict (%.3f)" % close_visibility)
	check(not bool(hunt.get("player_unseen")), "and at three metres in daylight with a clear view, you are seen")

	# The same hostile, far away instead.
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.global_position = Vector3(200, 0.9, 0)
	hunt.call("_update_perception", 0.1)
	var far_visibility: float = hunt.get("player_visibility")
	check(far_visibility < close_visibility, "moved far away, the same hostile sees you less (%.3f vs %.3f)" % [far_visibility, close_visibility])

	# C7.1. At night and twenty metres out the holder is still unresolved, but
	# the charged raised screen is a distinct source the hostile can follow.
	WorldClock.set_hour(1.0)
	actor.node.global_position = Vector3(20, 0.9, 0)
	hunt.handheld.battery = 1.0
	hunt.handheld.raised = 1.0
	hunt.handheld.is_open = true
	hunt.call("_update_perception", 0.1)
	check(bool(actor.get("tracking_light", false)), "at night a hunter notices the raised handheld at twenty metres")
	check(not bool(actor.get("tracking_player", true)), "the same hunter has not yet resolved the person behind the light")
	check(bool(hunt.get("player_unseen")), "the player remains unseen during the emitted-light warning interval")
	hunt.call("_update_encounter_actors", 0.1)
	check((actor.node as CharacterBody3D).velocity.length() > 0.0, "the emitted-light verdict enters the real pursuit state machine")

	hunt.handheld.raised = 0.0
	hunt.call("_update_perception", 0.1)
	check(not bool(actor.get("tracking_light", true)), "pocketing the screen removes the trail a hunter was following")

	# A real wall between a close hostile and the player: real cover.
	actor.node.global_position = Vector3(3, 0.9, 0)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 3.0, 3.0)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(1.5, 1.5, 0)
	hunt.add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.call("_update_perception", 0.1)
	var covered_visibility: float = hunt.get("player_visibility")
	check(covered_visibility < close_visibility, "a real wall between you and the same hostile actually counts as cover (%.3f vs %.3f)" % [covered_visibility, close_visibility])

	if failures.is_empty():
		print("perception integration: a real verdict against a real hostile")
		get_tree().quit(0)
	else:
		print("perception integration FAILURES: ", failures)
		get_tree().quit(1)
