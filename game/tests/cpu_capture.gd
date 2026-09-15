extends Node3D

## E2.11/E2.12. The CPU at die scale, and the three metal states.
##
## Greg: *"copper gold rust ect make it touchdesigner based and make the
## microscopic stuff like super intricate motherboards microchips ect — cpu
## microchip."*
##
## The corrosion sweep is the point of the dials: this is one board, rendered
## four times, with `corrosion` and `patina` moved between shots and nothing
## else touched. Those are the same `set_dial()` names `OSCBridge.drive(board)`
## feeds, so in the lab they are sliders in TouchDesigner.

const MOTHERBOARD := preload("res://systems/motherboard.gd")

var out_dir := "P:/GameDev/Temp"


func _shot(name: String) -> void:
	for _settle in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("CAPTURED: ", name)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var cpu_at := Vector3(-0.22 * 0.23, 0.0, -0.16 * 0.26)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = cpu_at + Vector3(0.030, 0.034, 0.046)
	camera.look_at(cpu_at + Vector3(0, 0.004, 0), Vector3.UP)
	camera.fov = 30.0
	camera.near = 0.001
	camera.current = true

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -34, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-14, 150, 0)
	rim.light_energy = 0.55
	add_child(rim)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("06100d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("1b2b21")
	environment.ambient_light_energy = 0.7
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.2
	env.environment = environment
	add_child(env)

	var board: Node3D = MOTHERBOARD.new()
	add_child(board)
	await get_tree().process_frame
	await _shot("cpu_00_die_clean")

	# One board, four states. Only the dials move.
	board.set_dial("corrosion", 0.55)
	await _shot("cpu_01_corroded")
	board.set_dial("corrosion", 1.0)
	board.set_dial("patina", 0.75)
	await _shot("cpu_02_patina")
	board.set_dial("corrosion", 0.0)
	board.set_dial("patina", 0.0)
	board.set_dial("trace_glow", 1.6)
	board.set_dial("die_glow", 2.2)
	board.set_dial("chip_charge", 1.0)
	await _shot("cpu_03_live")

	# And the same four from the board camera, so the CPU is seen in context.
	board.reset_dials()
	camera.position = Vector3(0.10, 0.16, 0.20)
	camera.look_at(Vector3(0.02, 0.0, -0.02), Vector3.UP)
	camera.fov = 32.0
	await _shot("cpu_04_board_with_cpu")
	board.set_dial("corrosion", 1.0)
	board.set_dial("patina", 0.6)
	await _shot("cpu_05_board_scrapped")

	print("CPU SHEET DONE")
	get_tree().quit(0)
