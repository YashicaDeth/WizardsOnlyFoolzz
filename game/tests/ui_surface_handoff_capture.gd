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
	for _settle in 24:
		await get_tree().process_frame

	# Reproduce the formerly broken M -> G path, then photograph the endpoint.
	# If the map remains alive beneath the device its title block and chart marks
	# are plainly visible around the physical phone.
	hunt._toggle_panel("map")
	hunt._toggle_handheld_surface()
	for _settle in 24:
		await get_tree().process_frame
	if not await _capture("ui_handoff_map_to_phone.png"):
		return

	# Reproduce the inverse phone -> J handoff. The result should be one artwork
	# surface, without a lit/draining phone composited beneath it.
	hunt._toggle_artwork()
	for _settle in 18:
		await get_tree().process_frame
	if not await _capture("ui_handoff_phone_to_artwork.png"):
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
