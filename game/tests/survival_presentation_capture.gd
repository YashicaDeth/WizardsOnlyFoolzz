extends Node

var out_dir := "res://captures"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _settle in 30:
		await get_tree().process_frame

	# Reproduce the playtest state: badly depleted blood and consciousness after
	# a close fight. This goes through the production shader/HUD, not a mock.
	var anatomy = hunt.player_rig.anatomy
	anatomy.blood_remaining = anatomy.blood_capacity * 0.30
	anatomy.consciousness = 18.0
	anatomy.pain = 76.0
	anatomy.critical = true
	anatomy.zones["torso"]["health"] = 34.0
	anatomy.zones["left_arm"]["health"] = 18.0
	hunt.blood_veil.splash(0.72, Vector2(-0.8, 0.2))
	hunt._update_altered_perception()
	for _settle in 18:
		hunt._update_hud()
		await get_tree().process_frame
	if not await _capture("survival_critical_field.png"):
		return

	# The same live body, inspected through the existing V pulmonary reliquary.
	hunt.pulmonary_held = true
	for _settle in 22:
		hunt._update_hud()
		await get_tree().process_frame
	if not await _capture("survival_self_condition.png"):
		return
	get_tree().quit()


func _capture(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var path := "%s/%s" % [out_dir, file_name]
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CAPTURE_FAILED %s (%s)" % [path, error_string(error)])
		get_tree().quit(1)
		return false
	print("CAPTURED: ", path)
	return true
