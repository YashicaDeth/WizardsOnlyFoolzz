extends Node

## imp-64 PROOF: first-person arms for every v0.1 weapon and bare hands, in
## the mechanics lab. Windowed only (headless draws nothing):
##   render_one.cmd fp_arms_capture --shots=P:/GameDev/Temp/fp_arms
## Swings are taken at a quarter of game speed so each phase gets frames:
##   <weapon>_combo_NN   three lights (wind-up, strike, follow-through, recovery)
##   <weapon>_heavy_NN   a heavy
##   cleaver_block, cleaver_parry_NN, cleaver_flinch_NN, cleaver_inspect_NN
##   pistol_rest, pistol_reload_NN, pistol_ads
##   bare_rest, bare_combo_NN, bare_heavy_NN
## and fps.txt: the mean frame rate over three seconds holding the cleaver.

const SLOW := 0.25

var lab: Node3D
var arms: FirstPersonArms
var shots := "P:/GameDev/Temp/fp_arms"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	if DisplayServer.get_name() == "headless":
		print("FP_ARMS_CAPTURE headless draws nothing; run windowed")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(shots)
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _seconds(0.6)
	arms = lab.held_mount
	# Swings into open air, so hitstop does not hold the frames.
	await _look_at_wall()
	await _fps()
	await _shot("cleaver_rest")
	await _combo("cleaver")
	await _heavy("cleaver")
	lab.melee.set_guard(true)
	await _seconds(0.4)
	await _shot("cleaver_block")
	lab.melee.set_guard(false)
	await _seconds(0.3)
	lab.melee.press_parry()
	await _sequence("cleaver_parry", 5, 0.05)
	await _seconds(0.3)
	lab.melee.receive_blow(10.0)
	await _sequence("cleaver_flinch", 4, 0.05)
	await _seconds(0.3)
	arms.inspect()
	await _sequence("cleaver_inspect", 6, FirstPersonArms.INSPECT_SECONDS / 6.0)

	lab.arsenal.select_weapon("staff")
	await _seconds(0.3)
	await _shot("staff_rest")
	await _combo("staff")
	await _heavy("staff")

	lab.arsenal.select_weapon("sidearm")
	await _seconds(0.3)
	await _shot("pistol_rest")
	lab.arsenal.ammo["sidearm"]["loaded"] = 2
	lab.arsenal.reload()
	await _sequence("pistol_reload", 8, float(lab.arsenal.current().reload) / 8.0)
	await _seconds(0.3)
	var aim := InputEventAction.new()
	aim.action = "parry"
	aim.pressed = true
	Input.parse_input_event(aim)
	await _seconds(0.6)
	await _shot("pistol_ads")
	aim.pressed = false
	Input.parse_input_event(aim)
	await _seconds(0.4)

	# Bare hands: no driver, the arms' own fists moveset.
	arms.arsenal = null
	arms.driver = null
	arms.take("")
	await _seconds(0.3)
	await _shot("bare_rest")
	Engine.time_scale = SLOW
	arms.strike()
	for frame in 18:
		if frame == 5 or frame == 10:
			arms.strike()
		await _shot("bare_combo_%02d" % frame)
		await _seconds(0.3)
	await _seconds(0.6)
	arms.strike(true)
	await _sequence("bare_heavy", 12, 0.36)
	Engine.time_scale = 1.0

	print("FP_ARMS_CAPTURE wrote %s" % shots)
	get_tree().quit(0)


func _combo(weapon: String) -> void:
	Engine.time_scale = SLOW
	lab.melee.press_light()
	for frame in 18:
		# Each next press lands in the last blow's recovery buffer.
		if frame == 5 or frame == 10:
			lab.melee.press_light()
		await _shot("%s_combo_%02d" % [weapon, frame])
		await _seconds(0.3)
	Engine.time_scale = 1.0
	await _seconds(0.8)


func _heavy(weapon: String) -> void:
	Engine.time_scale = SLOW
	lab.melee.press_heavy()
	lab.melee.release_heavy()
	await _sequence("%s_heavy" % weapon, 12, 0.36)
	Engine.time_scale = 1.0
	await _seconds(0.8)


func _look_at_wall() -> void:
	lab.player.global_position = Vector3(0, 1.0, 17.0)
	lab.player.velocity = Vector3.ZERO
	# Toward the lit yard, past the dummies' reach.
	lab.yaw = 0.0
	lab.pitch = -0.05
	await _seconds(0.3)


func _fps() -> void:
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var frames := 0
	var started := Time.get_ticks_usec()
	while Time.get_ticks_usec() - started < 3000000:
		await get_tree().process_frame
		frames += 1
	var fps := float(frames) / (float(Time.get_ticks_usec() - started) / 1000000.0)
	var line := "fps %.1f over 3 s holding the cleaver, adapter %s, vsync %s" % [fps, RenderingServer.get_video_adapter_name(), "off for the count"]
	DisplayServer.window_set_vsync_mode(vsync)
	print("FP_ARMS_CAPTURE ", line)
	var file := FileAccess.open(shots.path_join("fps.txt"), FileAccess.WRITE)
	file.store_line(line)


func _sequence(prefix: String, count: int, every: float) -> void:
	for frame in count:
		await _shot("%s_%02d" % [prefix, frame])
		await _seconds(every)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(shots.path_join(shot_name + ".png"))


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
