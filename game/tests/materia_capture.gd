extends Node

## drug-70 PROOF. Windowed only (headless draws nothing):
##   P:/GameDev/AgentHub/render_one.cmd materia_capture --shots=P:/GameDev/Temp/drug70
## Writes into the folder:
##   class_<id>.png    each of the nine class presets at its peak, at the station
##   plume_calm_*.png  an exhale toward the body with no wind (0.6 / 1.4 / 2.6 s)
##   plume_wind_*.png  the same exhale in a 1.6 m/s wind, bending and curling round
##   ring.png          a smoke ring
##   ember_draw.png    the lit end mid-draw with a built ash column
##   ember_flick_*.png the ash knocked off and falling
##   trip_*.png        the trip sequence at 6 / 14 / 22 / 27 / 33 s
##   fps.txt           frame time at the station with smoke and a preset live

var lab: Node3D
var station
var eye: Camera3D
var shots := "P:/GameDev/Temp/drug70"
var lines: Array[String] = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	WorldHistory.clear_history()
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	station = lab.materia
	station.clock_rate = 0.0
	station.lost_time_enabled = false
	eye = Camera3D.new()
	eye.fov = 70.0
	add_child(eye)
	await _seconds(0.6)
	eye.current = true
	lines.append("clock %s  daylight %.2f" % [WorldClock.stamp(), WorldClock.daylight()])

	await _classes()
	await _plumes()
	await _ember()
	await _trip()
	await _fps()

	var file := FileAccess.open(shots.path_join("fps.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("\n".join(lines))
	print("MATERIA_CAPTURE_DONE %s" % shots)
	get_tree().quit()


func _classes() -> void:
	var from: Vector3 = station.to_global(Vector3(0.6, 1.65, 2.6))
	var at: Vector3 = station.to_global(Vector3(0.2, 1.0, -0.6))
	for class_id: String in Materia.CLASS_ORDER:
		WorldHistory.amend_subject("player", {Materia.DOSES_KEY: []})
		var spec: Dictionary = Materia.CLASSES[class_id]
		var now := WorldClock.minutes()
		# Dosed so that "now" sits in the middle of the peak.
		Materia.dose("player", class_id, now - float(spec.onset) - float(spec.peak) * 0.5)
		# Let feedback trails and the beat settle into the look.
		await _seconds(1.6)
		await _shot("class_%s" % class_id, from, at)
		lines.append("%s  phase %s  level %.2f  plane %s  altitude %.1f" % [class_id, str(station.last_state.phase), float(station.last_state.level), str(station.last_state.plane), float(station.last_state.altitude)])
	WorldHistory.amend_subject("player", {Materia.DOSES_KEY: []})
	station.rig.reset_dials()
	await _seconds(0.3)


func _plumes() -> void:
	var dummy: BaselineHuman = station.dummy
	var body: Vector3 = dummy.global_position
	var mouth := body + Vector3(-1.25, 1.5, 0.2)
	var toward := (body + Vector3(0, 1.4, 0) - mouth).normalized()
	# Close, across the line of the breath, the body filling the right third.
	var from := body + Vector3(-0.55, 1.5, 2.1)
	var look := body + Vector3(-0.5, 1.4, 0)
	for pass_name: String in ["calm", "wind"]:
		station.smoke.clear()
		station.wind_override = 0.0 if pass_name == "calm" else 1.6
		await _frames(2)
		station.smoke.exhale("joint", mouth, toward, 1.25, 1.3)
		var t := 0.0
		for stamp in [0.6, 1.4, 2.6]:
			await _seconds(stamp - t)
			t = stamp
			await _shot("plume_%s_%s" % [pass_name, str(stamp).replace(".", "")], from, look)
		lines.append("plume %s  parcels %d  centroid %s  deepest-in-body %.3f" % [pass_name, station.smoke.count(), str(station.smoke.centroid()), station.smoke.deepest_inside()])
	# Rings, seen from the side as they travel.
	station.smoke.clear()
	station.wind_override = 0.2
	var ring_from := body + Vector3(-1.6, 1.5, -0.6)
	station.smoke.ring("cigarette", ring_from, Vector3(0, 0.05, 1), 1.0)
	await _seconds(0.5)
	station.smoke.ring("cigarette", ring_from, Vector3(0, 0.05, 1), 1.0)
	await _seconds(0.6)
	await _shot("ring", ring_from + Vector3(1.4, 0.15, 0.6), ring_from + Vector3(0, 0, 0.6))
	station.wind_override = -1.0
	station.smoke.clear()


func _ember() -> void:
	# A cigarette on its own in the air at eye height, lit, so a fixed camera
	# can sit beside the coal: heat, ash column, then the flick and the fall.
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = station.to_global(Vector3(-0.6, 1.45, 1.6))
	var cig := Smokeables.build("cigarette", 0.15)
	holder.add_child(cig)
	cig.rotation.y = PI * 0.5
	var coal: Node3D = (cig.get_meta("parts") as Dictionary).get("coal")
	var ember := SmokeEmber.new()
	add_child(ember)
	ember.attach(cig, "cigarette", station.smoke, lab)
	# Build ash over "a minute" of burning, drawing part of it.
	for index in 40:
		ember.tick(0.05, 1.0 if index > 30 else 0.0)
		await get_tree().process_frame
	ember.ash_length = 0.017
	for index in 6:
		ember.tick(0.05, 1.0)
	var tip := coal.global_position
	var close := Camera3D.new()
	close.fov = 28.0
	close.near = 0.005
	add_child(close)
	close.global_position = tip + Vector3(-0.05, 0.03, 0.17)
	close.look_at(tip + Vector3(-0.012, 0, 0), Vector3.UP)
	close.current = true
	await _frames(2)
	await _save("ember_draw")
	lines.append("ember heat %.2f  ash %.1f mm" % [ember.heat, ember.ash_length * 1000.0])
	# Let it rest and smoke a sidestream, then flick.
	for index in 20:
		ember.tick(get_process_delta_time(), 0.0)
		await get_tree().process_frame
	await _save("ember_rest")
	# One fixed side view framing the half metre under the tip, so the column
	# can be followed as it falls (about 3, 12 and 28 cm at these stamps).
	close.global_position = tip + Vector3(0.0, -0.22, 0.75)
	close.fov = 40.0
	close.look_at(tip + Vector3(0.0, -0.22, 0.0), Vector3.UP)
	ember.flick(Vector3(-0.3, -1, 0))
	for index in 3:
		await _seconds(0.08)
		await _save("ember_flick_%d" % index)
	lines.append("ash drops %d  reason %s" % [ember.drops, ember.last_drop_reason])
	await _seconds(1.2)
	await _save("ember_landed")
	# The lungs: a real draw in hand, so the pulmonary panel shows the smoke.
	lab.go_to(5)
	await _frames(3)
	lab.camera.current = true
	station.take_smokeable("cigarette")
	station.begin_draw()
	await _seconds(1.3)
	await _save("lungs_draw")
	station.end_draw()
	await _seconds(1.5)
	await _save("exhale_first_person")
	station.put_away()
	ember.detach()
	holder.queue_free()
	close.queue_free()
	eye.current = true


func _trip() -> void:
	var from: Vector3 = station.to_global(Vector3(0.6, 1.65, 2.6))
	var at: Vector3 = station.to_global(Vector3(0.2, 1.0, -0.6))
	eye.global_position = from
	eye.look_at(at, Vector3.UP)
	station.trip.play()
	var t := 0.0
	for stamp in [6.0, 14.0, 22.0, 27.0, 33.0]:
		await _seconds(stamp - t)
		t = stamp
		await _save("trip_%02d" % int(stamp))
	station.trip.skip()
	await _seconds(0.8)


func _fps() -> void:
	lab.go_to(5)
	await _frames(2)
	lab.camera.current = true
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var spec: Dictionary = Materia.CLASSES.psychedelic
	for pass_name: String in ["baseline", "dose only", "smoke only", "dose and smoke"]:
		WorldHistory.amend_subject("player", {Materia.DOSES_KEY: []})
		station.rig.reset_dials()
		station.smoke.clear()
		station.put_away()
		if pass_name.begins_with("dose"):
			Materia.dose("player", "psychedelic", WorldClock.minutes() - float(spec.onset) - 5.0)
		var smoking := pass_name.ends_with("smoke") or pass_name == "smoke only"
		if smoking:
			station.take_smokeable("joint")
		await _seconds(0.6)
		var frames := 0
		var gpu := 0.0
		var script := 0.0
		var physics := 0.0
		var start := Time.get_ticks_usec()
		var spawned := 0.0
		while Time.get_ticks_usec() - start < 3000000:
			await get_tree().process_frame
			frames += 1
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
			script += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			spawned += get_process_delta_time()
			if smoking and spawned > 0.7:
				spawned = 0.0
				station.smoke.exhale("joint", station.mouth(), station.forward(), 1.2, 1.2)
		var seconds := float(Time.get_ticks_usec() - start) / 1000000.0
		lines.append("fps %-15s %.1f fps (%.2f ms)  gpu %.2f  process %.2f  physics %.2f  parcels %d  draws %d" % [pass_name, float(frames) / seconds,
			seconds * 1000.0 / float(frames), gpu / frames, script / frames, physics / frames, station.smoke.count(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	await _save("fps_view")
	station.put_away()


func _shot(name: String, from: Vector3, at: Vector3) -> void:
	eye.global_position = from
	eye.look_at(at, Vector3.UP)
	eye.current = true
	await _frames(2)
	await _save(name)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(shots.path_join("%s.png" % name))


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
