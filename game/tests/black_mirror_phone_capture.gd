extends Node

## v02-51 visual proof. The examiner's office with every light killed, so the
## shots show what the Black Mirror gives you in the dark: naked eye, the
## handheld rising, the low-light camera, the depth image with its tracked
## boxes, MAP, CARRY and the Brain Index, then lowered. Driven by pad events
## through Input.parse_input_event, the same path a controller takes.
## Usage: render_one.cmd black_mirror_phone_capture -- --out=DIR

const VAT := preload("res://vat_chamber.tscn")

var out_dir := "P:/GameDev/Temp/v02-51"
var vat


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	WorldHistory.clear_history()
	vat = VAT.instantiate()
	# As in the game: the vat room is the root's current scene, so PadBridge
	# leaves the pad to the migrated route instead of synthesizing keys
	# (D-UP = K). current_scene must be a direct child of the root.
	await get_tree().process_frame
	get_tree().root.add_child(vat)
	get_tree().current_scene = vat
	await get_tree().process_frame
	await _stand_up()
	var route = vat.doctor_route
	while not route.door.broken:
		route.door.hit("axe", route.DOOR_AT + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
	route.fight.set_physics_process(false)
	route.fight.set_process(false)
	# The opening's guided turn toward his door would steer the view for 2.4 s.
	route._look_left = 0.0
	var desk_phone: Vector3 = route.mirror_model.global_position
	_place(Vector3(desk_phone.x, 0, desk_phone.z + 0.8), desk_phone)
	# GET REVENGE plays for about 5 s after standing up; shoot after it.
	await get_tree().create_timer(6.5).timeout
	await _shot("00_desk_pickup_lit")
	await _press(JOY_BUTTON_X)
	_darken()
	# Face him across his dark office, the window and the vat floor behind.
	var him: Vector3 = route.fight.body.global_position
	_place(him + Vector3(3.4, 0, -1.6), him + Vector3(0, 1.0, 0))
	await _settle(20)
	await _shot("01_dark_naked_eye")
	await _fps("naked eye, phone down")
	await _press(JOY_BUTTON_BACK)
	await _settle(25)
	await _shot("02_camera_night")
	await _fps("night")
	await _press(JOY_BUTTON_DPAD_UP)
	await _settle(25)
	await _shot("03_camera_depth")
	await _fps("depth")
	if OS.get_cmdline_user_args().has("--probe"):
		var phone = vat.phone
		phone.lens.overlay.visible = false
		await _fps("PROBE depth, lens overlay hidden")
		phone.rail.visible = false
		await _fps("PROBE + rail hidden")
		phone.lens.tracker.visible = false
		await _fps("PROBE + tracker hidden")
		phone.lens.depth_quad.visible = false
		await _fps("PROBE + depth quad hidden")
		phone.lens.overlay.visible = true
		phone.rail.visible = true
		phone.lens.tracker.visible = true
		phone.lens.depth_quad.visible = true
	# Look back out through his window at the vat floor: tanks and subjects.
	_place(him + Vector3(2.0, 0, 0.6), Vector3(-1.0, 1.4, -6.0))
	await _settle(25)
	await _shot("04_camera_depth_vat_floor")
	_place(him + Vector3(3.4, 0, -1.6), him + Vector3(0, 1.0, 0))
	await _press(JOY_BUTTON_DPAD_UP)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _settle(8)
	await _shot("05_handheld_rising")
	await _settle(40)
	await _shot("06_page_map")
	await _fps("MAP page")
	if OS.get_cmdline_user_args().has("--probe"):
		var hh = vat.phone.handheld
		hh._map.set_process(false)
		await _fps("PROBE map process off")
		hh.set_process(false)
		await _fps("PROBE + handheld process off")
		vat.phone.set_process(false)
		await _fps("PROBE + phone process off")
		vat.phone._page_sprite.visible = false
		await _fps("PROBE + picture hidden")
		hh._map.set_process(true)
		hh.set_process(true)
		vat.phone.set_process(true)
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _settle(40)
	await _shot("07_page_carry")
	await _fps("CARRY page")
	await _press(JOY_BUTTON_A)
	await _settle(10)
	await _shot("08_page_carry_brain_index")
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_BACK)
	await _settle(6)
	await _shot("09_lowering")
	await _settle(40)
	await _shot("10_lowered")
	await _fps("lowered again")
	get_tree().quit()


## Frames over two seconds of real time, windowed (BUILD_BRIEFS rule 6).
func _fps(label: String) -> void:
	var start := Engine.get_process_frames()
	var began := Time.get_ticks_msec()
	await get_tree().create_timer(2.0).timeout
	var seconds := float(Time.get_ticks_msec() - began) / 1000.0
	var line := "FPS %s: %.0f (vsync off, 1280x720)" % [label, float(Engine.get_process_frames() - start) / seconds]
	print(line)
	var log := FileAccess.open("%s/fps.txt" % out_dir, FileAccess.READ_WRITE if FileAccess.file_exists("%s/fps.txt" % out_dir) else FileAccess.WRITE)
	log.seek_end()
	log.store_line(line)
	log.close()


func _darken() -> void:
	for light in _all(vat, "Light3D"):
		(light as Light3D).light_energy = 0.0
	var environment: Environment = vat.get_node("WorldEnvironment").environment
	environment.ambient_light_energy = 0.02
	environment.background_color = Color.BLACK


func _all(root: Node, type_name: String) -> Array:
	var found: Array = []
	for child in root.get_children():
		if child.is_class(type_name):
			found.append(child)
		found.append_array(_all(child, type_name))
	return found


func _press(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _settle(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	# The capture window can catch stray desktop mouse motion, which flips the
	# hints to keyboard; every press here was a pad press.
	InputProfile.set_device_preference(true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED: ", path)


func _stand_up() -> void:
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
	await get_tree().physics_frame


func _place(at: Vector3, look_at_point: Vector3) -> void:
	vat.player.global_position = Vector3(at.x, vat.BODY_HALF_HEIGHT + 0.02, at.z)
	vat.player.velocity = Vector3.ZERO
	var to := look_at_point - Vector3(at.x, vat.BODY_HALF_HEIGHT + 0.7, at.z)
	vat.yaw = atan2(-to.x, -to.z)
	vat.pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.5, 0.5)
	vat.player.rotation.y = vat.yaw
	vat.camera.rotation = Vector3.ZERO
