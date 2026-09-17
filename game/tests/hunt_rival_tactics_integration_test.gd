extends Node

## F10.3. The unit test proves the derivation; this test proves the live Hunt
## actor loop asks for it. The same person first closes under a front-hit record,
## then a newly written severing event reverses their next decision without a
## tactic ever being cached on the encounter actor.

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
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	var subject_id := "tactic_probe_actor"
	WorldHistory.register_subject(subject_id, {
		"name": "The Remembering Knife", "kind": "person", "status": "active",
		"is_rival": true,
	})
	for _hit in 5:
		WorldHistory.record_event("melee_body_hit", {"subject_id": subject_id, "zone": "torso"})
	var actor: Dictionary = hunt._spawn_encounter_actor({
		"instance_id": "tactic_probe", "kind": "hostile",
		"display_name": "The Remembering Knife",
	}, hunt.player + Vector3(0, -0.5, 5.0))
	actor.node.position = hunt.player + Vector3(0, -0.5, 5.0)
	actor["tracking_player"] = true
	actor["route_time"] = 0.0
	await get_tree().physics_frame

	var before_circle: float = hunt.player.distance_to(actor.node.global_position)
	hunt._update_encounter_actors(0.25)
	var after_circle: float = hunt.player.distance_to(actor.node.global_position)
	check(after_circle < before_circle,
		"the production actor closes when its current front-hit record says circle (%.2f -> %.2f)" % [before_circle, after_circle])
	check(not actor.has("tactic") and not actor.has("rival_tactic"),
		"the live actor carries no cached tactic")

	WorldHistory.record_event("limb_severed_in_combat", {
		"subject_id": subject_id, "zones": ["left_arm"], "alive": true,
	})
	actor["route_time"] = 0.0
	var before_stand_off: float = hunt.player.distance_to(actor.node.global_position)
	hunt._update_encounter_actors(0.25)
	var after_stand_off: float = hunt.player.distance_to(actor.node.global_position)
	check(after_stand_off > before_stand_off,
		"a newly recorded severing reverses the next live decision into stand-off (%.2f -> %.2f)" % [before_stand_off, after_stand_off])
	check(str(hunt._fresh_rival_tactic(subject_id).get("id", "")) == "stand_off",
		"the production seam still derives its answer from WorldHistory")

	print("HUNT_RIVAL_TACTICS_INTEGRATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
