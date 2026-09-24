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

	# The drain no longer breaks the glass by itself. It leaves you hanging in
	# the wires under END ALL SUFFERING, and you tear them out yourself.
	opening.clock = opening.DRAINED_AT
	opening._update_sequence(0.05)
	check(opening.phase == "wired", "a drained tank leaves the player hanging in the wires")
	check(opening.title.visible and opening.title.text == "END ALL SUFFERING", "the wired beat opens under END ALL SUFFERING")
	check(opening.umbilicals.size() == 4 and opening.vat_glass.visible, "the wires are still in and the glass still holds")
	var held_clock: float = opening.clock
	var held_line: int = opening.line_index
	opening._physics_process(3.0)
	check(opening.clock == held_clock and opening.line_index == held_line, "the handler's lines wait while the player hangs there")
	check(opening.phase == "wired", "nothing breaks the glass until the player acts")

	var pain_before := float(opening.anatomy.call("snapshot").pain)
	opening._tug_wire(null)
	check(opening.umbilicals.size() == 4, "tugging at nothing pulls nothing out")
	var torn := 0
	while not opening.umbilicals.is_empty() and torn < 8:
		var cable: Node3D = opening.umbilicals[0]
		var link: Node3D = cable.get_child(4)
		var to_link: Vector3 = (link.global_position - opening.camera.global_position).normalized()
		opening.yaw = atan2(-to_link.x, -to_link.z)
		opening.pitch = asin(to_link.y)
		opening._update_wired(0.0)
		check(opening._aimed_wire() == cable, "looking at wire %d aims at it" % torn)
		for tug in opening.WIRE_TUGS - 1:
			opening._tug_wire(opening._aimed_wire())
		check(opening.umbilicals.has(cable), "wire %d holds until the last tug" % torn)
		opening._tug_wire(opening._aimed_wire())
		check(not opening.umbilicals.has(cable), "wire %d tears out on tug %d" % [torn, opening.WIRE_TUGS])
		torn += 1
	check(torn == 4, "all four wires come out, one at a time")
	check(float(opening.anatomy.call("snapshot").pain) > pain_before, "tearing the wires out hurts")
	check(opening.opening_audio.played_cues.has("tug") and opening.opening_audio.played_cues.has("rip"), "tugging and tearing have their own sound events")
	check(opening.title.text == "GET REVENGE" and opening.opening_audio.played_cues.has("revenge"), "the last wire turns the screen to GET REVENGE")
	check(str(WorldHistory.subject("player").get("memory", "")).contains("Tore its own wires out"), "the player's history remembers tearing the wires out")
	check(opening.phase == "wired" and opening.vat_glass.visible, "GET REVENGE holds before the glass goes")
	opening._physics_process(opening.REVENGE_HOLD + 0.1)
	check(opening.phase == "floor" and not opening.vat_glass.visible, "the glass goes after GET REVENGE")
	check(opening.opening_audio.played_cues.has("glass"), "the breach has its own sound event")
	for step in 30:
		opening._physics_process(0.2)
	check(opening.phase == "aisle" and opening.can_move, "the player still gets up and walks the aisle")
	check(not opening.title.visible, "the title clears once the player is on the floor")

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
