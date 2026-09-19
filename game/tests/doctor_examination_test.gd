extends Node

## AX1.1/AX1.2/AX2.1. The examination, checked against the direction doc rather
## than against itself. The load-bearing claim is the last one: the player's
## own answers must survive the institution disagreeing with them.

const SHEET := preload("res://systems/character_sheet.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# Every origin a player can choose is filed as something else.
	for origin in ["decanted", "born", "revived", "grafted", "unknown", "something_unlisted"]:
		var sheet = SHEET.new()
		sheet.race = origin
		var filed := DoctorExamination.classify(sheet)
		check(str(filed.label) != "", "%s is filed as something (%s)" % [origin, filed.label])
		check(str(filed.label) != str(filed.chosen), "%s is not filed as the word the player chose" % origin)
		check(not bool(filed.agrees), "and the record does not pretend to agree with them")

	# The doc's hard line: the diagnosis may be wrong, the choice may not be.
	var kept = SHEET.new()
	kept.race = "born"
	kept.traits = ["clerical_error"]
	var before_race: String = kept.race
	var before_traits: Array = kept.traits.duplicate()
	DoctorExamination.classify(kept)
	DoctorExamination.verdict(kept)
	check(kept.race == before_race, "being classified does not edit what the player chose")
	check(kept.traits == before_traits, "and it does not edit their traits either")

	# AX2.1. The threat has to be specific or it is just a villain line.
	var beats := DoctorExamination.verdict(kept)
	var spoken := ""
	for beat in beats:
		spoken += str(beat.line) + " "
	check(beats.size() >= 4, "the verdict is a sequence of beats, not one line")
	check(spoken.contains("clerical error"), "and it names a trait the player actually picked")
	check(spoken.to_lower().contains("apart"), "and it says what the examination was for")

	# A player who picked nothing still gets a closing.
	var bare = SHEET.new()
	bare.traits = []
	check(DoctorExamination.verdict(bare).size() >= 4, "a player with no traits still gets the verdict")

	# He interjects differently per page, and repeats do not replay line one.
	var first := DoctorExamination.observe("body", 0)
	var second := DoctorExamination.observe("body", 1)
	check(not first.is_empty(), "the doctor has something to say about the body page")
	check(str(first.line) != str(second.line), "and a second visit is not the same line again")
	check(DoctorExamination.observe("nonexistent_page", 0).is_empty(), "an unknown page gets silence, not a crash")

	check(DoctorExamination.CONSENT_NOTICE.contains("CONSENT NOT REQUIRED"), "the recording notice says consent was not required")

	# AX2.6. Killing him has to stay killed.
	WorldHistory.clear_history()
	check(not DoctorExamination.was_killed(), "he starts the run alive")
	check(not bool(DoctorExamination.reconstruct().ok), "a man who was never killed cannot be reconstructed")
	var kill := DoctorExamination.record_kill("blade")
	check(bool(kill.killed), "an apparent kill is recorded as a real one")
	check(str(kill.killed_by) == "player", "and the player gets the credit")
	check(DoctorExamination.was_killed(), "the world agrees he is dead")
	var back := DoctorExamination.reconstruct()
	check(bool(back.ok), "medical reconstruction can bring him back")
	check(bool(back.killed), "and it does NOT undo the kill - the victory stays true")
	check(DoctorExamination.was_killed(), "the world still agrees the player killed him")
	check(bool(back.remembers), "he remembers it")
	check(str(back.scar).contains("throat"), "and he carries the scar the method left (%s)" % back.scar)
	check(not bool(DoctorExamination.reconstruct().ok), "he does not come back twice")

	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
