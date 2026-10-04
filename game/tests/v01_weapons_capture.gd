extends Node

## Job 3 PROOF: the v0.1 weapons in the mechanics lab, first person.
## Windowed only (headless draws nothing and says so):
##   Godot --path game --resolution 1600x900 res://tests/v01_weapons_capture.tscn -- --shots=P:/GameDev/Temp/v01_weapons
## Writes, into the folder:
##   held_cleaver.png  held_staff.png  held_pistol.png   each weapon at rest
##   cleaver_swing_NN.png   a light chain into a dummy (PNG sequence)
##   cleaver_hot.png        the edge after several hits, the burn on the wound
##   staff_shock_NN.png     a charged R2 into a dummy
##   pistol_ads.png         L2: down the sights at a dummy
##   sparring_NN.png        the sparring partner's telegraph and a parry

var lab: Node3D
var shots := "P:/GameDev/Temp/v01_weapons"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	if DisplayServer.get_name() == "headless":
		print("V01_WEAPONS_CAPTURE headless draws nothing; run windowed")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(shots)
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _seconds(0.6)
	var rigs: Array = lab.bodies.rigs()

	# Each weapon at rest in the hand, facing a dummy.
	await _face(rigs[0], 1.6)
	await _shot("held_cleaver")
	lab.arsenal.select_weapon("staff")
	await _seconds(0.2)
	await _shot("held_staff")
	lab.arsenal.select_weapon("sidearm")
	await _seconds(0.2)
	await _shot("held_pistol")

	# Cleaver: a light chain into the dummy, one frame every 60 ms.
	lab.arsenal.select_weapon("cleaver")
	await _face(rigs[0], 1.3)
	lab.melee.press_light()
	await _sequence("cleaver_swing", 10, 0.06, func(frame: int) -> void:
		if frame == 4:
			lab.melee.press_light())
	for blow in 3:
		lab.melee.press_light()
		await _seconds(0.7)
	await _shot("cleaver_hot")

	# Staff: charged shock.
	lab.arsenal.select_weapon("staff")
	await _face(rigs[1], 2.6)
	lab.melee.press_heavy()
	await _seconds(SwordMoveset.CHARGED_HEAVY_SECONDS + 0.1)
	await _shot("staff_charging")
	lab.melee.release_heavy()
	await _sequence("staff_shock", 10, 0.07, Callable())

	# Pistol down the sights.
	lab.arsenal.select_weapon("sidearm")
	await _face(rigs[3], 4.0)
	var aim := InputEventAction.new()
	aim.action = "parry"
	aim.pressed = true
	Input.parse_input_event(aim)
	await _seconds(0.6)
	await _shot("pistol_ads")
	aim.pressed = false
	Input.parse_input_event(aim)

	# The sparring partner: its telegraph, then a parry.
	lab.arsenal.select_weapon("cleaver")
	var partner = lab.sparring
	await _face(partner.rig, 2.0)
	await _until(func() -> bool: return partner.state == "windup" and partner.clock > 0.35, 6.0)
	await _shot("sparring_00_telegraph")
	lab.melee.press_parry()
	await _sequence("sparring", 6, 0.08, Callable())

	print("V01_WEAPONS_CAPTURE wrote %s" % shots)
	Engine.time_scale = 1.0
	get_tree().quit(0)


func _face(rig: BaselineHuman, distance: float) -> void:
	lab.player.global_position = rig.global_position + Vector3(0, 1.0, distance)
	lab.player.velocity = Vector3.ZERO
	await _seconds(0.1)
	var to: Vector3 = rig.global_position + Vector3(0, 1.2, 0) - lab.camera.global_position
	lab.yaw = atan2(-to.x, -to.z)
	lab.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await _seconds(0.15)


func _sequence(prefix: String, count: int, every: float, each: Callable) -> void:
	for frame in count:
		if each.is_valid():
			each.call(frame)
		await _shot("%s_%02d" % [prefix, frame])
		await _seconds(every)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := shots.path_join(shot_name + ".png")
	image.save_png(path)
	print("SHOT ", path)


func _until(condition: Callable, limit: float) -> void:
	var waited := 0.0
	while waited < limit and not condition.call():
		await get_tree().physics_frame
		waited += 1.0 / float(Engine.physics_ticks_per_second)


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
