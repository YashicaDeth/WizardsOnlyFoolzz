extends Node

## Greg's breakout, in his order (DESIGN/ESCAPE_ROUTES.md, "The opening,
## continued"), driven the way a player does it: the wires, the cord in your
## mouth (E), three blows to the glass (click), down on your knees while the
## implant boots the HUD one piece at a time, SPACE to get up facing his door,
## and only then GET REVENGE.

const VAT := preload("res://vat_chamber.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var vat = VAT.instantiate()
	vat.hands_on_breakout = true
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
	check(vat.phase == "cord" and vat.mouth_cord != null, "with the wires out, the cord in your mouth is left")
	check(WorldHistory.event_count("mission_card_shown") == 1, "GET REVENGE has not come yet (only END ALL SUFFERING)")
	vat._update_hud()
	check(vat.prompt.text.contains("CORD"), "the prompt says to tear the cord out (%s)" % vat.prompt.text)
	for _pull in vat.CORD_TUGS:
		vat._unhandled_input(_key(KEY_E))
	check(vat.phase == "smash" and WorldHistory.event_count("opening_mouth_cord_torn") == 1, "E three times tears the cord out")
	vat._physics_process(5.0)
	check(vat.phase == "smash" and not vat.breakout_complete, "the glass does not break by itself")
	vat._unhandled_input(_click())
	vat._unhandled_input(_click())
	check(vat.vat_glass.visible and vat.glass_cracks.size() > 0, "two blows crack the glass (%d cracks)" % vat.glass_cracks.size())
	vat._unhandled_input(_click())
	check(vat.breakout_complete and not vat.vat_glass.visible, "the third blow goes through")
	check(vat.phase == "knees" and not vat.can_move, "you come out on your knees, not moving yet")
	check(vat.camera.position.y + vat.player.position.y < 1.0, "the eye is down at the puddle")
	check(vat.boot_hud != null and vat.boot_hud.running, "the implant boots the HUD while you're down")
	check(not vat.osd.pieces.vitals and not vat.osd.pieces.prompt, "nothing is on the HUD until the implant puts it there")
	vat._unhandled_input(_key(KEY_SPACE))
	check(vat.phase == "knees", "you can't get up before the HUD is up")
	var order: Array[String] = []
	for _tick in 60:
		vat._physics_process(0.05)
		for piece in ["rec", "vitals", "objective", "prompt"]:
			if vat.boot_hud.revealed(piece) and not order.has(piece):
				order.append(piece)
	check(order == ["rec", "vitals", "objective", "prompt"], "REC, then vitals, then the objective, then the prompt (%s)" % [order])
	check(vat.boot_hud.done and vat.osd.pieces.vitals and vat.osd.pieces.prompt, "the HUD holds once booted")
	check(WorldHistory.event_count("opening_implant_booted") == 1, "the boot is recorded")
	vat._update_hud()
	check(vat.prompt.text.contains("GET UP"), "then SPACE gets you up (%s)" % vat.prompt.text)
	vat._unhandled_input(_key(KEY_SPACE))
	check(vat.phase == "rising", "SPACE starts you up off your knees")
	for _tick in 60:
		if vat.can_move:
			break
		vat._physics_process(0.05)
	check(vat.can_move, "standing, you can move")
	var forward: Vector3 = -vat.camera.global_transform.basis.z
	forward.y = 0.0
	var to_door: Vector3 = DoctorRoute.DOOR_AT - vat.player.global_position
	to_door.y = 0.0
	check(forward.normalized().dot(to_door.normalized()) > 0.95, "you come up looking at his door")
	check(WorldHistory.event_count("mission_card_shown") == 2, "and GET REVENGE flashes")
	check(OpeningDirector.reached("broke_free"), "the opening records the breakout")
	print("HANDS_ON_BREAKOUT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
