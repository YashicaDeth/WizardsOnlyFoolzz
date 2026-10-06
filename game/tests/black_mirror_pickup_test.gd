extends Node

## v02-51. Greg, 6 Oct: "we gotta make the black mirror like work", in the v0.1
## route, picked up in the examiner's office; 5 Oct: one device, raised and
## lowered with one button, every page reachable on the pad, broken pages
## hidden. The whole walk on pad events only, through the engine's own input
## path (Input.parse_input_event): out of the vat, his door down, the phone on
## his desk, CREATE raises it, the d-pad walks CAMERA / MAP / CARRY, d-pad up
## turns the camera to the depth image and the tracker boxes him, Cross opens
## the Brain Index, CREATE puts it away.

const VAT := preload("res://vat_chamber.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var vat = VAT.instantiate()
	# As in the game: the vat room is the root's current scene, so PadBridge
	# leaves the pad to the migrated route instead of synthesizing keys
	# (D-UP = K). current_scene must be a direct child of the root.
	await get_tree().process_frame
	get_tree().root.add_child(vat)
	get_tree().current_scene = vat
	await get_tree().process_frame
	await _stand_up(vat)
	var route = vat.doctor_route
	var phone: BlackMirrorPhone = vat.phone
	check(phone != null, "the route carries a Black Mirror phone node")
	check(route.mirror_model != null and route.mirror_model.visible, "the phone lies on his desk")
	check(not BlackMirrorPhone.is_held(), "and it is not yours yet")

	# The plan the MAP page draws is the facility's own footprints.
	var titles: Array = []
	for entry: Dictionary in vat.facility_map.plan_rooms():
		titles.append(str(entry.title))
	for wanted in ["GROWING FLOOR", "EXAMINATION ROOM", "SERVICE ARCADE", "LOWER WORKS", "TRANSIT LIFT", "HEAT ELEVATOR", "SERVICE ARTERY"]:
		check(titles.has(wanted), "the facility plan holds %s" % wanted)

	await _press(JOY_BUTTON_BACK)
	check(not phone.raised, "CREATE raises nothing before the phone is taken")

	# His door down; keep him out of it so this stays a phone test.
	while not route.door.broken:
		route.door.hit("axe", route.DOOR_AT + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
	route.fight.set_physics_process(false)
	route.fight.set_process(false)
	# The opening's guided turn toward his door would steer the view for 2.4 s.
	route._look_left = 0.0
	var desk_phone: Vector3 = route.mirror_model.global_position
	_place(vat, Vector3(desk_phone.x, 0, desk_phone.z + 0.75), desk_phone)
	await get_tree().physics_frame
	vat._update_hud()
	check(route.prompt_text().contains("TAKE THE BLACK MIRROR"), "standing at his desk, the prompt offers it (%s)" % route.prompt_text())
	await _press(JOY_BUTTON_X)
	check(BlackMirrorPhone.is_held(), "SQUARE takes it")
	check(not route.mirror_model.visible, "it leaves the desk")
	check(WorldHistory.event_count("black_mirror_taken") == 1, "the taking is on the record")

	var world_env: Environment = vat.get_node("WorldEnvironment").environment
	await _press(JOY_BUTTON_BACK)
	check(phone.raised and phone.page == "CAMERA", "CREATE raises it, on the camera")
	check(bool(phone.lens.active) and phone.lens.visible, "the night sensor is live")
	check(vat.camera.environment != null and vat.camera.environment != world_env, "the lens grades only the camera's own view")
	check(vat.get_node("WorldEnvironment").environment == world_env, "the room's own environment is untouched")
	check(bool(vat.sight.phone_lens), "signals pulse through the lens, as in the Hunt")

	# Face him for the depth image.
	var him: Vector3 = route.fight.body.global_position
	_place(vat, him + Vector3(2.6, 0, 0.4), him + Vector3(0, 1.0, 0))
	await _press(JOY_BUTTON_DPAD_UP)
	check(str(phone.lens.mode) == "depth", "D-UP turns the camera to the depth image")
	check(not bool(vat.sight.phone_lens), "the signal pass stays off the depth image")
	for _frame in 3:
		await get_tree().physics_frame
	check(not vat.encounters.xray_on, "D-UP on the raised phone does not also switch the X-ray")
	check(str(vat.sight.mode) == "", "nor the wizard eyes")
	check(not vat.key_hints.visible, "the key-hint box is out of the way of the raised phone")
	check(phone.lens.depth_quad != null and phone.lens.depth_quad.visible, "the depth pass is on the camera")
	for _frame in 6:
		await get_tree().process_frame
	var tags: Array = []
	for target: Dictionary in phone.lens.tracker.targets:
		tags.append(str(target.tag))
	check(tags.has("EXAMINER"), "the tracker boxes him in depth (%s)" % ", ".join(tags))
	var material: ShaderMaterial = (phone.lens.depth_quad.mesh as QuadMesh).material
	check(int(material.get_shader_parameter("track_count")) >= 1, "and the shader runs his points hot")
	await _press(JOY_BUTTON_DPAD_UP)
	check(str(phone.lens.mode) == "night", "D-UP again returns to low-light")

	# Walking with it up does not turn pages.
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	await get_tree().process_frame
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	check(phone.page == "CAMERA", "the left stick walks, it does not turn pages")

	await _press(JOY_BUTTON_DPAD_RIGHT)
	check(phone.page == "MAP" and not bool(phone.lens.active), "D-RIGHT goes to MAP and the lens rests")
	await get_tree().create_timer(0.7).timeout
	var handheld = phone.handheld
	check(handheld.is_open and handheld.displayed_mode() == "MAP", "the handheld shows MAP")
	var map = handheld._map
	check(map.visible and map.plan_source == vat.facility_map, "MAP draws the facility plan")
	check(map.plan_feet.distance_to(vat.player.global_position) < 0.01, "with the carrier on it")

	await _press(JOY_BUTTON_DPAD_RIGHT)
	await get_tree().create_timer(0.7).timeout
	check(phone.page == "CARRY" and handheld.displayed_mode() == "CARRY", "D-RIGHT goes to CARRY")
	await _press(JOY_BUTTON_A)
	check(handheld.brain_index_open, "CROSS opens the Brain Index through the head")
	await _press(JOY_BUTTON_A)
	check(not handheld.brain_index_open, "CROSS closes it")
	await _press(JOY_BUTTON_DPAD_RIGHT)
	check(phone.page == "CAMERA" and bool(phone.lens.active) and not handheld.is_open, "D-RIGHT wraps back to the camera")
	await _press(JOY_BUTTON_DPAD_LEFT)
	check(phone.page == "CARRY", "D-LEFT steps back")

	# Hidden pages stay hidden.
	check(handheld.available_modes == ["MAP", "CARRY"], "the facility handheld offers MAP and CARRY only")
	for hidden in BlackMirrorPhone.HIDDEN_PAGES:
		check(not handheld.jump_to_mode(handheld.MODES.find(hidden)), "%s cannot be reached" % hidden)

	await _press(JOY_BUTTON_BACK)
	await get_tree().create_timer(0.5).timeout
	check(not phone.raised and not bool(phone.lens.active) and not handheld.is_open, "CREATE puts it away")
	check(vat.camera.environment == null, "and the naked-eye view comes back")
	check(not bool(vat.sight.phone_lens), "the lens signals go with it")

	print("BLACK_MIRROR_PICKUP_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _press(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _stand_up(vat) -> void:
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


func _place(vat, at: Vector3, look_at_point: Vector3) -> void:
	vat.player.global_position = Vector3(at.x, vat.BODY_HALF_HEIGHT + 0.02, at.z)
	vat.player.velocity = Vector3.ZERO
	var to := look_at_point - Vector3(at.x, vat.BODY_HALF_HEIGHT + 0.7, at.z)
	vat.yaw = atan2(-to.x, -to.z)
	vat.pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.5, 0.5)
	vat.player.rotation.y = vat.yaw
	vat.camera.rotation = Vector3.ZERO
