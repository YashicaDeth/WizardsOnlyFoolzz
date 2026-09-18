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

	opening.clock = 3.25
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
	check(celloutz_line[0].contains("Debt's in the meat"), "debt and ownership land as one comprehensible attributed beat")
	check(beat_texts.back() == "OBJECTIVE  //  ESCAPE THE FACILITY", "the last opening beat states the first objective plainly")
	opening.clock = 8.81
	opening.phase = "floor"
	opening._update_sequence(0.05)
	check(opening.can_move, "normal control arrives in under nine seconds after filing")

	OpeningDirector.advance("entered_pit")
	check(str(OpeningDirector.resume_destination().scene) == "res://underground_colosseum.tscn", "an unfinished heat resumes in the real underground colosseum")
	OpeningDirector.advance("won_derby")
	check(str(OpeningDirector.resume_destination().scene) == "res://bone_yard_hunt.tscn", "a won heat resumes beyond the derby instead of replaying it")

	print("OPENING_DIRECTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
