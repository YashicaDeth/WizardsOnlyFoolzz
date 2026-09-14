extends Node3D

## E2.4 cutscene director, seen rather than just tested. Every one of the 72
## bakes lands on the same reserved patch of board — this is the honest look
## of that, all the way through and partway in, not a claim made from the
## numbers alone.

const MOTHERBOARD := preload("res://systems/motherboard.gd")


func _shot(out_dir: String, name: String) -> void:
	for _settle in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path)


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.10, 0.16, 0.20)
	camera.look_at(Vector3(0.02, 0.0, -0.02), Vector3.UP)
	camera.fov = 32.0
	camera.current = true

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.4
	add_child(fill)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07120f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("1a2a20")
	environment.ambient_light_energy = 0.6
	env.environment = environment
	add_child(env)

	var board: Node3D = MOTHERBOARD.new()
	add_child(board)
	await get_tree().process_frame

	board.begin_full_sequence("burn", 0.2)
	# A third of the way through, so the mid-cutscene look is honestly there
	# too, not just the finished board. Landed mid-animation rather than on a
	# seal boundary, on purpose — a shot taken exactly between two seals shows
	# nothing live at all.
	for _seal in 23:
		board._process(0.25)
	board._process(0.1)
	await _shot(out_dir, "motherboard_sequence_live_mid_burn")

	for _seal in 49:
		board._process(0.25)
	await _shot(out_dir, "motherboard_sequence_burn_72_of_72")

	# Burning's permanent mark is deliberately minimal (E2.7: "burn 1.0 leaves
	# nothing but the memory of the ring") — true of one seal and just as true
	# stacked 72 deep, which is honest rather than a bug in the director, but
	# it means "burn" alone reads as barely more than the single-seal capture
	# already on file. Binding leaves every stroke as permanent lit copper, so
	# it is worth seeing what the same 72-deep walk looks like in that mode,
	# on a fresh board rather than layered over the burn scars above.
	board.queue_free()
	var bound_board: Node3D = MOTHERBOARD.new()
	add_child(bound_board)
	await get_tree().process_frame
	bound_board.begin_full_sequence("bind", 0.2)
	for _seal in 72:
		bound_board._process(0.25)
	await _shot(out_dir, "motherboard_sequence_bind_72_of_72")

	get_tree().quit()
