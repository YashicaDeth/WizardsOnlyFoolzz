extends Node

## Greg, 28 September: beat the examiner in his office and his vehicle bay is
## empty. His car is there, the emitter lies dark, the ramp still opens.

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
	WorldHistory.update_subject("examiner_fight", {"kind": "fight", "status": "won"}, "examiner_beaten")
	var bay = load("res://doctor_vehicle_bay.tscn").instantiate()
	add_child(bay)
	for i in 5:
		await get_tree().physics_frame
	check(bay.empty_bay, "the bay knows he was beaten")
	check(not bay.doctor.visible, "nobody stands by the car")
	check(bay.emitter.visible and is_zero_approx(bay.emitter_light.light_energy), "the emitter lies dark on the floor")
	check(bay.ramp_open, "the ramp is open")
	check("OFFICE FLOOR" in bay.speech.text, "a line says why (%s)" % bay.speech.text)
	for i in 30:
		await get_tree().physics_frame
	check(not bay.doctor_rig.visible, "and he never flickers in")
	bay.queue_free()
	await get_tree().process_frame

	WorldHistory.clear_history()
	var normal = load("res://doctor_vehicle_bay.tscn").instantiate()
	add_child(normal)
	await get_tree().physics_frame
	check(not normal.empty_bay and normal.doctor.visible, "without the fight, he is there as before")
	print("EMPTY_BAY_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
