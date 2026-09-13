extends Node

## AD2.4. "It survives the transition to third person without dissolving
## (M3.3)." `gothic_field_hud.gd` is a screen-space overlay with no
## dependency on which camera mode `_update_camera()` is driving — nothing
## in `bone_yard_hunt.gd`'s `_update_hud()` gates `field_interface.set_state()`
## or its visibility on `third_person` at all, so there is nothing here that
## *could* dissolve on the switch. This captures the claim rather than
## reasoning about it: the same HUD, alive, with the camera actually in the
## third-person position `_update_camera()` computes when `third_person` is
## true, next to a fresh first-person shot for the same state.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt._equip_weapon(1)
	hunt.health = 62.0
	hunt.stamina = 38.0
	hunt._spawn_encounter_actor({"instance_id": "hud_capture_target", "kind": "hostile"}, hunt.player + Vector3(0, -0.5, 5))

	for _settle in 20:
		await get_tree().process_frame
	hunt._update_hud()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var first_person := get_viewport().get_texture().get_image()
	var first_path := "%s/ad2_4_field_hud_first_person.png" % out_dir
	if first_person.save_png(first_path) != OK:
		print("CAPTURE_FAILED ", first_path)
		get_tree().quit(1)
		return
	print("CAPTURED: ", first_path)

	# The third-person camera path in `_update_camera()` only activates while
	# `resolution_ui` is visible and a `resolution_target` is set — the exact
	# state a downed-body decision uses. Driven directly rather than earning
	# a real third-person unlock, since what this proves is the HUD, not the
	# unlock gate AD10.3 already covers.
	hunt.third_person = true
	var target_actor: Dictionary = hunt.encounter_actors.back()
	hunt.resolution_target = str(target_actor.subject_id)
	hunt.resolution_ui.visible = true
	hunt._update_camera()
	hunt.resolution_ui.visible = false
	for _settle in 10:
		await get_tree().process_frame
	hunt._update_hud()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var third_person := get_viewport().get_texture().get_image()
	var third_path := "%s/ad2_4_field_hud_third_person.png" % out_dir
	if third_person.save_png(third_path) != OK:
		print("CAPTURE_FAILED ", third_path)
		get_tree().quit(1)
		return
	print("CAPTURED: ", third_path)
	get_tree().quit()
