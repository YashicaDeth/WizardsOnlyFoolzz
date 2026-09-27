extends Node

## Greg, 26 September: the examiner fight in his office. Played in the real
## vat room: out of the tank, his door down, into his room. He notices you,
## cuts you, the syringe slows you; you beat him and take his keycard and
## coat, and the keycard opens the staff door on his cupboard. Then a second
## world where he wins: you go back to the vat and he keeps the coat.

const VAT := preload("res://vat_chamber.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func stand_up(vat) -> void:
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
	for _step in 80:
		if vat.can_move:
			break
		vat._physics_process(0.1)
	await get_tree().physics_frame


func place(vat, at: Vector3, look_at_point: Vector3) -> void:
	vat.player.global_position = Vector3(at.x, vat.BODY_HALF_HEIGHT + 0.02, at.z)
	var to := look_at_point - at
	vat.yaw = atan2(-to.x, -to.z)
	vat.pitch = 0.0
	vat.player.rotation.y = vat.yaw
	vat.camera.rotation = Vector3(0, 0, 0)


func click(vat) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	vat._unhandled_input(event)


func open_door(vat, route) -> void:
	route.door.hit("axe", route.DOOR_AT + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
	var blows := 0
	while not route.door.broken and blows < 80:
		route.door.hit("axe", route.DOOR_AT + Vector3(0, 1.2, 0), Vector3(0, 0, 1))
		blows += 1
	await get_tree().physics_frame


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	await _win_world()
	await _lose_world()
	print("EXAMINER_FIGHT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _win_world() -> void:
	WorldHistory.clear_history()
	var vat = VAT.instantiate()
	add_child(vat)
	await get_tree().process_frame
	await stand_up(vat)
	check(vat.can_move, "out of the vat and standing")
	var route = vat.doctor_route
	var fight = route.fight
	check(fight != null and fight.state == "idle", "he is in his office, at his bench, back turned")
	var mask: Node3D = fight.body.parts["head"].get_node("SurgicalMask")
	await open_door(vat, route)
	check(route.door.broken, "his door is down")

	# Walk in close: he notices, turns, pulls his mask up.
	place(vat, fight.global_position + Vector3(1.8, 0, 0), fight.global_position)
	for i in 10:
		await get_tree().physics_frame
	check(fight.state in ["noticed", "fighting"], "he notices you in his room (%s)" % fight.state)
	check(mask.position.y > -0.1, "and pulls his surgical mask up")
	for i in 120:
		await get_tree().physics_frame
		if fight.state == "fighting":
			break
	check(fight.state == "fighting", "then he comes at you")

	# Stand in reach and let him work.
	var blood_before: float = vat.anatomy.blood_remaining
	for i in 400:
		place(vat, fight.global_position + Vector3(1.0, 0, 0), fight.global_position)
		await get_tree().physics_frame
		if fight.attacks_made >= 3 and fight.winding == "":
			break
	check(fight.hits_taken >= 2, "the scalpel lands (%d)" % fight.hits_taken)
	check(vat.anatomy.blood_remaining < blood_before, "and you bleed for it (%.0f -> %.0f)" % [blood_before, vat.anatomy.blood_remaining])
	check(vat.slowed_left > 0.0, "the syringe (every third) slows you (%.1f s left)" % vat.slowed_left)
	check(WorldHistory.event_count("examiner_fight_wound") >= 3, "every wound is on the record")
	check(fight.state == "fighting", "you are still standing")

	# Now hit him. Keep your blood up so this is about your blows.
	var clicks := 0
	while fight.state != "won" and clicks < 40:
		vat.anatomy.blood_remaining = vat.anatomy.blood_capacity
		place(vat, fight.global_position + Vector3(1.1, 0, 0), fight.global_position + Vector3(0, 1.2, 0))
		route.cooldown = 0.0
		click(vat)
		clicks += 1
		for i in 3:
			await get_tree().physics_frame
	check(fight.state == "won", "he goes down (%d blows)" % clicks)
	check(VatRebirth.carries(fight.KEYCARD), "his keycard is yours")
	check(Clothing.worn("player") == "examiner_coat", "and you are wearing his coat")
	check(str(WorldHistory.subject("examiner_fight").get("status", "")) == "won", "the world remembers you beat him")
	for i in 60:
		await get_tree().physics_frame
	check(fight.body.rotation.x < -1.0, "he is on the floor")

	# His keycard opens the staff door, on his cupboard.
	place(vat, vat.STAFF_DOOR_AT + Vector3(-1.2, 0, 0), vat.STAFF_DOOR_AT)
	vat._update_prompt() if vat.has_method("_update_prompt") else null
	vat._interact()
	check(vat.staff_door_open, "the keycard opens the staff door")
	var meds_before := FieldMeds.count()
	vat._interact()
	check(FieldMeds.count() == meds_before + 2, "his cupboard: two field dressings")
	vat._interact()
	check(FieldMeds.count() == meds_before + 2, "taken once")
	vat.queue_free()
	await get_tree().physics_frame


func _lose_world() -> void:
	WorldHistory.clear_history()
	var vat = VAT.instantiate()
	add_child(vat)
	await get_tree().process_frame
	await stand_up(vat)
	var route = vat.doctor_route
	var fight = route.fight
	await open_door(vat, route)
	place(vat, fight.global_position + Vector3(1.0, 0, 0), fight.global_position)
	for i in 2400:
		place(vat, fight.global_position + Vector3(1.0, 0, 0), fight.global_position)
		await get_tree().physics_frame
		if fight.state == "lost":
			break
	check(fight.state == "lost", "stand there and he puts you down (%d cuts)" % fight.hits_taken)
	check(VatRebirth.is_pending(), "back to the vat")
	check(str(WorldHistory.subject("examiner_fight").get("coat", "")) == "examiner", "and he keeps his coat")
	check(Clothing.worn("player") != "examiner_coat", "you are not wearing it")
	vat.queue_free()
	await get_tree().physics_frame
