extends Node

## Visual check harness. Headless runs prove a scene has no runtime errors but
## render nothing, so look work cannot be verified that way. This loads a scene,
## lets it settle, and writes one PNG.
##
## Usage:
##   Godot --path game res://tests/capture_scene.tscn -- \
##       --scene=res://rift_derby.tscn --out=P:/GameDev/Temp/look.png --frames=120

func _ready() -> void:
	var scene_path := "res://rift_derby.tscn"
	var out_path := "P:/GameDev/Temp/capture.png"
	var settle_frames := 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
		elif argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--frames="):
			settle_frames = int(argument.trim_prefix("--frames="))

	var archive_subject := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--archive="):
			archive_subject = argument.trim_prefix("--archive=")

	var packed := load(scene_path)
	if packed == null:
		print("CAPTURE_FAILED: could not load ", scene_path)
		get_tree().quit(1)
		return
	var scene: Node = packed.instantiate()
	add_child(scene)

	if not archive_subject.is_empty():
		await get_tree().process_frame
		var archive: Node = scene.get_node_or_null("HUD/CharacterArchive")
		if archive == null:
			print("CAPTURE_FAILED: no HUD/CharacterArchive in ", scene_path)
			get_tree().quit(1)
			return
		# The host scene re-asserts archive visibility from panel_mode every frame,
		# so opening the control alone is undone on the next tick.
		if "panel_mode" in scene:
			scene.set("panel_mode", "tree")
		archive.open_archive(archive_subject)

	# Procedural noise textures and the sky resolve over several frames; capturing
	# immediately yields an untextured, unlit frame that misrepresents the look.
	for _index in settle_frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	if error != OK:
		print("CAPTURE_FAILED: save_png returned ", error)
		get_tree().quit(1)
		return
	print("CAPTURED: ", out_path, " ", image.get_width(), "x", image.get_height())
	get_tree().quit()
