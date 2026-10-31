extends Node

## lab-46 PROOF: the liquid station's break as a PNG sequence, plus the
## shock and the frame rate at the station. Windowed only (headless draws
## nothing and says so), one window on the right monitor:
##   Godot --path game --resolution 1600x900 res://tests/fluid_glass_capture.tscn -- --shots=P:/GameDev/Temp/fluid_glass
## Writes 01_intact, 02_cracked_1..04_cracked_3, 05_burst, 05_pour_1..6 (the
## pour as a sequence), 06_pouring, 07_pooled, 08_waded, 09_shock .png and
## fps.txt into the folder. `--surface=0` draws the pour as the old spheres.

var lab: Node3D
var eye: Camera3D
var shots := "P:/GameDev/Temp/fluid_glass"
var fps_lines: Array[String] = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
		# imp-61 A/B: --surface=0 draws the pour as the old spheres.
		if argument == "--surface=0":
			FluidBody.surface_allowed = false
	DirAccess.make_dir_recursive_absolute(shots)
	BloodPool.clear()
	Footprints.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	eye = Camera3D.new()
	eye.fov = 62.0
	add_child(eye)
	await _seconds(0.5)
	eye.current = true
	var station = lab.liquid
	var tank: GlassTank = station.tank
	var close_from: Vector3 = tank.to_global(Vector3(1.1, 1.5, 2.3))
	var close_at: Vector3 = tank.to_global(Vector3(0, 0.9, 0))
	var wide_from: Vector3 = tank.to_global(Vector3(2.8, 3.0, 4.6))
	var wide_at: Vector3 = tank.to_global(Vector3(0, 0.2, 0.6))
	var face: Vector3 = tank.body.global_position + Vector3(0, 0.1, tank.radius)

	await _shot("01_intact", close_from, close_at)
	await _fps("intact")
	for stage in range(1, tank.blows):
		station.strike(face + Vector3(0.12 * stage - 0.2, 0.15 * stage - 0.2, 0), Vector3.FORWARD)
		await _seconds(0.5)
		await _shot("%02d_cracked_%d" % [stage + 1, stage], close_from, close_at)
	station.strike(face, Vector3.FORWARD)
	await _frames(4)
	await _shot("05_burst", close_from, close_at)
	# imp-61: the pour as a sequence, low and three-quarter on the struck face,
	# where the stream leaves the glass and lands.
	var pour_from: Vector3 = tank.to_global(Vector3(-1.3, 0.5, 2.9))
	var pour_at: Vector3 = tank.to_global(Vector3(0.1, 0.0, 1.0))
	for frame in 6:
		await _seconds(0.3)
		await _shot("05_pour_%d" % (frame + 1), pour_from, pour_at)
	await _shot("06_pouring", wide_from, wide_at)
	await _fps("pouring")
	await _seconds(7.0)
	await _shot("07_pooled", wide_from, wide_at)
	await _fps("pooled")
	# Walk the player through it.
	var player: CharacterBody3D = lab.player
	player.global_position = station.fluid.to_global(Vector3(-1.4, 0.95, 1.6))
	for frame in 90:
		player.velocity = Vector3(2.4, player.velocity.y, -0.3)
		station.wade(player, player.global_position - Vector3(0, 0.85, 0), player.velocity, 1.0 / 60.0)
		player.global_position += Vector3(2.4, 0, -0.3) / 60.0
		await get_tree().physics_frame
	await _shot("08_waded", station.fluid.to_global(Vector3(-0.2, 1.6, 3.6)), station.fluid.to_global(Vector3(0.2, 0.0, 1.2)))
	player.global_position = Vector3(0, 1.0, 17.0)
	station.press()
	await _frames(3)
	await _shot("09_shock", wide_from, station.wet_dummy.global_position + Vector3(0, 0.6, 0))
	var file := FileAccess.open(shots + "/fps.txt", FileAccess.WRITE)
	if file:
		file.store_string("\n".join(fps_lines) + "\n")
	print("FLUID_GLASS_CAPTURE fps ", fps_lines)
	get_tree().quit(0)


func _fps(label: String) -> void:
	# imp-61: GPU milliseconds per viewport too, since fps on a shared,
	# vsync-capped desktop is noisy: the game frame, and the pour's splat
	# buffer when the surface is drawing.
	var main_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(main_rid, true)
	var splats: SubViewport = lab.liquid.fluid.get_node_or_null("Surface/FluidSplats")
	if splats:
		RenderingServer.viewport_set_measure_render_time(splats.get_viewport_rid(), true)
	var main_gpu := 0.0
	var splat_gpu := 0.0
	var samples := 0
	var started := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - started < 1500000:
		await RenderingServer.frame_post_draw
		frames += 1
		main_gpu += RenderingServer.viewport_get_measured_render_time_gpu(main_rid)
		if splats:
			splat_gpu += RenderingServer.viewport_get_measured_render_time_gpu(splats.get_viewport_rid())
		samples += 1
	var seconds := float(Time.get_ticks_usec() - started) / 1000000.0
	var line := "%s: %d fps (%s), gpu game view %.2f ms, gpu splat buffer %.2f ms, %d blobs" % [label, roundi(frames / seconds), RenderingServer.get_video_adapter_name(), main_gpu / maxi(samples, 1), splat_gpu / maxi(samples, 1), lab.liquid.fluid.blob_count()]
	fps_lines.append(line)
	print("FLUID_GLASS_CAPTURE ", line)


func _shot(label: String, from: Vector3, at: Vector3) -> void:
	eye.global_position = from
	eye.look_at(at)
	if DisplayServer.get_name() == "headless":
		print("FLUID_GLASS_CAPTURE %s: headless, nothing rendered" % label)
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("FLUID_GLASS_CAPTURE %s: nothing rendered" % label)
		return
	var path := "%s/%s.png" % [shots, label]
	image.save_png(path)
	print("FLUID_GLASS_CAPTURE ", path)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
