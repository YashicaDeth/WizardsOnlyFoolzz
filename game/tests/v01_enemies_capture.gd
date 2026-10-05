extends Node

## Job 9 visual proof: each v0.1 foe's telegraph and its kill, in the real
## route (vat_chamber on the one facility map), from the player's eyes, and
## the frame rate in each room with its foes awake.
## Run windowed: render_one.cmd v01_enemies_capture --out=DIR
## Writes DIR/v01_*.png and DIR/v01_enemies_fps.txt.

const FPS_SECONDS := 3.0

var out_dir := "P:/GameDev/Temp/job9_shots"
var vat: Node3D
var enc: V01Encounters
var fps_lines: Array[String] = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	OS.set_environment("ATG_V01_NO_DEATH_BEAT", "1")
	WorldHistory.clear_history()
	vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	vat.intake._finish_filing()
	await get_tree().process_frame
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	vat._physics_process(vat.REVENGE_HOLD + 0.1)
	preload("res://systems/clothing.gd").wear("player", "scavenged_coat")
	for _step in 80:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	enc = vat.encounters
	vat.doctor_route._take_axe()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _growing_floor()
	await _arcade()
	await _lower_works()
	var file := FileAccess.open("%s/v01_enemies_fps.txt" % out_dir, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(fps_lines) + "\n")
		file.close()
	print("\n".join(fps_lines))
	get_tree().quit()


# --- The freed subject. ----------------------------------------------------------

func _growing_floor() -> void:
	var tank: Dictionary = {}
	for each: Dictionary in vat.vat_smash.tanks:
		if int(each.seed) == 1 and (tank.is_empty() or float((each.at as Vector3).x) > float((tank.at as Vector3).x)):
			tank = each
	var at: Vector3 = tank.at
	_stand(Vector3(at.x - 2.6, 0.0, at.z + 1.2), at + Vector3(0, 1.2, 0))
	for _frame in 150:
		if enc.subject != null:
			break
		await get_tree().physics_frame
	var foe: V01FreedSubject = enc.subject
	if foe == null:
		print("CAPTURE_FAILED: no subject")
		return
	# Let it turn, then hold a pounce's crouch two thirds in.
	foe.dazed = 0.0
	foe.state = "alert"
	for _frame in 20:
		await get_tree().physics_frame
	foe.global_position = vat.player.global_position + Vector3(0.6, -vat.player.global_position.y, -3.6)
	await _measure("growing floor (freed subject loose)")
	_stand(vat.player.global_position - Vector3(0, vat.BODY_HALF_HEIGHT + 0.02, 0), foe.global_position + Vector3(0, 1.0, 0))
	await _hold(foe, "pounce", {"windup": foe.POUNCE_WINDUP, "colour": V01Foe.RED, "parryable": false, "blockable": false, "share": 0.08, "clip": "roll"}, 0.7, func() -> void: foe._crouch(true))
	await _capture("v01_subject_1_pounce_telegraph")
	foe._crouch(false)
	foe.cancel_windup()
	_stand(vat.player.global_position - Vector3(0, vat.BODY_HALF_HEIGHT + 0.02, 0), foe.global_position + Vector3(0, 1.0, 0))
	await _hold(foe, "claw", {"windup": 0.24, "colour": V01Foe.COPPER, "parryable": true, "blockable": true, "share": 0.04, "clip": "punch_jab"}, 0.75)
	await _capture("v01_subject_2_claw_telegraph")
	foe.cancel_windup()
	await _kill(foe, "cleaver")
	_stand(foe.global_position + Vector3(0.4, 0, 2.4), foe.global_position + Vector3(0, 0.2, 0))
	for _frame in 20:
		await get_tree().process_frame
	await _capture("v01_subject_3_killed")


# --- The guards. --------------------------------------------------------------------

