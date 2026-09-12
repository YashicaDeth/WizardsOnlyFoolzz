extends Node3D

## E2.4/E2.5. The motherboard itself, a bound seal mid-growth, a bound seal
## finished, and a burnt seal finished - Greg's own image for the game's
## whole thesis, seen rather than just built.

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
	await _shot(out_dir, "motherboard_bare")

	board.begin_bind(1234, 6, 1.0)
	board._process(0.5)
	await _shot(out_dir, "motherboard_binding_midway")

	board._process(0.6)
	await _shot(out_dir, "motherboard_bound")

	# A separate board for the burn: a real run gives a burnt seal its own
	# board rather than scarring over a mark that already bound clean, and
	# reusing the first board here would just superimpose two seals at the
	# same spot and make neither reading clear.
	board.queue_free()
	var burnt_board: Node3D = MOTHERBOARD.new()
	add_child(burnt_board)
	await get_tree().process_frame
	burnt_board.begin_burn(9911, 6, 1.0, 0.2)
	burnt_board._process(0.4)
	await _shot(out_dir, "motherboard_burning_midway")

	burnt_board._process(0.7)
	await _shot(out_dir, "motherboard_burnt")

	get_tree().quit()
