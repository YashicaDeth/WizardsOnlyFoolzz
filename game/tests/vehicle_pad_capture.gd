extends Node

## Lab-53 PROOF: a car on the mechanics lab's vehicle pad before, after a wall
## hit, and after the second car rams it, with the frame rate over both runs.
## Windowed only, through AgentHub/render_one.cmd:
##   render_one.cmd vehicle_pad_capture --shots=P:/GameDev/Temp/lab53
## SUV comes from behind. Writes 1_before.png, 2_after_wall.png, 3_after_ram.png, 4_pad_wide.png and
## fps.txt into the folder.

var lab: Node3D
var eye: Camera3D
var shots := "P:/GameDev/Temp/lab53"
var _fps: Array[float] = []


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	# Measure the frame, not the monitor's refresh.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	eye = Camera3D.new()
	eye.fov = 62.0
	add_child(eye)
	await _seconds(1.0)
	eye.current = true
	var pad = lab.vehicles
	var car: RigidBody3D = pad.cars[0]
	var suv: RigidBody3D = pad.cars[1]
	var damage := car.get_node("Damage") as VehicleDamage
	await _shot_car("1_before", car)
	# The lab standing still, for comparison with the runs.
	await _until(func() -> bool: return false, 2.0)
	var idle := _fps.duplicate()
	_fps.clear()

	# Into the concrete wall, full throttle from the pad.
	car.enabled = true
	car.throttle = 1.0
	# From parked: the lane is about 24 m, enough to pass steel's ram tier.
	await _until(func() -> bool: return damage.hits > 0, 8.0)
	car.throttle = 0.0
	await _seconds(1.5)
	car.enabled = false
	await _shot_car("2_after_wall", car)

	# The SUV comes in from behind at full throttle and pins it to the wall.
	var back := car.global_basis.z.slide(Vector3.UP).normalized()
	var start := car.global_position + back * 11.0
	start.y = suv.global_position.y
	suv.teleport(Transform3D(Basis.looking_at(-back, Vector3.UP), start))
	await _seconds(0.3)
	suv.enabled = true
	suv.throttle = 1.0
	suv.linear_velocity = -suv.global_basis.z * 15.0
	var before := damage.hits
	await _until(func() -> bool: return damage.hits > before, 5.0)
	suv.throttle = 0.0
	await _seconds(1.5)
	suv.enabled = false
	await _shot_car("3_after_ram", car)
	await _shot("4_pad_wide", pad.to_global(Vector3(-4.0, 8.0, 10.0)), pad.to_global(Vector3(4.0, 0, -10.0)))

	var report := damage.report()
	var low: float = _fps.min() if not _fps.is_empty() else 0.0
	var mean := 0.0
	for value in _fps:
		mean += value
	mean /= maxf(1.0, float(_fps.size()))
	var idle_mean := 0.0
	for value in idle:
		idle_mean += value
	idle_mean /= maxf(1.0, float(idle.size()))
	var text := "adapter %s\nfps idle (cars parked): mean %.0f\nfps over both runs: mean %.0f, min %.0f (%d samples)\ncar after: %s\nsuv after: %s\n" % [
		RenderingServer.get_video_adapter_name(), idle_mean, mean, low, _fps.size(), report, (suv.get_node("Damage") as VehicleDamage).report()]
	var file := FileAccess.open("%s/fps.txt" % shots, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
	print("VEHICLE_PAD_CAPTURE ", text)
	get_tree().quit()


func _until(done: Callable, limit: float) -> void:
	var waited := 0.0
	while waited < limit and not done.call():
		await get_tree().process_frame
		waited += get_process_delta_time()
		_fps.append(Engine.get_frames_per_second())


## From the car's front-left quarter: the nose and the driver's side.
func _shot_car(label: String, car: RigidBody3D) -> void:
	var basis := car.global_basis
	var flat_x := basis.x.slide(Vector3.UP).normalized()
	var flat_z := basis.z.slide(Vector3.UP).normalized()
	await _shot(label, car.global_position + -flat_x * 4.6 - flat_z * 2.6 + Vector3.UP * 1.8, car.global_position + Vector3.UP * 0.1)


func _shot(label: String, from: Vector3, at: Vector3) -> void:
	eye.global_position = from
	eye.look_at(at)
	if DisplayServer.get_name() == "headless":
		print("VEHICLE_PAD_CAPTURE %s: headless, nothing rendered" % label)
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	var path := "%s/%s.png" % [shots, label]
	image.save_png(path)
	print("VEHICLE_PAD_CAPTURE ", path)


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
