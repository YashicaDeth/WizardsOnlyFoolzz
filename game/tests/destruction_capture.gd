extends Node

## lab-47 PROOF: the destruction station's breach sequence as PNGs, plus the
## cost of each step and the frame with the debris settled.
## Windowed (headless draws nothing; it still prints the timings):
##   Godot --path game --resolution 1600x900 res://tests/destruction_capture.tscn -- --shots=P:/GameDev/Temp/lab47
## Writes 1_intact, 2_after_pistol, 3_after_charge, 4_dug_and_crater,
## 5_bunker_drilled, 6_settled into the folder; prints DESTRUCTION_PERF lines
## (and writes them to perf.txt, since render_one.cmd keeps no stdout).
## imp-63 adds two sequences: charge_1..6 (the brick charge from 0.03 s to
## 6 s after) and dig_1..5 (a pit shovelled down through topsoil, clay and
## rock), and the fps during a blast as well as with the debris settled.

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
	_perf("brick_sooted_cells", Array(wall.soot).filter(func(level: int) -> bool: return level > 100).size())
	_perf("blast_decals_after_charge", BlastFx.of(station).decal_count())
	# The sequence, from a little off the axis so the floor in front shows.
	var seq_eye: Vector3 = station.to_global(Vector3(1.0, 1.7, 1.3))
	var seq_at: Vector3 = station.to_global(Vector3(0.1, 0.9, -2.0))
	var elapsed := 0.0
	var index := 1
	for when in [0.03, 0.12, 0.35, 1.0, 2.5, 6.0]:
		await _seconds(maxf(when - elapsed, 0.0), true)
		elapsed = when
		await _shot("charge_%d_%.2fs" % [index, when], seq_eye, seq_at, 0.0)
		index += 1
	# Close on what stays: soot round the hole, the scorch and dust at its foot.
	await _shot("charge_7_marks", station.to_global(Vector3(0.9, 1.5, 0.4)), station.to_global(Vector3(0.0, 0.3, -1.9)))
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

	# A terraced pit shovelled down in the far corner: each stage is a 3 x 3
	# of scoops across a slightly smaller floor, so every step of the pit's
	# wall shows a deeper layer: topsoil, clay, rock.
	var pit := middle + Vector3(-1.6, 0.0, -1.6)
	for stage in 4:
		var half := 0.7 - 0.14 * stage
		var bottom := _pit_floor(pit).y
		for row in 3:
			for column in 3:
				station.dig(Vector3(pit.x - half + half * column, bottom + 0.8, pit.z - half + half * row), Vector3.DOWN)
			await get_tree().physics_frame
		await _seconds(0.8)
		var reached := _pit_floor(pit)
		_perf("pit_%d_depth_m" % (stage + 1), terrain.surface_y() - reached.y)
		_perf("pit_%d_layer" % (stage + 1), terrain.layer_at(reached))
		await _shot("dig_%d" % (stage + 1), pit + Vector3(1.3, 1.9, 1.5), pit + Vector3(-0.2, -1.1, -0.2))

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

	# imp-63: the frame during a blast. Stand the walls back up, look at the
	# brick, set off a charge on it and a grenade at its foot together, and
	# time every frame for the next two seconds. Then the same view settled.
	station.press()
	await _seconds(1.0)
	wall = station.brick_wall
	eye.global_position = seq_eye
	eye.look_at(seq_at, Vector3.UP)
	await _seconds(0.5)
	charge = station.place_charge(wall.to_global(Vector3(2.0, 0.9, 0.3)), Vector3.BACK)
	started = Time.get_ticks_usec()
	station.detonate(charge)
	_perf("second_charge_ms", (Time.get_ticks_usec() - started) / 1000.0)
	Blast.explode(station, wall.to_global(Vector3(1.0, 0.05, 0.9)), 1.1, 260.0, "explosive")
	var worst := 0.0
	frames = 0
	clock = Time.get_ticks_usec()
	var last := clock
	while Time.get_ticks_usec() - clock < 2000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	_perf("blast_fps", frames / ((Time.get_ticks_usec() - clock) / 1000000.0))
	_perf("blast_worst_frame_ms", worst)
	var fx := BlastFx.of(station)
	_perf("blast_smoke_parcels", fx.smoke.count())
	_perf("blast_decals", fx.decal_count())
	await _seconds(8.0)
	frames = 0
	clock = Time.get_ticks_usec()
	while frames < 240:
		await get_tree().process_frame
		frames += 1
	_perf("settled_after_blast_fps", frames / ((Time.get_ticks_usec() - clock) / 1000000.0))
	_perf("cubes_after_blast", WorldDebris.pool_count(VoxelStructure.CUBE_POOL))
	print("DESTRUCTION_CAPTURE done%s" % (" (headless: timings only, no PNGs, fps not a GPU number)" if headless else ""))
	get_tree().quit(0)


func _pistol(at: Vector3) -> void:
	lab.ballistics.fire(at + Vector3(0, 0, 1.5), Vector3.FORWARD, "pistol", 0.0, 1, "lab_player", {"damage": 24.0, "impulse": 2.0, "damage_type": "ballistic", "weapon": "sidearm"})


## render_one.cmd keeps no stdout, so every line also goes to `perf.txt`.
var _log: FileAccess


func _perf(key: String, value: Variant) -> void:
	var line := "DESTRUCTION_PERF %s=%s" % [key, str(snappedf(value, 0.01)) if value is float else str(value)]
	print(line)
	if _log == null:
		_log = FileAccess.open("%s/perf.txt" % shots, FileAccess.WRITE)
	if _log != null:
		_log.store_line(line)
		_log.flush()


## The pit's floor: straight down from above its middle.
func _pit_floor(pit: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(pit + Vector3.UP * 1.5, pit + Vector3.DOWN * 4.0, 1)
	var met := lab.get_world_3d().direct_space_state.intersect_ray(query)
	return met.position if not met.is_empty() else pit


func _shot(file: String, from: Vector3, to: Vector3, settle := 0.3) -> void:
	eye.global_position = from
	eye.look_at(to, Vector3.UP)
	if settle > 0.0:
		await _seconds(settle)
	if headless:
		return
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [shots, file]
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


## `exact`: count frames, not a timer, so a 0.03 s wait is the next frame or two.
func _seconds(seconds: float, exact := false) -> void:
	if exact and seconds < 0.1:
		await get_tree().process_frame
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds).timeout
