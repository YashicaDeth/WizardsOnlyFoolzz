extends Node

## Greg, 25 September: speedrunners. After the questionnaire you can speed
## through: F, Enter or Space moves the doctor to his next line, and sends him
## out of his door, without cutting anything. His last line is Greg's.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func press(target, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	target._unhandled_input(key)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var lines := DoctorExamination.VERDICT_CLOSE
	check(str(lines.back().line) == "Okay. Great. We can break you now.", "his last word is Greg's line")
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var intake = vat.intake
	intake.intake_armed = true
	intake._begin_verdict()
	var total: int = intake.verdict.size() + 1
	var said: Array[String] = [str(intake.doctor_says)]
	var frames := 0
	while vat.intake != null and is_instance_valid(intake) and frames < 60:
		press(intake, KEY_F)
		intake._process(1.0 / 60.0)
		if not said.has(str(intake.doctor_says)):
			said.append(str(intake.doctor_says))
		frames += 1
		await get_tree().process_frame
	check(vat.intake == null or not is_instance_valid(intake), "pressing F rushes him through the verdict to filing (%d frames)" % frames)
	check(said.size() >= total, "and every line still plays (%d of %d)" % [said.size(), total])
	check(vat.phase == "departure", "he starts to leave")
	press(vat, KEY_F)
	vat._update_departure(1.0 / 60.0)
	vat._update_departure(1.0 / 60.0)
	check(vat.phase != "departure", "F sends him out of his door at once (phase %s)" % vat.phase)
	check(vat.examiner_door_heard and not vat.examiner_node.visible, "and his door is still heard shutting behind him")
	check(WorldHistory.event_count("opening_departure_skipped") == 1, "the skip is recorded")
	print("SPEEDRUN_INTAKE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
