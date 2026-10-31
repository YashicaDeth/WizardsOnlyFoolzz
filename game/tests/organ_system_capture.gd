extends Node

## Lab-48 PROOF, at the mechanics lab's bodies station, through the player's
## own eye (so the HUD, prompts and the X-ray scan are the real ones).
## Windowed only (headless draws nothing):
##   render_one.cmd organ_system_capture --shots=P:/GameDev/Temp/lab48
## Writes 1_intact, 2_chest_opened, 3_xray_scan, 4_heart_in_hand,
## 5_shorted_xray, 6_shorted_sparks and fps.txt.

var lab: Node3D
var shots := "P:/GameDev/Temp/lab48"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _seconds(0.6)
	lab.go_to(1)
	var rigs: Array = lab.bodies.rigs()
	var subject: BaselineHuman = rigs[1]
	var scanned: BaselineHuman = rigs[2]

	# 1. Intact, X-ray off.
	_stand_before(subject, 1.35)
	await _seconds(0.4)
	_aim((subject.parts.torso as Node3D).global_position + Vector3.UP * 0.05)
	await _seconds(0.3)
	await _shot("1_intact")

	# 2. Cleaver into the belly and the lower ribs until the chest opens, then
	# look into it while it is still on its feet.
	var front := _front(subject)
	var blows := 0
	while blows < 10 and not OrganSystem.is_opened(subject, "torso"):
		await _blow(subject, blows)
		blows += 1
	print("CAPTURE opened=%s blows=%d standing=%s heart_ok=%s" % [OrganSystem.is_opened(subject, "torso"), blows, not subject.anatomy.downed, subject.anatomy.organ_ok("heart")])
	await _seconds(0.8)
	_stand_before(subject, 0.95)
	_aim((subject.parts.torso as Node3D).global_position + Vector3.DOWN * 0.02)
	await _seconds(0.3)
	await _shot("2_chest_opened")
	lab.bodies.press()
	await _seconds(0.3)
	await _shot("2b_chest_opened_xray")
	lab.bodies.press()
	# Then put it down: the rip is a finisher on a downed body.
	while blows < 16 and not (subject.anatomy.downed or subject.anatomy.dead):
		await _blow(subject, blows)
		blows += 1
	print("CAPTURE downed=%s dead=%s blows=%d heart_ok=%s" % [subject.anatomy.downed, subject.anatomy.dead, blows, subject.anatomy.organ_ok("heart")])
	await _seconds(2.5)

	# 3. X-ray on, looking at a standing dummy: the pre-fight scan.
	lab.bodies.press()
	_stand_before(scanned, 1.3)
	await _seconds(0.3)
	_aim((scanned.parts.torso as Node3D).global_position + Vector3.UP * 0.1)
	await _seconds(0.5)
	await _shot("3_xray_scan")

	# 4. Back to the opened one, X-ray off, hand in, hold until it comes out.
	lab.bodies.press()
	_stand_before(subject, 1.1)
	await _seconds(0.3)
	var target := "heart" if subject.anatomy.organ_ok("heart") else "left_lung"
	var started := false
	for attempt in 60:
		_aim((subject.organ_parts[target] as Node3D).global_position)
		await get_tree().physics_frame
		if lab.begin_rip_aimed() and not lab.rip.is_empty():
			started = true
			break
	print("CAPTURE rip started=%s target=%s note=%s" % [started, target, lab.last_note])
	lab.rip_held = true
	await _seconds(OrganSystem.RIP_SECONDS * 0.55)
	await _shot("4a_tugging")
	var waited := 0.0
	while lab.hand_item.is_empty() and waited < 4.0:
		await _seconds(0.05)
		waited += 0.05
	lab.rip_held = false
	_aim(_heart_or_torso(subject) + Vector3.UP * 0.25)
	await _seconds(0.35)
	await _shot("4_heart_in_hand")
	print("CAPTURE hand=%s" % str(lab.hand_item))

	# 5. The PRODSTAFF on a standing dummy with powered hardware: shorted.
	lab.sell_hand_item()
	var shocked: BaselineHuman = rigs[0]
	_stand_before(shocked, 1.7)
	lab.bodies.press()
	await _seconds(0.3)
	_aim((shocked.parts.torso as Node3D).global_position)
	await _seconds(0.3)
	lab._land(shocked.parts.torso, (shocked.parts.torso as Node3D).global_position, -_front(shocked), {"damage": 8.0, "impulse": 1.0, "damage_type": "blunt", "shock": true, "weapon": "staff"}, "melee", null)
	await _seconds(0.08)
	await _shot("5_shorted_xray")
	lab.bodies.press()
	lab._land(shocked.parts.torso, (shocked.parts.torso as Node3D).global_position, -_front(shocked), {"damage": 8.0, "impulse": 1.0, "damage_type": "blunt", "shock": true, "weapon": "staff"}, "melee", null)
	await _seconds(0.06)
	await _shot("6_shorted_sparks")
	print("CAPTURE shorted note=%s" % lab.last_note)

	# Frame rate at the station, X-ray on with the scan up, then off. Uncapped:
	# the window's vsync holds a display at 60.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	lab.bodies.press()
	_stand_before(scanned, 1.3)
	_aim((scanned.parts.torso as Node3D).global_position)
	var xray_fps := await _measure(3.0)
	lab.organ_scan.process_mode = Node.PROCESS_MODE_DISABLED
	lab.organ_scan.hide()
	var no_overlay_fps := await _measure(3.0)
	lab.organ_scan.process_mode = Node.PROCESS_MODE_INHERIT
	lab.bodies.press()
	var plain_fps := await _measure(3.0)
	var line := "bodies station, window %s: x-ray+scan %.1f fps, x-ray without the scan panel %.1f fps, x-ray off %.1f fps (GPU %s)" % [str(get_viewport().get_visible_rect().size), xray_fps, no_overlay_fps, plain_fps, RenderingServer.get_video_adapter_name()]
	print("CAPTURE FPS ", line)
	var file := FileAccess.open(shots.path_join("fps.txt"), FileAccess.WRITE)
	file.store_line(line)
	file.close()
	get_tree().quit(0)


