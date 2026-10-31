extends Node

## Fix-56. An aimed X-ray (VATS) round that kills replays as a slowed cutscene:
## its own camera from the muzzle, the world slowed, the X-ray cut before the
## skin, the organ bursting, then control back. Any button skips. The dial
## decides how often an ordinary killing shot earns it.

const HUNT := preload("res://bone_yard_hunt.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _mouse(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	print("-- the dial --")
	check(not RoundCam.wanted(true, true, 0.0), "off under ATG_TEST_MODE unless a test asks (other suites stay deterministic)")
	RoundCam.force_in_tests = true
	check(RoundCam.wanted(true, false, 0.99), "a VATS round that lands always earns it")
	check(RoundCam.wanted(false, true, 0.1) and not RoundCam.wanted(false, true, 0.9), "a killing shot earns it on the kill dial (%.2f)" % RoundCam.kill_chance)
	check(not RoundCam.wanted(false, false, 0.0), "an ordinary hit never does")
	check(not RoundCam.wanted(true, true, 0.0, RoundCam.COOLDOWN * 0.5), "not twice inside the cooldown")

	print("-- a VATS kill in the Hunt --")
	var hunt := HUNT.instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 60.0, 0)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt._equip_weapon(2)
	var actor: Dictionary = hunt._spawn_encounter_actor({
		"instance_id": "round_cam_subject", "kind": "hostile", "display_name": "ROUND PROBE",
	}, hunt.player + Vector3(0, -0.5, 4.0))
	# Head at the eye: a round angled down past the shooter's own arm hitbox
	# is a different question (see the report).
	(actor.node as Node3D).position = hunt.player + Vector3(0, -0.5, 4.0)
	actor.node.set_physics_process(false)
	var rig := actor.rig as BaselineHuman
	# One round from a pistol has to be enough: the brain is most of the way gone.
	rig.anatomy.damage_organ("brain", 14.0)
	for frame in 3:
		hunt._update_camera()
		await get_tree().physics_frame
	var player_camera: Camera3D = hunt.camera

	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true))
	hunt._update_vats(VatsTargeting.CHORD_WINDOW + 0.01)
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	check(hunt.vats.is_active(), "aimed X-ray opens on the body")
	var brain_index := -1
	for position in hunt.vats.parts.size():
		if str(hunt.vats.parts[position].id) == "brain":
			brain_index = position
	check(brain_index >= 0, "the brain is a part you can pick")
	hunt.vats.index = maxi(brain_index, 0)
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true))
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	var cam: RoundCam = hunt.round_cam
	for frame in 60:
		await get_tree().physics_frame
		if cam.active:
			break
	check(actor.anatomy.dead, "the round kills")
	check(cam.active, "the round cam starts on the VATS kill")
	check(cam.caption.begins_with("VATS") and "BRAIN" in cam.caption, "it names the shot (%s)" % cam.caption)
	check(get_viewport().get_camera_3d() == cam.camera and cam.camera != player_camera, "its own camera has the view")
	check(absf(Engine.time_scale - RoundCam.SLOW_SCALE) < 0.001, "the world is slowed (%.2f)" % Engine.time_scale)
	check(not (hunt.get_node("HUD") as CanvasLayer).visible, "the HUD is put away")
	check(hunt._cinematic_active(), "the hunt reads it as a cutscene and holds the player's input")
	var muzzle_gap := cam.camera.global_position.distance_to(player_camera.global_position)
	check(muzzle_gap < 0.8, "it starts at the muzzle, by the shooter (%.2f m from the eye)" % muzzle_gap)

	var waited := 0
	while cam.active and cam.clock < RoundCam.RUPTURE_AT + 0.1 and waited < 600:
		await get_tree().process_frame
		waited += 1
	check(cam.xray_on and rig._xray, "it cuts to the X-ray as the round reaches the skin")
	check(cam.ruptured, "the organ bursts")
	var focus_gap := cam.camera.global_position.distance_to(cam._focus())
	check(focus_gap < RoundCam.ORBIT + 0.3, "the camera is on the wound (%.2f m)" % focus_gap)

	# Skip: any button, through the real input path.
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	get_viewport().push_input(key)
	await get_tree().process_frame
	check(not cam.active and cam.skipped, "a button skips it")
	check(absf(Engine.time_scale - 1.0) < 0.001, "time comes back (%.2f)" % Engine.time_scale)
	check(get_viewport().get_camera_3d() == player_camera, "the player's camera has the view again")
	check((hunt.get_node("HUD") as CanvasLayer).visible, "the HUD is back")
	check(not rig._xray, "the body is solid again")
	check(not hunt._cinematic_active(), "the hunt takes input again")
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false))
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
	check(hunt.firearm_aiming, "and the next press is the player's (aims)")
	hunt._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false))

	print("-- left alone it ends by itself --")
	var ended := [false, true]
	cam.finished.connect(func(was_skipped: bool) -> void:
		ended[0] = true
		ended[1] = was_skipped)
	check(cam.trigger(player_camera.global_position, rig.global_position + Vector3.UP * 1.2, rig, "heart", "torso", "TEST // HEART", hunt.get_node("HUD") as CanvasLayer),
		"it can be played on a body directly")
	var start := Time.get_ticks_msec()
	while cam.active and Time.get_ticks_msec() - start < 6000:
		await get_tree().process_frame
	var seconds := float(Time.get_ticks_msec() - start) / 1000.0
	check(ended[0] and not ended[1], "it hands back on its own")
	check(seconds > 2.0 and seconds < 3.5, "in about %.1f s of real time" % seconds)
	check(absf(Engine.time_scale - 1.0) < 0.001 and get_viewport().get_camera_3d() == player_camera, "time and the view are the player's")

	RoundCam.force_in_tests = false
	hunt.queue_free()
	await get_tree().process_frame
	print("ROUND_CAM_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
