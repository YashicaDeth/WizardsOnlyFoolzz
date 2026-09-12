extends Node

## AG4.2. Blood on the lens only exists if you can see it, so this puts real
## doses on the glass and photographs them: one hit, a fight's worth, and the
## same thing twenty seconds later once it has started to dry and run.

const VEIL := preload("res://systems/blood_veil.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	await tree.process_frame

	# A plate behind it, so the marks are read against something rather than
	# against the clear colour.
	var plate := ColorRect.new()
	plate.color = Color("2a2b24")
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(plate)

	var veil: Control = VEIL.new()
	add_child(veil)
	veil.size = Vector2(1280, 720)
	await tree.process_frame

	# One blow, from the right.
	veil.call("splash", 0.55, Vector2(0.8, -0.2))
	await _shoot(tree, veil, out_dir + "/blood_one.png")

	# A fight. Several doses from different sides.
	for index in 5:
		veil.call("splash", 0.7 + float(index) * 0.05, Vector2(cos(float(index) * 1.9), sin(float(index) * 1.9)))
		for _gap in 6:
			await tree.process_frame
	await _shoot(tree, veil, out_dir + "/blood_fight.png")

	# And after it has run and begun to dry.
	var waited := 0.0
	while waited < 9.0:
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
	await _shoot(tree, veil, out_dir + "/blood_dried.png")
	print("soaked: %.2f" % float(veil.call("soaked")))
	tree.quit(0)


func _shoot(tree: SceneTree, veil: Control, path: String) -> void:
	veil.queue_redraw()
	for _frame in 4:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)