func _arcade() -> void:
	var g47: V01Guard = enc.guards[0]
	var g49: V01Guard = enc.guards[2]
	_stand(Vector3(27.0, 0.0, -6.0), g47.global_position + Vector3(0, 1.4, 0))
	for guard in enc.guards:
		guard.alert(vat.player.global_position)
		guard.called = true
	await _measure("service arcade (three guards awake)")
	enc.set_physics_process(false)
	# 47, a step away: a COPPER light (parry it) and the RED shock (step out).
	g47.global_position = Vector3(27.0, 0.0, -9.0)
	_stand(Vector3(27.3, 0.0, -6.4), g47.global_position + Vector3(0, 1.3, 0))
	g47.face(vat.player.global_position - g47.global_position, 1.0)
	await _hold(g47, "light", g47.staff_spec("light"), 0.7)
	await _capture("v01_guard_1_staff_light_telegraph")
	g47.cancel_windup()
	await _hold(g47, "shock", g47.staff_spec("shock"), 0.75)
	await _capture("v01_guard_2_staff_shock_telegraph")
	g47.cancel_windup()
	# 49 down the hall: his red sight line, locked.
	_stand(Vector3(28.6, 0.0, -36.0), g49.global_position + Vector3(0, 1.4, 0))
	g49.face(vat.player.global_position - g49.global_position, 1.0)
	g49.aim_from = g49.global_position + Vector3(0, 1.45, 0)
	g49.aim_dir = (vat.player.global_position + Vector3(0, 0.4, 0) - g49.aim_from).normalized()
	g49.begin("aim", {"windup": V01Guard.AIM_SECONDS, "colour": V01Foe.RED, "parryable": false, "blockable": false, "share": 0.09, "clip": ""})
	if g49.sight_line != null:
		g49.sight_line.visible = true
	g49.windup = V01Guard.AIM_SECONDS * 0.85
	g49._glow(0.85)
	g49._draw_sight(g49.aim_from, g49.aim_dir)
	var rigged = (g49.body as BaselineHuman).rigged
	if rigged != null:
		rigged.play_action("pistol_aim", 1.0)
	for _frame in 20:
		await get_tree().process_frame
	await _capture("v01_guard_3_pistol_aim_telegraph")
	g49.cancel_windup()
	# 47 cut down: his body and his PRODSTAFF on the floor.
	await _kill(g47, "cleaver")
	_stand(g47.global_position + Vector3(1.6, 0, 2.0), g47.global_position + Vector3(0, 0.3, 0))
	for _frame in 30:
		await get_tree().process_frame
	await _capture("v01_guard_4_killed_staff_dropped")
	enc.set_physics_process(true)


# --- The sentinel. -----------------------------------------------------------------

func _lower_works() -> void:
	var sentinel: V01Sentinel = enc.sentinel
	_stand(Vector3(28.0, -12.0, -84.0), sentinel.global_position + Vector3(0, 1.2, 0))
	sentinel.alert(vat.player.global_position)
	await _measure("lower works (sentinel awake)")
	enc.set_physics_process(false)
	sentinel.global_position = Vector3(28.0, -12.0, -91.0)
	sentinel.face(vat.player.global_position - sentinel.global_position, 1.0)
	_stand(Vector3(28.4, -12.0, -84.5), sentinel.global_position + Vector3(0, 1.3, 0))
	sentinel.begin("ram", {"windup": V01Sentinel.RAM_WINDUP, "colour": V01Foe.RED, "parryable": false, "blockable": false, "share": 0.17})
	sentinel.windup = V01Sentinel.RAM_WINDUP * 0.7
	sentinel._glow(0.7)
	sentinel.body.rotation.x = 0.18 * ease(0.7, 0.5)
	sentinel._eye_material.emission_energy_multiplier = 3.0 + 0.7 * 9.0
	for _frame in 20:
		await get_tree().process_frame
	await _capture("v01_sentinel_1_ram_telegraph")
	sentinel.cancel_windup()
	sentinel.body.rotation.x = 0.0
	# The X-ray on it: plates, core, eye.
	enc.xray_on = true
	enc._update_xray()
	for _frame in 20:
		await get_tree().process_frame
	await _capture("v01_sentinel_2_xray_plates")
	enc.xray_on = false
	enc.xray.show_scan(null, vat.camera)
	# Its slam, close (copper: block or step back).
	_stand(Vector3(28.2, -12.0, -88.9), sentinel.global_position + Vector3(0, 1.3, 0))
	sentinel.begin("slam", {"windup": V01Sentinel.SLAM_WINDUP, "colour": V01Foe.COPPER, "parryable": false, "blockable": true, "share": 0.11})
	sentinel.windup = V01Sentinel.SLAM_WINDUP * 0.75
	sentinel.arm.rotation.x = 0.9 * ease(0.75, 0.6)
	sentinel._glow(0.75)
	for _frame in 20:
		await get_tree().process_frame
	await _capture("v01_sentinel_3_slam_telegraph")
	sentinel.cancel_windup()
	# Killed from behind: powered down, a plate off on the floor beside it.
	sentinel._shed("left")
	await _kill(sentinel, "cleaver")
	_stand(sentinel.global_position + Vector3(-2.8, 0, 2.6), sentinel.global_position + Vector3(0, 0.9, 0))
	for _frame in 40:
		await get_tree().process_frame
	await _capture("v01_sentinel_4_killed")
	enc.set_physics_process(true)


