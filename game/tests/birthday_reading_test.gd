extends Node

## Greg, 25 September: "you tell them your birthday, so he tells you
## information about your birth". Typed or said, the date goes on the sheet
## and he reads the chart back.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var a := CharacterSheet.parse_birth("11 1 2007")
	check(a.get("day") == 11 and a.get("month") == 1 and a.get("year") == 2007 and not a.get("time_known"), "11 1 2007 (%s)" % str(a))
	var b := CharacterSheet.parse_birth("the 3rd of March 1994 at 7:45pm")
	check(b.get("day") == 3 and b.get("month") == 3 and b.get("year") == 1994 and b.get("hour") == 19 and b.get("minute") == 45, "the 3rd of March 1994 at 7:45pm (%s)" % str(b))
	var c := CharacterSheet.parse_birth("11/01/2007 2:30am")
	check(c.get("hour") == 2 and c.get("minute") == 30, "11/01/2007 2:30am (%s)" % str(c))
	check(CharacterSheet.parse_birth("let me out").is_empty(), "a thought is not a birthday")
	check(CharacterSheet.parse_birth("31 2 2000").is_empty(), "there is no 31st of February")
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var intake = vat.intake
	intake.intake_armed = true
	intake.opening_active = false
	check(intake.PAGES.has("BIRTH"), "the form has a BIRTH page")
	intake._think("3 March 1994 7:45pm")
	check(int(intake.sheet.birth.day) == 3 and int(intake.sheet.birth.hour) == 19, "what you told him is on the sheet")
	check(intake.touched_pages.has(intake.BIRTH_PAGE), "and it confirms the page")
	var said: Array[String] = []
	for i in 1200:
		intake._process(0.05)
		if intake.doctor_life > 0.0 and not said.has(str(intake.doctor_says)):
			said.append(str(intake.doctor_says))
		if not intake.opening_active and intake.opening_lines.is_empty() and said.size() > 3:
			break
	check(said.has(str(DoctorExamination.READS_THOUGHTS.line)), "he tells you he read it")
	check(said.any(func(l): return l.begins_with("The 3rd of March, 1994")), "he reads the date back (%s)" % str(said))
	check(said.any(func(l): return l.begins_with("Sun in Pisces")), "and the chart")
	check(said.has("Everything I need to know."), "and closes with Greg's promise")
	check(WorldHistory.event_count("birthday_given") == 1 and WorldHistory.event_count("examiner_read_chart") == 1, "both go on the record")
	print("BIRTHDAY_READING_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
