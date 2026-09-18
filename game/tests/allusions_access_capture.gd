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
	var j_key := InputEventKey.new()
	j_key.keycode = KEY_J
	j_key.pressed = true
	hunt._unhandled_input(j_key)
	for _settle in 18:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/j_allusions_artwork_only.png" % out_dir
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CAPTURE_FAILED %s (%s)" % [path, error_string(error)])
		get_tree().quit(1)
		return
	print("CAPTURED: ", path)
	get_tree().quit()
