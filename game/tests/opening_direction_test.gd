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
	# Filing used to begin decanting on the same frame, with the examiner still
	# at his terminal watching the tank fail. The examination ends first now.
	check(opening.intake == null and opening.phase == "departure", "filing the sheet ends the examination rather than starting the escape")
	check(OpeningDirector.reached("woke"), "the run begins only after the sheet is filed")

	# Drive the departure without waiting on wall-clock: he walks, the staff
	# door shuts behind him, and only then does the vat get its turn.
	var examiner_start: float = opening.examiner_node.position.x
	var door_start: float = opening.staff_door_panel.position.z
	# Comfortably past DEPARTURE_SECONDS: at 1/30 per step, 120 steps is 4.0s
	# and the walk plus the door plus the head coming back is 4.4s.
	for _step in 150:
		opening._update_departure(1.0 / 30.0)
	check(opening.examiner_node.position.x > examiner_start + 3.0, "the examiner walks to his own door instead of standing there")
	check(not opening.examiner_node.visible, "and is gone through it before the tank goes")
	check(absf(opening.staff_door_panel.position.z - opening.STAFF_DOOR_AT.z) < 0.01 and not is_equal_approx(door_start, opening.STAFF_DOOR_AT.z), "the staff door closes behind him")
	check(opening.phase == "submerged", "decanting begins only once he has left")
	check(opening.get_node("HUD/Objective").text == "", "no escape objective while the man who filed you is still in the room")

	opening.clock = 3.25
	opening._update_sequence(0.05)
	check(opening.phase == "voiding", "the directed camera reaches the voiding beat")
	check(opening.opening_audio.played_cues.has("drain"), "voiding has its own sound event")

	# The drain does not break the glass by itself. It leaves the body hanging
	# in the wires under END ALL SUFFERING, and the player tears them out.
	opening.clock = opening.DRAINED_AT
	opening._update_sequence(0.05)
	check(opening.phase == "wired", "a drained tank leaves the player hanging in the wires")
	check(opening.title.visible and opening.title.text == "END ALL SUFFERING", "the wired beat opens under END ALL SUFFERING")
	check(opening.umbilicals.size() == 4 and opening.vat_glass.visible and not opening.breakout_complete, "the wires are still in and the glass still holds")
	var held_clock: float = opening.clock
	opening._physics_process(3.0)
	check(opening.clock == held_clock and opening.phase == "wired", "nothing moves on until the player acts")
	var pain_before := float(opening.anatomy.call("snapshot").pain)
	opening._tug_wire(null)
	check(opening.umbilicals.size() == 4, "tugging at nothing pulls nothing out")
	var first: Node3D = opening.umbilicals[0]
	var aim: Vector3 = ((first.get_child(3) as Node3D).global_position - opening.camera.global_position).normalized()
	opening.yaw = atan2(-aim.x, -aim.z)
	opening.pitch = asin(aim.y)
	opening._update_wired(0.0)
	check(opening._aimed_wire() == first, "looking at a wire aims at it")
	opening._tug_wire(first)
	opening._tug_wire(first)
	check(opening.umbilicals.has(first), "a wire holds until the last tug")
	check(_tear_all_wires(opening) == 4 and opening.umbilicals.is_empty(), "all four wires come out, one at a time")
	check(float(opening.anatomy.call("snapshot").pain) > pain_before, "tearing the wires out hurts")
	check(opening.opening_audio.played_cues.has("tug") and opening.opening_audio.played_cues.has("rip"), "tugging and tearing have their own sound events")
	check(opening.title.text == "GET REVENGE" and opening.opening_audio.played_cues.has("revenge"), "the last wire turns the screen to GET REVENGE")
	check(opening.vat_glass.visible and not opening.breakout_complete, "GET REVENGE holds before the glass goes")
	opening._physics_process(opening.REVENGE_HOLD + 0.1)
	check(opening.phase == "floor" and not opening.vat_glass.visible, "the glass goes after GET REVENGE")
	check(opening.opening_audio.played_cues.has("glass"), "the breach has its own sound event")
	check(opening.breakout_complete and opening.first_acquisition_complete, "the soul/implant breakout completes instead of stalling in the vat")
	check(OpeningDirector.reached("broke_free"), "breakout is persisted as an opening stage")
	var carried: Array = WorldHistory.subject("inventory").get("items", [])
	check(carried.any(func(item): return str((item as Dictionary).get("label", "")).contains("MEDICAL RESTRAINT")), "the first physical acquisition uses the shared inventory")
	check(str(WorldHistory.subject("player").get("status", "")) == "broke free", "the player's body and history record the breakout")

	# K3.2. The opening reframed: CellOutz grew you, which is why the debt is
	# in the meat. Checked as real scene content, not just prose in a design doc.
	# The line is still said by the same man for the same reason; he says it on
	# his way out now, which is the only stretch where he is still in the room.
	# Searched across both tables so where it lives stays an authoring choice
	# and what it has to say stays the contract.
	var beat_texts: Array = opening.BEATS.map(func(beat): return str(beat.text))
	var spoken: Array = beat_texts + opening.DEPARTURE_BEATS.map(func(beat): return str(beat.text))
	var celloutz_line := spoken.filter(func(text): return text.contains("CellOutz"))
	check(not celloutz_line.is_empty(), "the examiner's own dialogue names CellOutz as the one who grew you")
	check(celloutz_line[0].contains("owns what it grew"), "and ties that directly to ownership of the debt")
	check(celloutz_line[0].contains("Debt's in the meat"), "debt and ownership land as one comprehensible attributed beat")
	# There used to be a beat that printed OBJECTIVE // ESCAPE THE FACILITY as a
	# centred subtitle while HUD/Objective printed the same six words in the
	# corner. One objective, one place -- so the contract is now that no spoken
	# beat claims it and the HUD label is the only thing that does.
	check(spoken.filter(func(text): return text.contains("OBJECTIVE")).is_empty(), "no subtitle beat duplicates the objective the HUD already shows")
	opening.clock = 8.81
	opening.phase = "floor"
	opening._update_sequence(0.05)
	check(opening.can_move, "normal control arrives in under nine seconds after filing")
	opening._update_hud()
	check(opening.get_node("HUD/Objective").text.contains("ESCAPE THE FACILITY"), "the escape objective remains legible when control arrives")

	# The resume ladder, walked in order. Nothing covered this, and it is where
	# inserting the Service Arcade went wrong: the vat door advanced straight to
	# `entered_pit` while travelling to the arcade, so stepping into the new
	# area and quitting resumed you in the colosseum with the arcade skipped
	# entirely. Every test passed, because each half was correct on its own.
	check(str(OpeningDirector.resume_destination().scene) == "res://vat_chamber.tscn", "a run that has not left the tank resumes in the tank")
	OpeningDirector.advance("entered_arcade")
	check(str(OpeningDirector.resume_destination().scene) == "res://service_arcade.tscn", "a run that reached the arcade resumes in the arcade, not past it")
	check(Interstitial.STAGE_ON_ARRIVAL.get("res://service_arcade.tscn", "") == "entered_arcade", "arriving at the arcade records the arcade, whichever route got there")
	OpeningDirector.advance("entered_lower_works")
	check(str(OpeningDirector.resume_destination().scene) == "res://buried_city.tscn", "a run inside the Lower Works resumes at its lift objective, not past it")
	check(Interstitial.STAGE_ON_ARRIVAL.get("res://buried_city.tscn", "") == "entered_lower_works", "arriving at the Lower Works records its distinct escape beat")
	OpeningDirector.advance("entered_pit")
	check(str(OpeningDirector.resume_destination().scene) == "res://underground_colosseum.tscn", "an unfinished heat resumes in the real underground colosseum")
	OpeningDirector.advance("won_derby")
	check(str(OpeningDirector.resume_destination().scene) == "res://bone_yard_hunt.tscn", "a won heat resumes beyond the derby instead of replaying it")

	print("OPENING_DIRECTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Aims the real camera at each umbilical and pulls it the way a player does.
func _tear_all_wires(vat) -> int:
	var torn := 0
	while not vat.umbilicals.is_empty() and torn < 8:
		var cable: Node3D = vat.umbilicals[0]
		var link: Node3D = cable.get_child(3)
		var to_link: Vector3 = (link.global_position - vat.camera.global_position).normalized()
		vat.yaw = atan2(-to_link.x, -to_link.z)
		vat.pitch = asin(to_link.y)
		vat._update_wired(0.0)
		for tug in vat.WIRE_TUGS:
			vat._tug_wire(vat._aimed_wire())
		torn += 1
	return torn
