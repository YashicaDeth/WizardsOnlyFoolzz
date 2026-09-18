extends Node

var out_dir := "P:/GameDev/Temp"


func _shot(name: String) -> void:
	for _frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED " if result == OK else "CAPTURE_FAILED ", path)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldClock.set_hour(13.0)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	hunt.set_physics_process(false)
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = PI
	hunt.pitch = -0.04
	hunt._equip_weapon(0)

	# One live opponent, lock-on and the production third-person combat camera.
	var target: Dictionary = hunt._spawn_encounter_actor({
		"instance_id": "playtest_target", "kind": "hostile", "display_name": "LOCK PROBE",
	}, hunt.player + Vector3(0, -0.5, -5.0))
	(target.node as Node3D).position = hunt.player + Vector3(0, -0.5, -5.0)
	hunt.third_person = true
	hunt.body_motion.set_perspective(false)
	hunt.perspective_blend = 1.0
	hunt.camera_ready = false
	hunt._toggle_lock()
	for _frame in 36:
		hunt._steer_lock(1.0 / 60.0)
		hunt._update_camera()
		hunt._update_hud()
		await get_tree().process_frame
	print("THIRD_PERSON_CAMERA player=", hunt.player, " camera=", hunt.camera.global_position,
		" gap=", hunt.camera.global_position.distance_to(hunt.player))
	await _shot("combat_playtest_camera_fallback")

	# Repeat the same lock in open ground so the evidence includes the intended
	# shoulder composition as well as the tight-space fallback above.
	hunt.player_body.position = Vector3(175, 0.9, 125)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	(target.node as Node3D).position = hunt.player + Vector3(0, -0.5, -5.0)
	hunt.camera_ready = false
	for _frame in 24:
		hunt.body_motion.update(1.0 / 60.0, Vector3.ZERO, true, false, false, false)
		hunt._steer_lock(1.0 / 60.0)
		hunt._update_camera()
		hunt._update_hud()
		await get_tree().process_frame
	await _shot("combat_playtest_third_person_lock")

	# The narrated playtest found that RMB simply fired another shot and there
	# was no firearm aim at all. Capture the production held stance and narrowed
	# lens in first person before returning to the melee grip sheet below.
	hunt.third_person = false
	hunt.body_motion.set_perspective(true)
	hunt.perspective_blend = 0.0
	hunt.lock_target = ""
	hunt._equip_weapon(2)
	hunt.firearm_aiming = true
	for _frame in 24:
		hunt._update_player(1.0 / 60.0)
		hunt._update_camera()
		hunt._update_hud()
		await get_tree().process_frame
	await _shot("combat_playtest_firearm_aim")
	hunt.firearm_aiming = false

	# The same production viewmodel in all three sword stances. These frames
	# catch the exact failure where half-sword numbers changed while its hand did not.
	hunt._equip_weapon(0)
	hunt.third_person = false
	hunt.body_motion.set_perspective(true)
	hunt.perspective_blend = 0.0
	hunt.lock_target = ""
	for grip_name in ["two_hand", "one_hand", "half_sword"]:
		hunt.current_grip = grip_name
		hunt.arsenal.apply_grip(grip_name)
		hunt._carry_current_weapon(true)
		for _frame in 18:
			hunt.body_motion.update(1.0 / 60.0, Vector3.ZERO, true, false, false, false)
			hunt._advance_arm(1.0 / 60.0)
			hunt._update_held_inspection(1.0 / 60.0)
			hunt._update_first_person_forearms()
			hunt._update_camera()
			hunt._update_hud()
			await get_tree().process_frame
		await _shot("combat_playtest_%s" % grip_name)
	get_tree().quit()
