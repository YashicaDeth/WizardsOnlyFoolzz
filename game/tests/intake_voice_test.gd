extends Node

## Greg, 26 September: speak the intake's answers aloud with V (optional;
## typing and the keys still work). The words arrive as Vosk would hand them
## (`_think`), and the form acts on them like its keys.

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

	var start_page: int = intake.page
	intake._think("next page")
	check(intake.page == (start_page + 1) % intake.PAGES.size(), "\"next page\" turns the page")
	intake._think("back")
	check(intake.page == start_page, "\"back\" turns it back")
	intake._think("two")
	check(intake.touched_pages.has(start_page) and intake.row == 1, "\"two\" picks the second row and confirms it")
	intake.answers = ["YES", "NO", "STARE"]
	intake._think("no")
	check(intake.answers.is_empty(), "a spoken answer to his question is taken like its key")
	intake.answers = ["YES", "NO", "STARE"]
	intake._think("the third one I guess three")
	check(intake.answers.is_empty(), "a number said inside a sentence picks his option")
	intake._think("I don't want to be here")
	check(str(intake.thought) == "I don't want to be here", "anything else is a thought, as before")
	intake._think("file it")
	check(intake.transcript.begins_with("STILL TO CONFIRM") or intake.verdict_started, "\"file it\" files, or says what is still to confirm")

	print("INTAKE_VOICE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
