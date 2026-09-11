extends Node

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
	var opening = load("res://vat_chamber.tscn").instantiate()
	add_child(opening)
	await get_tree().process_frame
	check(opening.phase == "intake", "the handler and sheet are the first playable beat")
	check(opening.intake != null, "character creation is reachable from a new run")
	check(opening.clock == 0.0, "the decanting camera does not run behind the form")
	check(opening.opening_audio.room.playing and opening.opening_audio.pulse.playing, "the Growing Floor has room and body ambience")

	opening.intake.filed.emit({"race": "decanted"})
	await get_tree().process_frame
	check(opening.intake == null and opening.phase == "submerged", "filing the sheet begins decanting")
	check(OpeningDirector.reached("woke"), "the run begins only after the sheet is filed")

	opening.clock = 5.25
	opening._update_sequence(0.05)
	check(opening.phase == "voiding", "the directed camera reaches the voiding beat")
	check(opening.opening_audio.played_cues.has("drain"), "voiding has its own sound event")
	opening._breach()
	check(opening.opening_audio.played_cues.has("glass"), "the breach has its own sound event")

	print("OPENING_DIRECTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
