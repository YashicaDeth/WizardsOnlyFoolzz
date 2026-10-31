extends Node
## The hidden den behind the Growing Floor's weak wall: the shiv and the Black
## Mirror lying by the bedroll, from the doorway and from close.
##   Godot --path game res://tests/den_capture.tscn -- --out=P:/GameDev/Temp/den

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp/den"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat: Node = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	for _frame in 30:
		await get_tree().process_frame
	(vat.get_node("HUD") as CanvasItem).visible = false
	var camera := Camera3D.new()
	vat.add_child(camera)
	camera.current = true
	camera.fov = 62.0
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.5
	lamp.omni_range = 6.0
	vat.add_child(lamp)
	var shiv := vat.get_node("DenShiv") as Node3D
	var mirror := vat.get_node("DenMirror") as Node3D
	print("DEN shiv=%s mirror=%s centre=%s" % [shiv.global_position, mirror.global_position, vat.den_centre])
	var look := (shiv.global_position + mirror.global_position) * 0.5
	for shot: Array in [["shiv", shiv.global_position + Vector3(0.5, 0.45, 0.0), shiv.global_position], ["mirror", mirror.global_position + Vector3(0.5, 0.45, 0.0), mirror.global_position]]:
		camera.make_current()
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		lamp.global_position = camera.global_position + Vector3(0, 0.3, 0)
		for _frame in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/den_%s.png" % [out_dir, shot[0]]
		print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "FAILED: ", path)
	get_tree().quit()
