extends Node

## D3.4 and D8.3. The intake collected everything it needed and was delivered
## by a rota: six lines, five seconds each, in order, no matter what the player
## had just done. These are the checks that it is now directed — that he answers
## the moment, and that signing a socket into your own head is something you
## watch happen rather than a flag being set quietly.

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

	# --- D3.4: delivery answers the moment ----------------------------------
	var idle := IntakeDirection.line_for("idle", 1)
	var slipped := IntakeDirection.line_for("slipped", 1)
	check(str(idle.line) != str(slipped.line), "he does not say the same thing after a mistranscription as when idle")
	check(float(slipped.hold) > float(idle.hold) * 0.7, "and the pause after getting it wrong is a real pause")
	check(float(IntakeDirection.line_for("chose", 0).hold) < float(slipped.hold), "ticking a box is not held as long as ruining your paperwork")
	check(str(IntakeDirection.line_for("idle", 3).line) == str(IntakeDirection.line_for("idle", 3).line), "the same moment plays the same way twice")

	# --- D8.3: every modifier has an authored procedure ----------------------
	for modifier_id in CharacterSheet.MODIFIERS:
		var beats := IntakeDirection.procedure(str(modifier_id), true)
		check(beats.size() >= 2, "%s is a procedure, not a checkbox (%d beats)" % [modifier_id, beats.size()])
		check(IntakeDirection.duration(beats) > 5.0, "%s takes long enough to be done to you" % modifier_id)
		var shots: Array = []
		for beat in beats:
			if not shots.has(str((beat as Dictionary).shot)):
				shots.append(str((beat as Dictionary).shot))
		check(shots.size() > 1, "%s does not sit on one camera the whole way through" % modifier_id)
		check(not IntakeDirection.procedure(str(modifier_id), false).is_empty(), "and refusing %s is its own beat, not silence" % modifier_id)

	# --- the scene actually plays it ----------------------------------------
	var intake: Control = VAT_INTAKE.new()
	add_child(intake)
	await get_tree().process_frame
	intake.page = 4
	intake.row = 0
	var key := str(CharacterSheet.MODIFIERS.keys()[0])
	intake._commit()
	check(intake.sheet.modifiers.has(key), "committing on the schedule page signs you up")
	check(not intake.procedure.is_empty(), "and starts the procedure rather than moving straight on")
	var during := str(intake.handler_says)
	check(during != "", "he is saying something while he does it")

	# Input is suspended for exactly as long as the scene is playing.
	var page_before: int = intake.page
	var event := InputEventKey.new()
	event.keycode = KEY_RIGHT
	event.pressed = true
	intake._unhandled_input(event)
	check(intake.page == page_before, "you cannot page away while it is being done to you")

	# And it hands control back at the end.
	for _step in 40:
		intake._process(0.5)
	check(intake.procedure.is_empty(), "the procedure finishes on its own")
	intake._unhandled_input(event)
	check(intake.page != page_before, "and then you have the form back")

	print("INTAKE_DIRECTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
