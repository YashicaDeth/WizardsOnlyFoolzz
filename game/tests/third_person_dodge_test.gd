extends Node

## AG5.28. Third-person evasion is a readable exchange with the locked body,
## not a camera accident or an animation that can overlap every other action.

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
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	for _settle in 6:
		hunt._update_player(1.0 / 60.0)
		await get_tree().physics_frame
	check(hunt.player_body.is_on_floor(), "the dodge fixture begins grounded")

	# Put the opponent due east while deliberately leaving camera yaw facing
	# north. A camera-relative dodge would be observably wrong on this frame.
	var target_at: Vector3 = hunt.player + Vector3(5.0, -0.5, 0.0)
	hunt._spawn_encounter_actor({"instance_id": "dodge_subject", "kind": "hostile"}, target_at)
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.position = target_at
	hunt.third_person = true
	hunt.lock_target = str(actor.subject_id)
	hunt.yaw = 0.0
	var toward: Vector3 = actor.node.global_position - hunt.player
	toward.y = 0.0
	toward = toward.normalized()
	var lateral: Vector3 = hunt._combat_dodge_direction(Vector2.RIGHT)
	check(absf(lateral.dot(toward)) < 0.01, "locked left/right dodge circles the target even before the camera catches up")
	var retreat: Vector3 = hunt._combat_dodge_direction(Vector2.ZERO)
	check(retreat.dot(toward) < -0.99, "a directionless locked dodge retreats from the opponent")

	print("AG5.28 - accepted dodge owns aim, guard, stamina and its receipt")
	hunt.firearm_aiming = true
	hunt.guarding = true
	hunt.stamina = 100.0
	hunt.dodge_cooldown = 0.0
	var receipts_before := PlayerActionLedger.count("player_dodged")
	Input.action_press("move_right")
	hunt._dodge()
	Input.action_release("move_right")
	check(hunt.dodge_remaining > 0.0 and hunt.dodge_direction.dot(lateral) > 0.99, "the accepted dodge uses the locked combat frame")
	check(is_equal_approx(hunt.stamina, 75.0) and is_equal_approx(hunt.dodge_cooldown, 0.75), "one dodge spends its authored stamina and starts one cooldown")
	check(not hunt.firearm_aiming and not hunt.guarding, "dodge lowers firearm aim and guard instead of blending incompatible poses")
	check(PlayerActionLedger.count("player_dodged") == receipts_before + 1, "one accepted dodge produces one action receipt")

	print("AG5.28 - refusals preserve the exchange rather than spending resources")
	hunt.dodge_remaining = 0.0
	hunt.dodge_cooldown = 0.0
	hunt.stamina = 100.0
	hunt.strike_windup = 0.15
	hunt.pending_attack = {"weapon": "cleaver"}
	receipts_before = PlayerActionLedger.count("player_dodged")
	hunt._dodge()
	check(hunt.dodge_remaining <= 0.0 and is_equal_approx(hunt.stamina, 100.0), "a committed melee wind-up cannot also become a dodge")
	check(PlayerActionLedger.count("player_dodged") == receipts_before, "a refused dodge writes no receipt")
	check(hunt.prompt.text == "COMMITTED TO THE SWING", "attack commitment explains the refusal")
	hunt.strike_windup = -1.0
	hunt.pending_attack = {}
	hunt.player_body.position.y += 2.0
	hunt.player_body.velocity = Vector3.ZERO
	hunt._update_player(1.0 / 60.0)
	await get_tree().physics_frame
	check(not hunt.player_body.is_on_floor(), "the airborne refusal fixture has actually left the floor")
	hunt._dodge()
	check(hunt.dodge_remaining <= 0.0 and is_equal_approx(hunt.stamina, 100.0), "an airborne body cannot spend a grounded dodge")

	print("THIRD_PERSON_DODGE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
