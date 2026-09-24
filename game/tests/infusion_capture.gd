extends Node3D

## E2.4 `v2` / E2.5. Greg: *"each and every goetic demon sigil being infused
## into the microchip in the computer's copper and gold wiring."*
##
## Two things this shows that the earlier capture could not. The board now has
## **two metals** — copper for the etched traces, gold for the edge fingers and
## the chip's legs, which is where plating actually goes on a real board. And
## the seals no longer stop at the board: each one burns in, then collapses into
## the chip, copper going in and gold arriving. Seventy-two burns would have left
## seventy-two overlapping scars; seventy-two infusions leave a chip that is lit.

const MOTHERBOARD := preload("res://systems/motherboard.gd")
const GoeticSeals := preload("res://systems/goetic_seals.gd")

var out_dir := "P:/GameDev/Temp"


func _shot(name: String) -> void:
	for _settle in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
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
	# Emission is the whole readout here, so it needs somewhere to bloom.
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.25
	env.environment = environment
	add_child(env)

	var board: Node3D = MOTHERBOARD.new()
	add_child(board)
	await get_tree().process_frame
	await _shot("infusion_00_board_two_metals")

	# The procession, driven by hand so seventy-two seals do not need seventy-two
	# seconds of wall clock. Every step is the real _process the game runs.
	board.begin_procession([], 0.6)
	# The board drives itself once an animation starts, and this capture also
	# steps it by hand. Both at once ran the clock double speed and every shot
	# landed somewhere after the moment it asked for — the seal read as parked
	# on its patch because the frame was already into the next demon's burn.
	board.process_mode = Node.PROCESS_MODE_DISABLED
	var shot_burn := false
	var shot_early := false
	var shot_late := false
	var shot_twenty := false
	for step in 9000:
		board._process(0.015)
		var mode: String = board._mode
		var progress: float = clampf(board._elapsed / maxf(0.001, board._duration), 0.0, 1.0)
		if not shot_burn and mode == "burn" and progress > 0.45:
			shot_burn = true
			await _shot("infusion_01_burning_in")
		if not shot_early and mode == "infuse" and progress > 0.25 and progress < 0.5:
			shot_early = true
			await _shot("infusion_02_leaving_the_board")
		if not shot_late and mode == "infuse" and progress > 0.88:
			shot_late = true
			await _shot("infusion_03_arriving_gold")
		if not shot_twenty and int(board.infused_seals) >= 20:
			shot_twenty = true
			await _shot("infusion_04_twenty_in")
		if int(board.infused_seals) >= 72:
			break

	print("INFUSED: ", board.infused_seals, " of ", GoeticSeals.GOETIA.size())
	await _shot("infusion_05_all_seventy_two")
	print("INFUSION SHEET DONE")
	get_tree().quit(0)