# --- Helpers. ---------------------------------------------------------------------

func _stand(at: Vector3, look: Vector3) -> void:
	vat.player.global_position = Vector3(at.x, at.y + vat.BODY_HALF_HEIGHT + 0.02, at.z)
	vat.player.velocity = Vector3.ZERO
	var eye: Vector3 = vat.player.global_position + Vector3(0, 0.77, 0)
	var to := look - eye
	vat.yaw = atan2(-to.x, -to.z)
	vat.pitch = atan2(to.y, Vector2(to.x, to.z).length())


## Starts a wind-up and freezes it at `amount`, glint lit, clip held.
func _hold(foe: V01Foe, move_id: String, spec: Dictionary, amount: float, pose: Callable = Callable()) -> void:
	enc.set_physics_process(false)
	foe.begin(move_id, spec)
	var frames := int(foe.windup_needed * amount * 60.0)
	for _frame in frames:
		foe.windup += 1.0 / 60.0
		foe._glow(clampf(foe.windup / foe.windup_needed, 0.0, 1.0))
		if pose.is_valid():
			pose.call()
		await get_tree().process_frame
	var rigged = foe.body.get("rigged") if foe.body != null else null
	if rigged != null:
		rigged.player.speed_scale = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if rigged != null:
		rigged.player.speed_scale = 1.0


func _kill(foe: V01Foe, weapon: String) -> void:
	var behind := foe.global_position - foe.forward() * 2.0
	foe.take_blow({"weapon": weapon, "move": "heavy", "damage": foe.max_health * 3.0, "from": behind, "direction": foe.forward(), "zone": "torso", "kind": "cut", "impulse": 8.0, "part": "core"})
	for _frame in 60:
		await get_tree().process_frame


## Average and worst frame time over FPS_SECONDS with the room's foes awake.
func _measure(room: String) -> void:
	for _frame in 30:
		await get_tree().process_frame
	var frames := 0
	var worst := 0.0
	var started := Time.get_ticks_usec()
	var last := started
	while Time.get_ticks_usec() - started < int(FPS_SECONDS * 1000000.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
	var seconds := (Time.get_ticks_usec() - started) / 1000000.0
	var line := "FPS %s: %.0f average, worst frame %.1f ms (%d frames, vsync off, 1280x720)" % [room, frames / seconds, worst, frames]
	fps_lines.append(line)
	print(line)


func _capture(shot: String) -> void:
	for overlay in [vat.get("title"), vat.get("mission_card"), vat.get("key_hints")]:
		if overlay is Object and is_instance_valid(overlay) and overlay.get("visible") != null:
			overlay.set("visible", false)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, shot]
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
