extends Node

## Fix-56 evidence. Windowed only (through AgentHub's render_one.cmd):
## the mechanics lab's MERCY NINE at the hip and aimed, then a VATS kill in the
## Hunt and four frames of the round cam it plays (flight, X-ray cut, rupture,
## orbit), then the view handed back.
##   render_one.cmd round_cam_capture
## Writes into P:/GameDev/Temp/fix56/proof (or -- --out=DIR).

var out_dir := "P:/GameDev/Temp/fix56/proof"


func _shot(shot_name: String, note := "") -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, shot_name]
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(path) if image != null else FAILED
	print("CAPTURED " if result == OK else "CAPTURE_FAILED ", path, " ", note)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _mouse(hunt: Node, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	hunt._unhandled_input(event)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()

	# --- the lab: hip and aimed ---
	var lab: Node3D = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(20)
	lab.arsenal.select_weapon("sidearm")
	await _frames(30)
	await _shot("lab_sidearm_hip", "fov=%.1f" % lab.camera.fov)
	Input.action_press("guard")
	await _frames(45)
	await _shot("lab_sidearm_ads", "fov=%.1f aiming=%s" % [lab.camera.fov, str(lab.aiming)])
	Input.action_release("guard")
	lab.queue_free()
	await _frames(5)

	# --- the Hunt: a VATS kill and its round cam ---
	WorldClock.set_hour(13.0)
	RoundCam.force_in_tests = true
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	hunt.set_physics_process(false)
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = PI
	hunt.pitch = 0.0
	hunt._equip_weapon(2)
	var at: Vector3 = hunt.player + Vector3(0, -0.5, -4.0)
	var actor: Dictionary = hunt._spawn_encounter_actor({
		"instance_id": "round_cam_proof", "kind": "hostile", "display_name": "ROUND PROBE",
	}, at)
	(actor.node as Node3D).position = at
	(actor.node as Node3D).rotation.y = 0.0
	actor.node.set_physics_process(false)
	actor.attack_time = 0.0
	(actor.rig as BaselineHuman).anatomy.damage_organ("heart", 20.0)
	(actor.rig as BaselineHuman).anatomy.damage_organ("brain", 14.0)
	for frame in 20:
		hunt._update_camera()
		await get_tree().process_frame
	_mouse(hunt, MOUSE_BUTTON_RIGHT, true)
	_mouse(hunt, MOUSE_BUTTON_LEFT, true)
	hunt._update_vats(VatsTargeting.CHORD_WINDOW + 0.01)
	_mouse(hunt, MOUSE_BUTTON_LEFT, false)
	for position in hunt.vats.parts.size():
		if str(hunt.vats.parts[position].id) == "brain":
			hunt.vats.index = position
	await _frames(10)
	await _shot("vats_open")
	_mouse(hunt, MOUSE_BUTTON_LEFT, true)
	_mouse(hunt, MOUSE_BUTTON_LEFT, false)
	var cam: RoundCam = hunt.round_cam
	for frame in 90:
		await get_tree().physics_frame
		if cam.active:
			break
	print("ROUND_CAM active=", cam.active, " caption=", cam.caption, " dead=", actor.anatomy.dead)
	var marks := [0.35, 0.9, 1.35, 2.0]
	for index in marks.size():
		while cam.active and cam.clock < float(marks[index]):
			await get_tree().process_frame
		await _shot("killcam_%d" % (index + 1), "clock=%.2f xray=%s ruptured=%s" % [cam.clock, str(cam.xray_on), str(cam.ruptured)])
	while cam.active:
		await get_tree().process_frame
	await _frames(10)
	await _shot("killcam_after", "time_scale=%.2f" % Engine.time_scale)
	RoundCam.force_in_tests = false
	print("ROUND_CAM_CAPTURE_DONE")
	get_tree().quit()
