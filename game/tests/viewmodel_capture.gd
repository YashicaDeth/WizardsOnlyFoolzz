extends Node

## M4.4 visual check. The weapon models in `hunter_arsenal.gd` were built and
## positioned before M4.1-M4.3 corrected the FOV and eye height they are seen
## through, so this photographs the real first-person view of all three at the
## corrected numbers rather than guessing whether the old placement still
## holds up.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	# Default yaw/pitch, matching the already-reviewed i0_weapon_well.png framing
	# — an overridden yaw of 0 turned out to face away from the sky entirely and
	# read as a black frame that had nothing to do with the weapon model.
	hunt.third_person = false
	# A framing check needs to actually see the geometry. The night rework
	# (A3-A10) landed after this capture was first authored and the world now
	# defaults dark enough that the weapon was unreadable against it.
	WorldClock.set_hour(13.0)
	# Let the real idle pose settle: arm_raise only applies through
	# hunter_body_motion.gd's normal update loop, so this runs the actual game
	# for a second rather than posing the rig by hand.
	for _settle in 90:
		await get_tree().physics_frame

	for entry in [{"slot": 0, "name": "sword"}, {"slot": 1, "name": "shotgun"}, {"slot": 2, "name": "sidearm"}]:
		hunt._equip_weapon(entry.slot)
		for _frame in 20:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/viewmodel_%s.png" % [out_dir, entry.name]
		var error := image.save_png(path)
		print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)
		if error != OK:
			get_tree().quit(1)
			return
	get_tree().quit()
