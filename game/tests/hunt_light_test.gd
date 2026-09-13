extends Node

## Greg, repeatedly: *"i dont like the blueish backround and how low poly
## everything is"*, and before that *"i dont see alot of the things ive
## requesred"*.
##
## A capture of the Hunt Grounds came back almost black and got written up as a
## lighting bug. It was not one. The capture harness settles in *frames*, a
## heavy scene spends real seconds on each, `WorldClock` runs at a game-minute
## per real second, and `world_minute` persists between runs — so the shot was
## taken at 19:52 after a 240-frame settle walked the world three and a half
## hours into dusk. The world was fine; the photograph was of a different time
## of day than the one it claimed.
##
## This measures the three things that decide it rather than guessing at any of
## them: what the clock says, what the sun is actually set to, and how bright
## the frame reaching the player really is — with the clock pinned, so the
## answer means the same thing twice.
##
## The luminance check is the one that matters. Every other number here can read
## correctly while the screen stays unreadable.
##
## Usage:
##   Godot --path game res://tests/hunt_light_test.tscn -- --out=P:/GameDev/Temp

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")

	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	await tree.process_frame

	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	tree.root.add_child(hunt)
	tree.current_scene = hunt
	# Pinned, for the same reason `capture_scene.gd` is: settling is counted in
	# frames, a heavy scene spends real seconds on each, and `WorldClock` turns
	# real seconds into game minutes. Unpinned, this probe drifts into dusk while
	# it waits and then reports darkness as though it had measured noon.
	var pinned := WorldClock.OPENING_MINUTE
	for _settle in 150:
		WorldHistory.world_minute = pinned
		await tree.process_frame
	WorldHistory.world_minute = pinned

	var daylight := WorldClock.daylight()
	print("clock: hour=%.2f phase=%s daylight=%.3f night=%s" % [
		WorldClock.hour(), WorldClock.phase(), daylight, str(WorldClock.is_night())])
	check(daylight > 0.9, "the probe is running in full daylight, so darkness is not the hour")

	var sun: DirectionalLight3D = hunt.get("sun")
	if sun != null and is_instance_valid(sun):
		print("sun: energy=%.3f visible=%s colour=%s rot=%s" % [
			sun.light_energy, str(sun.visible), str(sun.light_color), str(sun.rotation_degrees)])
		check(sun.visible and sun.light_energy > 1.0, "the sun is up and at daylight strength")
	else:
		check(false, "the hunt has a sun at all")

	var env: Environment = hunt.get_node("WorldEnvironment").environment
	if env != null:
		print("env: ambient_source=%d ambient_energy=%.2f sky_contrib=%.2f" % [
			env.ambient_light_source, env.ambient_light_energy, env.ambient_light_sky_contribution])
		print("env: tonemap=%d exposure=%.2f white=%.2f" % [
			env.tonemap_mode, env.tonemap_exposure, env.tonemap_white])
		print("env: fog=%s density=%.4f volumetric=%s" % [
			str(env.fog_enabled), env.fog_density, str(env.volumetric_fog_enabled)])
		print("env: bg_mode=%d bg_energy=%.2f" % [env.background_mode, env.background_energy_multiplier])
		check(env.ambient_light_energy > 0.0, "the environment contributes some ambient")
	else:
		check(false, "the hunt has an environment")

	# The only measurement that speaks for the player. Everything above can read
	# correctly while the screen stays unreadable.
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	var path := "%s/hunt_light.png" % out_dir
	shot.save_png(path)
	print("CAPTURED: ", path)

	# Sampled on a grid rather than per-pixel: a 1280x720 read in GDScript is a
	# million `get_pixel` calls and this only needs the average.
	var total := 0.0
	var darkest := 1.0
	var brightest := 0.0
	var samples := 0
	for x in range(0, shot.get_width(), 8):
		for y in range(0, shot.get_height(), 8):
			var pixel := shot.get_pixel(x, y)
			var luma := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			total += luma
			darkest = minf(darkest, luma)
			brightest = maxf(brightest, luma)
			samples += 1
	var mean := total / maxf(1.0, float(samples))
	print("frame: mean_luma=%.4f darkest=%.4f brightest=%.4f over %d samples" % [
		mean, darkest, brightest, samples])

	# 0.06 is dim but legible. Below it a player is looking at a black rectangle
	# with a HUD on it, which is what the capture that prompted this showed.
	check(mean > 0.06, "the world in daylight is bright enough to read (mean luma > 0.06)")

	if failures.is_empty():
		print("hunt light: fine")
		tree.quit(0)
	else:
		print("hunt light FAILURES: ", failures)
		tree.quit(1)
