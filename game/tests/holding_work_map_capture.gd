extends Node

const HOLDINGS := preload("res://systems/ashbloom_holdings.gd")


func _ready() -> void:
	var out_dir := "res://captures"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _settle in 50:
		await get_tree().process_frame

	var bone: Dictionary = HOLDINGS.DEFINITIONS[2]
	HOLDINGS.observe(bone.at)
	HOLDINGS.accept_work("holding_job:bone_yard:claim_crew")
	HOLDINGS.accept_work("holding_job:bone_yard:field_recovery")
	hunt._maintain_holding_work()
	hunt.player = Vector3(float(bone.at.x), 1.5, float(bone.at.y))
	hunt.player_body.position = hunt.player - Vector3.UP * 0.6
	var map: Control = hunt.living_map
	# Survey the holding and its two nearby objective coordinates so the marks
	# are being read over real developed terrain rather than a capture-only map.
	for x in range(-194, -114, 8):
		for z in range(-30, 36, 12):
			map.observe(Vector3(float(x), 0.0, float(z)), 0.0)
	hunt._toggle_panel("map")
	map.zoom = 1.72
	for _settle in 35:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/holding_work_map.png" % out_dir
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CAPTURE_FAILED %s (%s)" % [path, error_string(error)])
		get_tree().quit(1)
		return
	print("CAPTURED: ", path)
	for job_id in ["holding_job:bone_yard:claim_crew", "holding_job:bone_yard:field_recovery"]:
		HOLDINGS.complete_work(job_id, {"method": "visual_proof"})
	map.queue_redraw()
	for _settle in 18:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var resolved_path := "%s/holding_decision_open_map.png" % out_dir
	error = get_viewport().get_texture().get_image().save_png(resolved_path)
	if error != OK:
		push_error("CAPTURE_FAILED %s (%s)" % [resolved_path, error_string(error)])
		get_tree().quit(1)
		return
	print("CAPTURED: ", resolved_path)
	get_tree().quit()
