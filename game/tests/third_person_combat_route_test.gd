extends Node

## Production Hunt regression for Greg's 4 October report: third-person combat
## was made out of individually-tested parts that were not wired into one
## exchange. This drives the real Hunt from lock acquisition through camera,
## stance, committed swing and anatomical contact.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _camera_reach(hunt) -> float:
	var offset: Vector3 = hunt.camera.global_position - hunt.player_body.global_position
	return Vector2(offset.x, offset.z).length()


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0.0, 0.9, 19.0)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt.third_person = true
	hunt.perspective_blend = 1.0
	hunt._equip_weapon(0)

	var target_at: Vector3 = hunt.player + Vector3(0.0, -0.5, 2.2)
	hunt._spawn_encounter_actor({
		"instance_id": "third_person_route_target",
		"kind": "hostile",
		"tier": "scavenger",
	}, target_at)
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.position = target_at
	# A committed opponent is open, keeping the proof about contact rather than
	# the deterministic fighter-tier defence roll.
	actor.attack_time = 1.0
	await get_tree().physics_frame

	print("THIRD PERSON ROUTE - aim and camera share one living lock")
	hunt._toggle_lock()
	check(hunt.lock_target == str(actor.subject_id), "R3/Z acquires the standing hostile in front")
	for _frame in 40:
		hunt._steer_lock(1.0 / 60.0)
		hunt._update_camera()
	var target_focus: Vector3 = actor.node.global_position + Vector3.UP * 1.1
	check(not hunt.camera.is_position_behind(target_focus), "the shoulder camera keeps the locked body in front")
	check(_camera_reach(hunt) > 1.5, "open ground preserves a readable shoulder camera")

	print("THIRD PERSON ROUTE - circling is a CombatStance, not free-run legs")
	Input.action_press("move_right")
	hunt._update_player(1.0 / 60.0)
	check(hunt.body_motion.strafe_lateral > 0.5, "locked right input reaches CombatStance.strafe")
	var strafe_pose := CombatStance.strafe(hunt.body_motion.strafe_lateral, hunt.body_motion.strafe_approach)
	check(not strafe_pose.is_empty() and is_zero_approx(float(strafe_pose.torso.angles.y)), "the fed stance keeps the torso square to the target")

	print("THIRD PERSON ROUTE - a lock wins over circling input for the swing")
	var wounds_before: int = actor.anatomy.wounds.size()
	hunt.attack_cooldown = 0.0
	hunt.arsenal.cooldown = 0.0
	hunt.stamina = 100.0
	hunt._attack()
	var moveset = hunt.get("third_person_moveset")
	check(moveset != null and moveset.is_attacking(), "the production Hunt starts the authored SwordMoveset")
	# Advance past the authored wind-up. Contact must happen in the active
	# phase while the left stick is still circling, not wherever the stick has
	# moved by the old one-shot proximity timer.
	if hunt.has_method("_advance_third_person_melee"):
		for _frame in 30:
			hunt.call("_advance_third_person_melee", 1.0 / 60.0)
			if actor.anatomy.wounds.size() > wounds_before:
				break
	else:
		# The old Hunt has no authored third-person clock. Resolve its legacy
		# contact timer so this same run records the circling/lock failure too.
		hunt._resolve_strike()
	check(actor.anatomy.wounds.size() > wounds_before, "the committed locked swing registers on the locked anatomy while circling")
	check(not hunt.body_motion.moveset_phase.is_empty(), "the authored windup/active/recovery pose reaches HunterBodyMotion")
	Input.action_release("move_right")

	print("THIRD PERSON ROUTE - an incapacitated body releases aim and camera")
	actor.anatomy.go_down()
	hunt._steer_lock(1.0 / 60.0)
	check(hunt.lock_target.is_empty(), "lock-on releases a body once it is down")
	check(hunt._camera_combat_focus() == null, "the camera stops orbiting the incapacitated body")

	print("THIRD_PERSON_COMBAT_ROUTE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
