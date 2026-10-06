extends Node

## Windowed only through AgentHub/render_one.cmd. Captures the real production
## vat scene at each join and during both physical lift rides.

const VAT := preload("res://vat_chamber.tscn")

var vat: Node3D
var facility: Node3D
var shots := "P:/GameDev/Temp/job5-facility-one-map"
var fps_samples: Array[float] = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("FACILITY_ONE_MAP_CAPTURE headless draws nothing; use AgentHub/render_one.cmd")
		get_tree().quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	vat = VAT.instantiate()
	add_child(vat)
	await _frames(8)
	facility = vat.facility_map
	vat.phase = "aisle"
	vat.breakout_complete = true
	vat.can_move = true
	vat.fade.color.a = 0.0
	vat.submerge_tint.color.a = 0.0
	# Real play reaches the aisle with the intake filed and the beat line
	# cleared; the OSD (and the objective it adopts) only shows after that.
	if vat.intake != null:
		vat.intake.queue_free()
		vat.intake = null
	vat.subtitle.text = ""
	vat.line_index = vat.active_beats.size()
	if vat.load_in != null:
		vat.load_in.visible = false
	vat._open_staff_door(false)
	vat.camera.current = true
	vat.player.global_position = Vector3(4.4, 0.86, -2.5)
	vat.player.velocity = Vector3.ZERO
	# Let the opening's smash debris land first: a player reaches this door
	# long after it settles (the "floating red slabs" were it mid-flight).
	await get_tree().create_timer(3.0).timeout

	await _pose_and_capture("01_staff_door_to_artery.png", Vector3(4.4, 0.86, -2.5), -PI * 0.5)
	vat.thought_life = 0.0
	await _walk(Vector3(9.5, 0.0, -2.5))
	await _walk(Vector3(18.0, 0.0, -2.5))
	await _capture("02_artery_to_arcade.png")
	await _walk(Vector3(28.0, 0.0, -2.5))
	# The arcade's landmark from its entry: the shuttered stalls (imp-67).
	var held_pitch: float = vat.pitch
	await _look_at(Vector3(21.0, 1.4, -17.5))
	await _capture("02b_arcade_entry_stalls.png")
	vat.pitch = held_pitch
	await _walk(Vector3(28.0, 0.0, -24.0))
	await _capture("03a_arcade_mid.png")
	await _walk(Vector3(28.0, 0.0, -36.0))
	await _look_at(Vector3(23.0, 1.4, -41.5))
	await _capture("03b_arcade_story_props.png")
	await _walk(Vector3(28.0, 0.0, -55.0))
	await _capture("03_arcade_to_transit.png")

	var transit: FacilityElevator = facility.lifts["transit"]
	await _walk(Vector3(28.0, 0.0, -62.0))
	vat._interact()
	await _until(func() -> bool: return transit.state == "moving" and transit.cab.position.y < -3.0)
	await _look_out_of_cab()
	await _capture("04_transit_lift_riding_down.png")
	await _until(func() -> bool: return transit.state == "open")
	await _walk(Vector3(28.0, 0.0, -70.0))
	await _capture("05_transit_to_lower_works.png")
	await _walk(Vector3(28.0, 0.0, -94.0))
	await _capture("05b_lower_works_mid.png")
	await _look_at(Vector3(38.0, -10.5, -98.0))
	await _capture("05c_lower_works_story_props.png")
	await _walk(Vector3(28.0, 0.0, -116.8))
	await _capture("06_lower_works_to_heat_lift.png")

	var heat: FacilityElevator = facility.lifts["heat"]
	await _walk(Vector3(28.0, 0.0, -122.0))
	vat._interact()
	await _until(func() -> bool: return heat.state == "moving" and heat.cab.position.y > -5.0)
	await _look_out_of_cab()
	await _capture("07_heat_lift_riding_up.png")
	await _until(func() -> bool: return heat.state == "open")
	await _walk(Vector3(28.0, 0.0, -130.0))
	await _capture("08_surface_gate_daylight.png")
	await _walk(Vector3(28.0, 0.0, -138.0))

	var minimum: float = fps_samples.min() if not fps_samples.is_empty() else 0.0
	var total := 0.0
	for sample in fps_samples:
		total += sample
	var average := total / maxf(1.0, float(fps_samples.size()))
	var result := "FACILITY_ONE_MAP_CAPTURE_RESULT walked=vat_to_surface shots=13 fps_min=%.1f fps_average=%.1f" % [minimum, average]
	print(result)
	# render_one.cmd runs the window detached: keep the numbers with the PNGs.
	var report := FileAccess.open(shots.path_join("result.txt"), FileAccess.WRITE)
	if report != null:
		report.store_line(result)
		report.store_line("fps per shot: %s" % [fps_samples])
		report.close()
	get_tree().quit()


## Turn the real camera onto a story prop, as a player looking round would.
func _look_at(target: Vector3) -> void:
	var to: Vector3 = target - vat.camera.global_position
	vat.yaw = atan2(-to.x, -to.z)
	vat.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(8)


## You keep control in the car: turn to the side slot and watch the shaft go by.
func _look_out_of_cab() -> void:
	vat.yaw += PI * 0.5
	vat.pitch = 0.05
	await _frames(6)
	vat.yaw -= PI * 0.5
	vat.yaw += PI * 0.38
	await _frames(4)


func _pose_and_capture(file_name: String, at: Vector3, heading: float) -> void:
	vat.player.global_position = at
	vat.player.velocity = Vector3.ZERO
	vat.yaw = heading
	vat.pitch = -0.03
	vat.player.rotation.y = heading
	vat._update_hud()
	await _frames(12)
	await _capture(file_name)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := shots.path_join(file_name)
	var result := get_viewport().get_texture().get_image().save_png(path)
	if result != OK:
		push_error("CAPTURE_FAILED %s" % path)
	else:
		print("CAPTURED: %s" % path)
	fps_samples.append(float(Engine.get_frames_per_second()))


func _until(condition: Callable) -> bool:
	for _frame in 900:
		if condition.call():
			return true
		await get_tree().physics_frame
	push_error("CAPTURE_TIMEOUT waiting for lift state")
	return false


## Drive the real opening controller with its real InputMap actions. Goals use
## x/z only so the same walk continues after each moving cab changes level.
func _walk(goal: Vector3) -> bool:
	var ok := await _until(func() -> bool:
		var to: Vector3 = goal - vat.player.global_position
		to.y = 0.0
		if to.length() < 0.45:
			return true
		vat.yaw = atan2(-to.x, -to.z)
		Input.action_press("move_forward")
		Input.action_press("sprint")
		return false)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	vat.player.velocity.x = 0.0
	vat.player.velocity.z = 0.0
	if not ok:
		push_error("CAPTURE_WALK_STUCK at %s heading for %s" % [vat.player.global_position, goal])
	return ok


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame
