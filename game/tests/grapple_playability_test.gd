extends Node

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
	WorldHistory.clear_history()
	var hunt := HUNT.instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	for existing: Dictionary in hunt.encounter_actors:
		if is_instance_valid(existing.get("node")):
			existing.node.queue_free()
	hunt.encounter_actors.clear()
	hunt.player = Vector3(0, 1.5, 19)
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.yaw = PI

	# Spawn-order used to win even when a different body sat under the reticle.
	hunt._spawn_encounter_actor({"instance_id": "grapple_off_axis", "kind": "hostile"}, hunt.player + Vector3(1.7, -0.6, -1.2))
	var off_axis: Dictionary = hunt.encounter_actors.back()
	hunt._spawn_encounter_actor({"instance_id": "grapple_aimed", "kind": "hostile"}, hunt.player + Vector3(0.0, -0.6, -2.0))
	var aimed: Dictionary = hunt.encounter_actors.back()
	check(str(hunt._grapple_candidate().subject_id) == str(aimed.subject_id),
		"the body under the reticle wins over encounter spawn order")

	hunt._start_grapple()
	check(hunt.grapple_target == str(aimed.subject_id), "C starts a hold on that intended body")
	hunt.grapple_pushing_override = false
	hunt.grapple_drag_override = Vector2(0, -1)
	var player_before: Vector3 = hunt.player_body.position
	hunt._update_grapple(0.25)
	hunt.grapple_drag_override = null
	check(hunt.player_body.position.distance_to(player_before) > 0.01,
		"WASD advances the actual player body during a clinch")
	check(hunt.player.distance_to(aimed.node.global_position) < 2.0,
		"the held body travels with the player at clinch spacing")

	# Ordinary hostile AI must not run on the same held body before the clinch
	# moves it. That was the source of the visible jitter and random breakaways.
	aimed.attack_time = 1.0
	var held_before: Vector3 = aimed.node.global_position
	hunt._update_encounter_actors(0.5)
	check(is_zero_approx(float(aimed.attack_time)) and aimed.node.global_position == held_before,
		"a held actor cannot simultaneously pursue or wind up an attack")

	hunt._break_grapple("TEST RELEASE")
	check(hunt.grapple_target.is_empty(), "Space/release returns cleanly to ordinary control")
	off_axis.node.queue_free()
	aimed.node.queue_free()
	print("GRAPPLE_PLAYABILITY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
