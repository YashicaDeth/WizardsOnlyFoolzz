extends Node

## lab-47 PROOF: the destruction station's breach sequence as PNGs, plus the
## cost of each step and the frame with the debris settled.
## Windowed (headless draws nothing; it still prints the timings):
##   Godot --path game --resolution 1600x900 res://tests/destruction_capture.tscn -- --shots=P:/GameDev/Temp/lab47
## Writes 1_intact, 2_after_pistol, 3_after_charge, 4_dug_and_crater,
## 5_bunker_drilled, 6_settled into the folder; prints DESTRUCTION_PERF lines.

var lab: Node3D
var eye: Camera3D
var shots := "P:/GameDev/Temp/lab47"
var headless := DisplayServer.get_name() == "headless"


func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index].begins_with("--shots="):
			shots = arguments[index].trim_prefix("--shots=")
		# render_one.cmd hands it over split at the "=".
		elif arguments[index] == "--shots" and index + 1 < arguments.size():
			shots = arguments[index + 1]
	DirAccess.make_dir_recursive_absolute(shots)
	var built := Time.get_ticks_usec()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	_perf("lab_build_ms", (Time.get_ticks_usec() - built) / 1000.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	eye = Camera3D.new()
	eye.fov = 70.0
	add_child(eye)
	await _seconds(0.5)
	eye.current = true
	var station = lab.destruction
	var walls_eye: Vector3 = station.to_global(Vector3(1.5, 1.6, 2.6))
	var walls_at: Vector3 = station.to_global(Vector3(1.5, 1.0, -2.0))
	await _shot("1_intact", walls_eye, walls_at)

	# Pistol rounds across the brick (tier 2) and concrete (tier 3) walls and
	# the bunker (tier 4): holes in brick, chips in concrete, nothing on the bunker.
	var wall: VoxelStructure = station.brick_wall
	var started := Time.get_ticks_usec()
	for index in 9:
		var target := wall.to_global(Vector3(0.3 + float(index) * 0.55, 0.4 + float(index % 3) * 0.55, 0.3))
		_pistol(target)
	for index in 4:
		_pistol(station.concrete_wall.to_global(Vector3(0.4 + float(index) * 0.35, 1.0, 0.3)))
		_pistol(station.bunker_front.to_global(Vector3(0.5 + float(index) * 0.5, 1.2, 0.6)))
	_perf("pistol_17_rounds_ms", (Time.get_ticks_usec() - started) / 1000.0)
	await _seconds(1.0)
	await _shot("2_after_pistol", walls_eye, walls_at)

	# A demolition charge on the brick wall: a hole through and the top falls.
	var charge: Node3D = station.place_charge(wall.to_global(Vector3(2.0, 0.9, 0.3)), Vector3.BACK)
	started = Time.get_ticks_usec()
	var tally: Dictionary = station.detonate(charge)
	_perf("charge_ms", (Time.get_ticks_usec() - started) / 1000.0)
	_perf("charge_cells", tally.removed)
	await _seconds(2.5)
	await _shot("3_after_charge", walls_eye, walls_at)

	# The dig patch: a grenade crater and a shovelled shaft down to the hatch.
	var terrain: DigTerrain = station.terrain
	var middle: Vector3 = station.to_global(Vector3(station.DIG_RECT.get_center().x, 0, station.DIG_RECT.get_center().y))
	started = Time.get_ticks_usec()
	Blast.explode(station, middle + Vector3(1.6, 0.05, 1.4), 1.1, 260.0, "explosive")
	_perf("grenade_crater_ms", (Time.get_ticks_usec() - started) / 1000.0)
	started = Time.get_ticks_usec()
	var scoops := 0
	for step in 12:
		# A sloped tunnel: each scoop a little further along and deeper.
		var from := middle + Vector3(-1.8 + float(step) * 0.16, 1.0, 0.0)
		scoops += 1 if station.dig(from, Vector3(0.25, -1, 0).normalized()) > 0 else 0
		await get_tree().physics_frame
	_perf("shovel_scoop_ms_avg", (Time.get_ticks_usec() - started) / 1000.0 / 12.0)
	_perf("scoops", scoops)
	await _seconds(1.0)
	# From the yard side (the patch's +z edge is 1.5 m from the perimeter wall).
	await _shot("4_dug_and_crater", middle + Vector3(3.6, 3.2, 0.6), middle + Vector3(-0.2, -1.0, 0.4))

	# The bunker: twelve seconds of thermal drill on the front.
	var front: VoxelStructure = station.bunker_front
	var aim := front.to_global(Vector3(front.size.x * front.voxel * 0.5, 1.1, front.size.z * front.voxel + 0.5))
	started = Time.get_ticks_usec()
	var drilled := 0
	for frame in 60 * 12:
		drilled += station.drill(aim, Vector3.FORWARD, 1.0 / 60.0)
	_perf("drill_frame_ms_avg", (Time.get_ticks_usec() - started) / 1000.0 / 720.0)
	_perf("drill_cells", drilled)
	# And a grenade at the door, for the breach.
	Blast.explode(station, aim - Vector3(0, 0, 0.45), 1.1, 260.0, "explosive")
	await _seconds(2.0)
	await _shot("5_bunker_drilled", aim + Vector3(0.8, 0.4, 2.2), aim - Vector3(0, 0.3, 1.5))

	# Debris settled: the frame at the station.
	await _seconds(4.0)
	lab.go_to(3)
	# Uncapped, so the number is the frame's cost and not the monitor's refresh.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _seconds(0.5)
	var frames := 0
	var physics_ms := 0.0
	var process_ms := 0.0
	var clock := Time.get_ticks_usec()
	while frames < 180:
		await get_tree().process_frame
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		frames += 1
	var seconds := (Time.get_ticks_usec() - clock) / 1000000.0
	_perf("settled_fps", frames / seconds)
	_perf("settled_physics_ms", physics_ms / frames)
	_perf("settled_process_ms", process_ms / frames)
	_perf("cubes", WorldDebris.pool_count(VoxelStructure.CUBE_POOL))
	_perf("pieces", WorldDebris.pool_count(VoxelStructure.CHUNK_POOL))
	_perf("renderer", RenderingServer.get_video_adapter_name())
	await _shot("6_settled", station.to_global(Vector3(-2.0, 4.5, 6.0)), station.to_global(Vector3(-3.0, 0.0, -2.5)))
	print("DESTRUCTION_CAPTURE done%s" % (" (headless: timings only, no PNGs, fps not a GPU number)" if headless else ""))
	get_tree().quit(0)


func _pistol(at: Vector3) -> void:
	lab.ballistics.fire(at + Vector3(0, 0, 1.5), Vector3.FORWARD, "pistol", 0.0, 1, "lab_player", {"damage": 24.0, "impulse": 2.0, "damage_type": "ballistic", "weapon": "sidearm"})


func _perf(key: String, value: Variant) -> void:
	print("DESTRUCTION_PERF %s=%s" % [key, str(snappedf(value, 0.01)) if value is float else str(value)])


func _shot(file: String, from: Vector3, to: Vector3) -> void:
	eye.global_position = from
	eye.look_at(to, Vector3.UP)
	await _seconds(0.3)
	if headless:
		return
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [shots, file]
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
