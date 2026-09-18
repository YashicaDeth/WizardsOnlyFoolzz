extends Node

## AG5.29. Damage that does not stagger still has to be visible on the body.
## Melee and delayed ballistic hits share one short directional reaction while
## combat_response remains the sole owner of actual interruption/stun rules.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	var actor: Dictionary = hunt._spawn_encounter_actor({
		"instance_id": "hit_reaction_subject", "kind": "hostile", "display_name": "REACTION PROBE",
	}, hunt.player + Vector3(0, -0.5, 2.0))
	(actor.node as Node3D).position = hunt.player + Vector3(0, -0.5, 2.0)
	await get_tree().physics_frame
	var motion := actor.motion as HunterBodyMotion
	var torso := (actor.rig as BaselineHuman).parts.get("torso") as Node3D
	var rest_rotation: Vector3 = torso.get_meta("rest_rotation", Vector3.ZERO)

	print("AG5.29 - a non-staggering melee wound still reads on the body")
	var connected: bool = hunt._attack_nearest_encounter_actor({
		"damage": 6.0, "impulse": 2.0, "damage_type": "cut", "range": 4.1, "weapon": "test edge",
	})
	check(connected, "the light melee fixture lands")
	check(motion.hit_react_time > 0.0 and motion.state == "hit", "the landed melee wound starts a visible reaction without inventing another attack state")
	check(str(actor.state) != "staggered", "the presentation reaction does not counterfeit a gameplay stagger")
	motion.update(motion.hit_react_duration * 0.5, Vector3.ZERO, true, false, false, false)
	check(torso.rotation.distance_to(rest_rotation) > 0.02, "the reaction visibly displaces the torso at its midpoint")
	motion.update(motion.hit_react_duration, Vector3.ZERO, true, false, false, false)
	check(motion.hit_react_time <= 0.0 and torso.rotation.distance_to(rest_rotation) < 0.01, "the body returns cleanly to its locomotion pose")

	print("AG5.29 - a ballistic wound reaches the same readable grammar")
	var torso_hitbox := (actor.rig as BaselineHuman).get_node_or_null("torso_hitbox") as Node
	check(torso_hitbox != null, "the ballistic fixture uses the live anatomy hitbox")
	var resolved: bool = hunt._resolve_body_hit(torso_hitbox, {
		"position": (actor.node as Node3D).global_position + Vector3.UP,
		"direction": Vector3.RIGHT,
	}, {
		"shot_id": 0, "damage": 6.0, "impulse": 3.0, "damage_type": "ballistic", "weapon": "test sidearm",
	})
	check(resolved and motion.hit_react_time > 0.0, "a real ballistic anatomy hit starts the same reaction")
	check(absf(motion.hit_react_direction.x) > 0.5, "the reaction preserves the incoming shot direction")

	print("ENEMY_HIT_REACTION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
