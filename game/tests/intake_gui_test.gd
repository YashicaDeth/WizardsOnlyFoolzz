extends Node

## The intake GUI pass (Greg, 24 September): tabs print in, his earlier lines
## stay above as a transcript, and the stat gauges flash what a choice changed.

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
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var intake = vat.intake
	intake._process(0.1)
	intake.page = 2
	intake._process(0.05)
	check(intake.page_print < 0.2, "switching tab starts the page printing out")
	intake._process(intake.PRINT_SECONDS)
	check(is_equal_approx(intake.page_print, 1.0), "and it has printed in under a second")
	intake.handler_says = "First."
	intake._process(0.05)
	intake.handler_says = "Second."
	intake._process(0.05)
	intake.handler_says = "Third."
	intake._process(0.05)
	intake.handler_says = "Fourth."
	intake._process(0.05)
	check(intake.said_history.size() == intake.HISTORY_LINES and intake.said_history.back() == "Third.", "his last lines stay above the current one, oldest dropped")
	intake.sheet.race = "roadborn" if intake.sheet.race != "roadborn" else "soft_rot"
	intake._process(0.05)
	var flashed := false
	for key in CharacterSheet.ATTRIBUTES:
		flashed = flashed or float(intake._gauge_flash.get(key, 0.0)) > 0.0
	check(flashed, "a choice that moves a stat flashes its change on the gauge")
	print("INTAKE_GUI_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