## A camera of its own, 0.6 m over the chest, looking into it.
func _close_shot(rig: BaselineHuman, file_name: String, keep_hud: bool) -> void:
	var torso := rig.parts.torso as Node3D
	var centre := torso.global_position
	var toward: Vector3 = lab.player.global_position - centre
	toward.y = 0.0
	toward = toward.normalized()
	var eye := Camera3D.new()
	eye.fov = 50.0
	add_child(eye)
	# From above and the player's side, the way you would lean over to look in.
	eye.look_at_from_position(centre + Vector3.UP * 0.62 + toward * 0.38, centre, Vector3.UP)
	eye.current = true
	await _seconds(0.25)
	await _shot(file_name)
	eye.current = false
	lab.camera.current = true
	eye.queue_free()


func _blow(rig: BaselineHuman, index: int) -> void:
	var front := _front(rig)
	var at: Vector3 = (rig.parts.torso as Node3D).global_position + front * 0.1 + Vector3.DOWN * 0.17 + _side(rig) * (0.06 if index % 2 == 0 else -0.06)
	lab._land(rig.parts.torso, at, -front, {"damage": 30.0, "impulse": 3.0, "damage_type": "cut", "weapon": "cleaver"}, "melee", null)
	await _seconds(0.05)


func _measure(seconds: float) -> float:
	await _seconds(0.5)
	var frames := Engine.get_process_frames()
	var start := Time.get_ticks_usec()
	await _seconds(seconds)
	return float(Engine.get_process_frames() - frames) / (float(Time.get_ticks_usec() - start) / 1000000.0)


func _front(rig: BaselineHuman) -> Vector3:
	var front := -rig.global_transform.basis.z
	front.y = 0.0
	return front.normalized()


func _side(rig: BaselineHuman) -> Vector3:
	return rig.global_transform.basis.x.normalized()


func _heart_or_torso(rig: BaselineHuman) -> Vector3:
	var heart := rig.organ_parts.get("heart") as Node3D
	return heart.global_position if heart != null and heart.is_inside_tree() else (rig.parts.torso as Node3D).global_position


func _stand_before(rig: BaselineHuman, distance: float) -> void:
	var at := rig.global_position
	lab.player.global_position = Vector3(at.x, lab.player.global_position.y, at.z) + _front(rig) * distance
	lab.player.velocity = Vector3.ZERO


func _aim(target: Vector3) -> void:
	var eye: Camera3D = lab.camera
	var to := target - eye.global_position
	lab.yaw = atan2(-to.x, -to.z)
	lab.pitch = asin(clampf(to.normalized().y, -1.0, 1.0))
	lab.player.rotation.y = lab.yaw


func _seconds(value: float) -> void:
	await get_tree().create_timer(value).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(shots.path_join(file_name + ".png"))
	print("CAPTURE shot ", file_name)
