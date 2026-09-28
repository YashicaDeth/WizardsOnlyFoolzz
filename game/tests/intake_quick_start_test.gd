extends Node

## Greg, 28 September: a quick start for friends. PRESET (the first row of
## the first page) fills every page with one fixed strong default when no
## character is saved, and he files you straight on.

const VAT_INTAKE := preload("res://systems/vat_intake.gd")

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
	var intake = VAT_INTAKE.new()
	add_child(intake)
	await get_tree().process_frame
	intake.intake_armed = true
	intake.procedure = []
	intake.page = 0
	intake.row = 0
	intake._commit()
	check(intake.touched_pages.size() == intake.PAGES.size(), "every page is filled")
	check(intake.sheet.race != "", "with a real character (%s)" % intake.sheet.race)
	check(intake.verdict_started, "and he goes straight to his verdict")
	var first_race: String = intake.sheet.race
	intake.queue_free()
	await get_tree().process_frame

	var again = VAT_INTAKE.new()
	add_child(again)
	await get_tree().process_frame
	again.intake_armed = true
	again.procedure = []
	again.page = 0
	again.row = 0
	again._commit()
	check(again.sheet.race == first_race, "the quick start is the same character every time")

	print("INTAKE_QUICK_START_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
