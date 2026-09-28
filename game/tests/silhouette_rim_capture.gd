extends Node

## A Support Unit guard standing in the black between two pools, and one in a
## pool, with the rim and without it, from the same camera. HUD hidden.
## Run (not headless): ... res://tests/silhouette_rim_capture.tscn -- --out=DIR

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var unit: Node = load("res://support_unit.tscn").instantiate()
	add_child(unit)
	unit.set_physics_process(false)
	unit.set_process(false)
	await _hold(4)
	# Freeze the rounds: one guard in the gap past the -51 pool, one under -43.
	var dark: Node3D = unit.guards[1]
	var lit: Node3D = unit.guards[0]
	for guard in unit.guards:
		guard.set_physics_process(false)
		guard.set_process(false)
	dark.global_position = Vector3(0.6, 0.0, -55.0)
	lit.global_position = Vector3(-1.2, 0.0, -51.0)
	for layer in unit.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	(unit.player as Node3D).visible = false
	var lights: Node = unit.get_node_or_null("RoomLights")
	if lights != null:
		lights.set("tension", 0.0)
		lights.set_process(false)
	var eye := Camera3D.new()
	eye.fov = 70.0
	unit.add_child(eye)
	eye.global_position = Vector3(-0.5, 1.7, -46.5)
	eye.look_at(Vector3(0.2, 1.0, -55.0), Vector3.UP)
	eye.current = true
	await _hold(8)
	await _capture("%s/rim_on.png" % out_dir)
	# Probe: the rim at four times its strength, to see where it lands.
	var rim := SilhouetteRim.material()
	var strength: float = rim.get_shader_parameter("strength") if rim.get_shader_parameter("strength") != null else 0.45
	rim.set_shader_parameter("strength", strength * 4.0)
	await _hold(4)
	await _capture("%s/rim_probe.png" % out_dir)
	rim.set_shader_parameter("strength", strength)
	for guard in unit.guards:
		for node in guard.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).material_overlay = null
	await _hold(4)
	await _capture("%s/rim_off.png" % out_dir)
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
