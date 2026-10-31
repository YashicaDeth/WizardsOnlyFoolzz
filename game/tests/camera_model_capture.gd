extends Node3D
## The generated CCTV on its wall, looked at: three-quarter, side and front
## views, the housing swept to either end of its arc (the bracket must not move),
## the state colours, and smashed.
##   Godot --path game res://tests/camera_model_capture.tscn -- --out=P:/GameDev/Temp/cctv

var lens: SecurityCamera
var eye: Camera3D


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp/cctv"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.05, 0.05, 0.06)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.5, 0.5, 0.55)
	settings.ambient_light_energy = 0.7
	var environment := WorldEnvironment.new()
	environment.environment = settings
	add_child(environment)
	var key := OmniLight3D.new()
	key.position = Vector3(1.5, 3.6, -2.0)
	key.omni_range = 9.0
	key.light_energy = 3.0
	add_child(key)
	var wall := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(10.0, 6.0, 0.3)
	slab.material = LabSurface.material("plate")
	wall.mesh = slab
	wall.position = Vector3(0.0, 3.0, 0.15)
	add_child(wall)
	lens = SecurityCamera.new()
	lens.position = Vector3(0.0, 3.0, 0.0)
	# The lens node looks along -Z; this stands it facing the observer (-Z is
	# out from the wall here), so no turn is needed.
	add_child(lens)
	lens.build("camera_model_capture")
	eye = Camera3D.new()
	eye.fov = 34.0
	add_child(eye)
	eye.make_current()
	await _settle(4)
	print("CCTV bracket=", lens.get_node_or_null("Bracket") != null, " housing model=", lens.head.get_node_or_null("HousingModel") != null, " head=", lens.head.position)
	var views := {
		"3q": [Vector3(1.9, 3.0, -2.2), Vector3(0.0, 2.75, -0.2)],
		"side": [Vector3(2.8, 2.8, -0.35), Vector3(0.0, 2.75, -0.35)],
		"front": [Vector3(0.0, 3.0, -3.0), Vector3(0.0, 2.75, -0.2)],
	}
	for view: String in views:
		_look(views[view][0], views[view][1])
		await _shoot("%s/cctv_%s.png" % [out_dir, view])
	# The arc: the housing swings, the bracket does not.
	for yaw in [-lens.sweep_half, lens.sweep_half]:
		lens.head.rotation.y = yaw
		_look(views["3q"][0], views["3q"][1])
		await _shoot("%s/cctv_sweep_%s.png" % [out_dir, "left" if yaw < 0.0 else "right"])
	lens.head.rotation.y = 0.0
	# Signals on (the cone and beam), then locked on and tracking.
	SecurityCamera.show_signals(true)
	lens.tracking = true
	lens.lock = 1.0
	lens._tint()
	_look(Vector3(1.9, 3.3, -2.6), Vector3(0.0, 2.6, -1.5))
	await _shoot("%s/cctv_tracking.png" % out_dir)
	SecurityCamera.show_signals(false)
	lens.tracking = false
	lens.lock = 0.0
	# Smashed.
	lens.smash("capture")
	_look(views["3q"][0], views["3q"][1])
	await _settle(4)
	await _shoot("%s/cctv_smashed.png" % out_dir)
	get_tree().quit()


func _look(from: Vector3, at: Vector3) -> void:
	eye.position = from
	eye.look_at(at, Vector3.UP)


func _settle(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _shoot(path: String) -> void:
	await _settle(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path)
