extends "res://tests/body_look_capture.gd"

## player-81 PROOF. The player's looks on the rigged base, side by side, in
## the same dim room as body_look_capture: the base as it was (unmarked, for
## comparison), the three looks (PlayerLook), and the jester set the Hunt
## dresses on the new build. Then a severed arm and a ragdoll at rest on the
## default look. Windowed only:
##   render_one.cmd player_look_capture --out=DIR


func _ready() -> void:
	out_dir = "P:/GameDev/Temp/player-81/after/looks"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless":
		print("PLAYER_LOOK_CAPTURE headless draws nothing; run windowed")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	_build_room()
	var people := {
		"old_base": _look_body(""),
		"patient": _look_body("patient"),
		"bodysuit": _look_body("bodysuit"),
		"wraps": _look_body("wraps"),
		"jester": _jester(),
	}
	var x := -3.2
	for key: String in people:
		var holder := people[key] as Node3D
		holder.position = Vector3(x, 0, 0)
		holder.rotation.y = PI
		x += 1.6
	eye = Camera3D.new()
	eye.fov = 40.0
	add_child(eye)
	eye.current = true
	for _frame in 90:
		await get_tree().process_frame
	_shoot_at(Vector3(0, 1.0, 7.0), Vector3(0, 0.9, 0), 45.0)
	await _capture("lineup_front")
	_shoot_at(Vector3(0, 1.0, -7.0), Vector3(0, 0.9, 0), 45.0)
	await _capture("lineup_back")
	for key: String in people:
		for other: String in people:
			(people[other] as Node3D).visible = other == key
		var at := (people[key] as Node3D).global_position
		_shoot_at(at + Vector3(0, 1.0, 3.2), at + Vector3(0, 0.9, 0), 40.0)
		await _capture("%s_front" % key)
		_shoot_at(at + Vector3(3.2, 1.0, 0.0), at + Vector3(0, 0.9, 0), 40.0)
		await _capture("%s_side" % key)
		_shoot_at(at + Vector3(0.25, 1.55, 1.0), at + Vector3(0, 1.45, 0), 35.0)
		await _capture("%s_face" % key)
		_shoot_at(at + Vector3(-0.6, 1.25, 0.7), at + Vector3(-0.35, 1.0, 0), 35.0)
		await _capture("%s_hand" % key)
	# A cut: the patient's right arm comes off whole.
	for other: String in people:
		(people[other] as Node3D).visible = other == "patient"
	var patient := (people["patient"] as Node3D).get_child(0) as BaselineHuman
	patient.hit("right_arm", 400.0, 6.0, "cut", "", Vector3.LEFT)
	for _frame in 40:
		await get_tree().process_frame
	var at_patient := (people["patient"] as Node3D).global_position
	_shoot_at(at_patient + Vector3(0.4, 1.3, 3.0), at_patient + Vector3(0, 0.8, 0), 45.0)
	await _capture("patient_severed_arm")
	# Death: the ragdoll at rest.
	patient.hit("head", 400.0, 6.0, "puncture", "brain", Vector3.LEFT, 1.0, null, null, "heavy")
	for _frame in 240:
		await get_tree().process_frame
	_shoot_at(at_patient + Vector3(1.6, 1.6, 2.2), at_patient + Vector3(0, 0.2, 0), 45.0)
	await _capture("patient_ragdoll")
	get_tree().quit()


func _look_body(look: String) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var rig := BaselineHuman.new()
	rig.name = "Player_" + (look if not look.is_empty() else "old")
	holder.add_child(rig)
	if not look.is_empty():
		PlayerLook.mark(rig, look)
	rig.build("player", BaselineHuman.config_from_subject({}).merged({"rigged": true, "gore": true}, true))
	return holder


## The Hunt's player: the forced jester set over the new build.
func _jester() -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var rig := BaselineHuman.new()
	rig.name = "Player_jester"
	holder.add_child(rig)
	PlayerLook.mark(rig)
	rig.build("player", BaselineHuman.config_from_subject({}).merged({"rigged": true, "gore": true}, true))
	rig.dress(ClothingShell.humiliation_wardrobe())
	Outfit.dress(rig)
	var look := HunterAppearance.new()
	rig.add_child(look)
	look.configure(rig, {})
	return holder
