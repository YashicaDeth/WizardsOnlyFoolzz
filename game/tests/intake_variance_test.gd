extends Node

## D3.5 v2. `_speak()` indexed every line pool with `handler_line %
## pool.size()`, and `handler_line` always started at zero - so the first
## idle line was the same line every single decanting, then the same second
## line, forever, in the same order. `line_offset` (rolled once per scene in
## `_ready()`) breaks that while keeping `IntakeDirection.line_for()` itself
## exactly as deterministic as `intake_direction_test.gd` already proved it
## is - the offset changes *which* line a given moment lands on, not whether
## the same moment plays the same way twice.
##
## D4.6 v2. Picking a race now gets a reaction that names the race, not the
## same "Fine. That's what I'll put." every other row on the form gets.

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

	print("D3.5 v2 - two decantings do not hear the handler in the same order")
	var first: Control = VAT_INTAKE.new()
	add_child(first)
	await get_tree().process_frame
	var second: Control = VAT_INTAKE.new()
	add_child(second)
	await get_tree().process_frame

	# The offset is what varies decanting to decanting; pin two different
	# values directly rather than trusting two calls to randomize() to land
	# on different numbers, which is true in practice but not guaranteed.
	first.line_offset = 4
	first.handler_line = 0
	first._speak("idle")
	second.line_offset = 71
	second.handler_line = 0
	second._speak("idle")
	check(first.handler_says != second.handler_says, "the very first idle line differs between two decantings with different offsets")

	# Determinism within one sitting is not lost: the same moment (same
	# handler_line, same offset) still plays the same line every time -
	# this is IntakeDirection.line_for()'s own contract, which the offset
	# must not break.
	first.handler_line = 0
	first._speak("idle")
	var replay := str(first.handler_says)
	first.handler_line = 0
	first._speak("idle")
	check(str(first.handler_says) == replay, "the same moment in the same decanting still plays the same way twice")

	print("D4.6 v2 - the intake reacts to the race you actually picked")
	var intake: Control = VAT_INTAKE.new()
	add_child(intake)
	await get_tree().process_frame
	intake.page = 1
	var reactions: Array = []
	for row_index in CharacterSheet.RACES.size():
		intake.row = row_index
		intake._commit()
		reactions.append(str(intake.handler_says))
	var unique: Array = []
	for line: String in reactions:
		if not unique.has(line):
			unique.append(line)
	check(unique.size() >= CharacterSheet.RACES.size() - 1, "most races get a genuinely different reaction, not the same generic line (%d/%d unique)" % [unique.size(), CharacterSheet.RACES.size()])
	var race_names: Array = []
	for key in CharacterSheet.RACES:
		race_names.append(str((CharacterSheet.RACES[key] as Dictionary).name))
	var generic_only := true
	for line: String in reactions:
		if line != "Noted." and line != "Fine. That's what I'll put.":
			generic_only = false
	check(not generic_only, "at least some of those reactions are the race-specific ones, not the fallback \"noted\"")

	print("INTAKE_VARIANCE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
