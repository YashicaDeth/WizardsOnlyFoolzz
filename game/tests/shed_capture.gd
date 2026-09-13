extends Node3D

## AU3.1. The shed, from inside it — which is the only angle that proves it is a
## room. A shot from outside a 3.2m box proves nothing; standing at eye height
## with a wall behind you and the bulb in shot is the test.

const SHED := preload("res://systems/shed.gd")

var shed


func _shot(out_dir: String, shot_name: String) -> void:
	for _settle in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, shot_name]
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "FAILED: ", path)


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0a0c0e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Night outside. Just enough that the gaps between the sheets read.
	environment.ambient_light_color = Color("28313a")
	environment.ambient_light_energy = 0.55
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	env.environment = environment
	add_child(env)

	# One weak moon outside, so the seams have something to leak.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38, 26, 0)
	moon.light_color = Color("9fb4cc")
	moon.light_energy = 0.5
	add_child(moon)

	shed = SHED.new()
	add_child(shed)
	shed.build()
	await get_tree().process_frame

	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 62.0
	camera.current = true

	# Standing inside, by the door, looking at the bench. Eye height 1.68m,
	# which is the height A10.4 already established for street view.
	camera.position = Vector3(0.86, 1.68, 0.84)
	camera.look_at(Vector3(-0.20, 1.05, -0.86), Vector3.UP)
	await _shot(out_dir, "shed_inside")

	# Leaning over the bench — what you actually see when you use it.
	camera.position = Vector3(-0.30, 1.42, 0.26)
	camera.look_at(Vector3(-0.34, 0.88, -0.78), Vector3.UP)
	camera.fov = 54.0
	await _shot(out_dir, "shed_over_bench")

	# Back to the door, so the way out and the gaps in the walls are in frame.
	camera.position = Vector3(-0.70, 1.60, -0.60)
	camera.look_at(Vector3(0.62, 1.10, 1.20), Vector3.UP)
	camera.fov = 66.0
	await _shot(out_dir, "shed_door")

	print("SHED ROOM DONE")
	get_tree().quit()
