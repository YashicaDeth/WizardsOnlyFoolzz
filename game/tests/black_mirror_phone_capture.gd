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
	WorldHistory.clear_history()
	vat = VAT.instantiate()
	add_child(vat)
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
	await _settle(30)
	await _shot("00_desk_pickup_lit")
	await _press(JOY_BUTTON_X)
	_darken()
	# Face him across his dark office, the window and the vat floor behind.
	var him: Vector3 = route.fight.body.global_position
	_place(him + Vector3(3.4, 0, -1.6), him + Vector3(0, 1.0, 0))
	await _settle(20)
	await _shot("01_dark_naked_eye")
	await _press(JOY_BUTTON_BACK)
	await _settle(25)
	await _shot("02_camera_night")
	await _press(JOY_BUTTON_DPAD_UP)
	await _settle(25)
	await _shot("03_camera_depth")
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
	await _press(JOY_BUTTON_DPAD_RIGHT)
	await _settle(40)
	await _shot("07_page_carry")
	await _press(JOY_BUTTON_A)
	await _settle(10)
	await _shot("08_page_carry_brain_index")
	await _press(JOY_BUTTON_A)
	await _press(JOY_BUTTON_BACK)
	await _settle(6)
	await _shot("09_lowering")
	await _settle(40)
	await _shot("10_lowered")
	get_tree().quit()


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
