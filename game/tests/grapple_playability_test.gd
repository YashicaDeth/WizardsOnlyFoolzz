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
	var aimed_floor_y: float = aimed.node.global_position.y
	check(str(hunt._grapple_candidate().subject_id) == str(aimed.subject_id),
		"the body under the reticle wins over encounter spawn order")

	hunt._start_grapple()
	check(hunt.grapple_target == str(aimed.subject_id), "C starts a hold on that intended body")
	check(hunt.player_body.get_collision_exceptions().has(aimed.node)
		and aimed.node.get_collision_exceptions().has(hunt.player_body),
		"the clinch constraint, not two colliding capsules, owns pair spacing")
	hunt.grapple_pushing_override = false
	hunt.grapple_drag_override = Vector2(0, -1)
	var player_before: Vector3 = hunt.player_body.position
	hunt._update_grapple(0.25)
	hunt.grapple_drag_override = null
	check(hunt.player_body.position.distance_to(player_before) > 0.01,
		"WASD advances the actual player body during a clinch")
	check(hunt.player.distance_to(aimed.node.global_position) < 2.0,
		"the held body travels with the player at clinch spacing")
	check(absf(aimed.node.global_position.y - aimed_floor_y) < 0.08,
		"dragging targets the captive capsule height rather than hoisting it toward the camera")

	# Sustained turns and reversals used to make the two capsules fight, jitter,
	# overlap and eventually break the hold. Exercise a small traversal pattern,
	# not just one favourable forward frame.
	var min_gap := INF
	var max_gap := 0.0
	for direction: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		hunt.grapple_drag_override = direction
		for tick in range(12):
			# This test isolates the physical constraint. Outcome tests cover the
			# stamina/advantage contest; keep it neutral while traversing here.
			hunt.grapple_advantage = 0.0
			hunt._update_grapple(0.05)
			var flat_offset: Vector3 = aimed.node.global_position - hunt.player_body.global_position
			flat_offset.y = 0.0
			min_gap = minf(min_gap, flat_offset.length())
			max_gap = maxf(max_gap, flat_offset.length())
	check(hunt.grapple_target == str(aimed.subject_id) and min_gap > 0.72 and max_gap < 1.25,
		"forward, reverse and lateral dragging preserve a stable non-overlapping hold")
	var faces_player: Vector3 = hunt.player_body.global_position - aimed.node.global_position
	faces_player.y = 0.0
	var captive_forward: Vector3 = -aimed.node.global_transform.basis.z
	captive_forward.y = 0.0
	check(faces_player.normalized().dot(captive_forward.normalized()) > 0.8,
		"the captive visibly faces the player throughout the clinch")
	check(hunt.body_motion.grapple_blend > 0.99 and aimed.motion.grapple_blend > 0.99
		and hunt.body_motion.grapple_holder and not aimed.motion.grapple_holder,
		"holder and captive receive distinct readable clinch poses")

	# F remains a legitimate combat decision while bodies are linked. It must
	# not drop the hold, and the camera should look at the pair automatically
	# without requiring a separate lock-on input.
	WorldHistory.record_event("melee_body_hit", {"target": aimed.subject_id})
	var perspective_event := InputEventKey.new()
	perspective_event.keycode = KEY_F
	perspective_event.pressed = true
	hunt._unhandled_input(perspective_event)
	for camera_tick in range(30):
		hunt._update_camera()
	check(hunt.third_person and hunt.grapple_target == str(aimed.subject_id),
		"switching perspective during a clinch preserves the hold")
	check(hunt._camera_combat_focus() == aimed.node,
		"third-person clinch framing automatically targets the linked pair")

	# Ordinary hostile AI must not run on the same held body before the clinch
	# moves it. That was the source of the visible jitter and random breakaways.
	aimed.attack_time = 1.0
	var held_before: Vector3 = aimed.node.global_position
	hunt._update_encounter_actors(0.5)
	check(is_zero_approx(float(aimed.attack_time)) and aimed.node.global_position == held_before,
		"a held actor cannot simultaneously pursue or wind up an attack")

	hunt._break_grapple("TEST RELEASE")
	check(hunt.grapple_target.is_empty(), "Space/release returns cleanly to ordinary control")
	check(not hunt.player_body.get_collision_exceptions().has(aimed.node)
		and not aimed.node.get_collision_exceptions().has(hunt.player_body),
		"release restores ordinary body collision")
	check(is_zero_approx(hunt.body_motion.grapple_blend) and is_zero_approx(aimed.motion.grapple_blend),
		"release clears both clinch poses")

	# The teaching loop has to be repeatable, not merely survivable once. A
	# release must hand the motor back immediately, then let C acquire the same
	# live body again without retaining a collision exception or a zeroed player
	# velocity from the previous constraint.
	var released_from: Vector3 = hunt.player_body.global_position
	hunt.grapple_drag_override = null
	Input.action_press("move_forward")
	for tick in range(4):
		hunt._update_player(1.0 / 60.0)
	Input.action_release("move_forward")
	check(hunt.player_body.global_position.distance_to(released_from) > 0.01
		and hunt.player_body.velocity.length() > 0.01,
		"release returns locomotion without a frozen player velocity")

	# Put the player back at deliberate contact range after proving ordinary
	# movement, then repeat the public acquire path rather than assigning a
	# target directly. This catches stale reciprocal exceptions on reacquire.
	hunt.player_body.global_position = aimed.node.global_position - Vector3(0, 0, 1.5)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.player = hunt.player_body.global_position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.stamina = 100.0
	hunt._start_grapple()
	check(hunt.grapple_target == str(aimed.subject_id)
		and hunt.player_body.get_collision_exceptions().has(aimed.node)
		and aimed.node.get_collision_exceptions().has(hunt.player_body),
		"a released body can be acquired again with one fresh reciprocal exception pair")
	hunt.grapple_drag_override = Vector2(0, -1)
	hunt.grapple_pushing_override = true
	var reacquire_advantage: float = hunt.grapple_advantage
	hunt._update_grapple(0.05)
	hunt.grapple_drag_override = null
	hunt.grapple_pushing_override = null
	check(hunt.player_body.velocity.length() > 0.01 and hunt.grapple_advantage > reacquire_advantage
		and hunt.grapple_target == str(aimed.subject_id),
		"the reacquired clinch still owns live directional pressure rather than a stuck body")
	hunt._break_grapple("TEST FINAL RELEASE")
	check(not hunt.player_body.get_collision_exceptions().has(aimed.node)
		and not aimed.node.get_collision_exceptions().has(hunt.player_body),
		"the reacquired hold also restores ordinary collisions on release")
	off_axis.node.queue_free()
	aimed.node.queue_free()
	print("GRAPPLE_PLAYABILITY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
