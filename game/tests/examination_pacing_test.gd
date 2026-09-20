extends Node

## AX1.5. The direction doc asks for "roughly 10-15 minutes" on a deliberate
## first pass. That is a claim about a person at a keyboard and a suite cannot
## assert it -- what a suite CAN do is measure the authored floor: how long the
## scripted beats alone take, before the player has decided anything.
##
## If the floor is longer than the target, the scene is over-written and no
## player can come in under it. If it is a tiny fraction, the target rests
## entirely on deliberation and the pacing claim is really about how many
## decisions are on offer. Either answer is worth knowing before somebody
## writes "10-15 minutes" into a checklist tick.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# The doctor's authored beats: every observation plus the closing verdict.
	var doctor_seconds := 0.0
	for context in DoctorExamination.OBSERVATIONS.keys():
		for beat in DoctorExamination.OBSERVATIONS[context]:
			doctor_seconds += float(beat.hold)
	for beat in DoctorExamination.VERDICT_CLOSE:
		doctor_seconds += float(beat.hold)

	# The handler's, from his own direction table.
	var handler_seconds := 0.0
	for context in IntakeDirection.LINES.keys():
		for beat in IntakeDirection.LINES[context]:
			handler_seconds += float(beat.get("hold", 2.6))

	var floor_seconds := doctor_seconds + handler_seconds
	print("AUTHORED FLOOR // doctor %.0fs // handler %.0fs // total %.1f min" % [doctor_seconds, handler_seconds, floor_seconds / 60.0])

	check(doctor_seconds > 0.0, "the doctor has authored beats to spend (%.0fs)" % doctor_seconds)
	check(handler_seconds > 0.0, "and so does the handler (%.0fs)" % handler_seconds)
	# The floor must leave room for the player. If the script alone eats the
	# budget, nobody can make a considered choice inside it.
	check(floor_seconds < 10.0 * 60.0, "the authored beats alone stay under the 10 minute floor (%.1f min)" % (floor_seconds / 60.0))
	check(DoctorExamination.VERDICT_CLOSE.size() >= 4, "the closing is long enough to land (%d beats)" % DoctorExamination.VERDICT_CLOSE.size())

	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
