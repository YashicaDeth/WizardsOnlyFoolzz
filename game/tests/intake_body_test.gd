extends Node

## D7.4 v2. The mirror's wobble used to be four universal constants - every
## character lied the same way regardless of what was actually on the sheet.
## `_mirror_distortion()` now reads race (`build`) and skeleton (rigidity),
## so a plated or dense skeleton barely moves and a hollow one swims, and
## different races land on a different wobble phase.
##
## D8.5 v2. Declining a modifier used to leave no fact anywhere that told
## "chose the hard way" apart from "was never offered" - both looked
## identical once the intake scene ended. `apply_to_world()` now records
## which modifiers were declined, as a real WorldHistory event, the same
## register N2.2 already uses to acknowledge an overspent build.

const VAT_INTAKE := preload("res://systems/vat_intake.gd")
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
	WorldHistory.clear_history()

	print("D7.4 v2 - the mirror's lie fits the body on the sheet")
	var intake: Control = VAT_INTAKE.new()
	add_child(intake)
	await get_tree().process_frame

	intake.sheet.race = "roadborn"
	intake.sheet.under_skin["skeleton"] = "plated"
	var rigid: Dictionary = intake._mirror_distortion()

	intake.sheet.race = "unreset"
	intake.sheet.under_skin["skeleton"] = "hollow"
	var frail: Dictionary = intake._mirror_distortion()

	check(float(rigid.amplitude) < float(frail.amplitude), "a plated skeleton distorts less than a hollow one (%.4f < %.4f)" % [float(rigid.amplitude), float(frail.amplitude)])
	check(float(rigid.phase) != float(frail.phase), "different races land on a different wobble phase, not the same waveform")

	intake.sheet.race = "roadborn"
	intake.sheet.under_skin["skeleton"] = "standard"
	var same_race_a: Dictionary = intake._mirror_distortion()
	var same_race_b: Dictionary = intake._mirror_distortion()
	check(is_equal_approx(float(same_race_a.amplitude), float(same_race_b.amplitude)) and is_equal_approx(float(same_race_a.phase), float(same_race_b.phase)), "the same sheet lies the same way twice - this is not extra randomness")

	print("D8.5 v2 - declining a modifier is a fact the world keeps")
	WorldHistory.clear_history()
	var sheet: CharacterSheet = SHEET.new()
	sheet.display_name = "TEST SUBJECT"
	sheet.modifiers.append("neuralace")
	# mast_tithe and full_schedule left untouched: declined by omission,
	# which is the ordinary path D8.4 already calls the harder road.
	var state: Dictionary = sheet.apply_to_world()
	var declined: Array = state.get("declined_modifiers", [])
	check(declined.has("mast_tithe") and declined.has("full_schedule"), "the sheet itself records which modifiers were declined (%s)" % str(declined))
	check(not declined.has("neuralace"), "and does not count the one actually signed for")

	var found_event := false
	for event: Dictionary in WorldHistory.recent_events(10):
		if str(event.get("type", "")) == "modifiers_declined":
			var details: Dictionary = event.get("details", {})
			if str(details.get("subject", "")) == "player":
				found_event = true
	check(found_event, "and a real event names the player and what they declined, the same way N2.2 acknowledges an overspent build")

	print("INTAKE_BODY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
