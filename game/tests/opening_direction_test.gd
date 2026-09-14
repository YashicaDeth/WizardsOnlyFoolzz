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

	# K3.2. The opening reframed: CellOutz grew you, which is why the debt is
	# in the meat. Checked as real scene content, not just prose in a design doc.
	var beat_texts: Array = opening.BEATS.map(func(beat): return str(beat.text))
	var celloutz_line := beat_texts.filter(func(text): return text.contains("CellOutz"))
	check(not celloutz_line.is_empty(), "the handler's own dialogue names CellOutz as the one who grew you")
	check(celloutz_line[0].contains("owns what it grew"), "and ties that directly to ownership of the debt")
	var debt_index := -1
	var celloutz_index := -1
	for index in opening.BEATS.size():
		var text := str(opening.BEATS[index].text)
		if text.contains("Debt's in the meat"):
			debt_index = index
		if text.contains("CellOutz"):
			celloutz_index = index
	check(celloutz_index == debt_index + 1, "the reframe lands as the very next beat after the debt line, not buried elsewhere")

	OpeningDirector.advance("entered_pit")
	check(str(OpeningDirector.resume_destination().scene) == "res://rift_derby.tscn", "an unfinished heat resumes at the real derby")
	OpeningDirector.advance("won_derby")
	check(str(OpeningDirector.resume_destination().scene) == "res://bone_yard_hunt.tscn", "a won heat resumes beyond the derby instead of replaying it")

	print("OPENING_DIRECTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
