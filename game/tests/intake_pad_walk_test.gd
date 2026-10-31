extends Node

## intake-29 (Greg, 4 Oct, on the pad: "this entire section needs to be
## reworked so that it works for controller keys"). The whole NEURAL INTAKE
## walked with joypad events only, through the real input path: every tab by
## bumper, trigger or d-pad, rows by d-pad and stick, Cross to change a row,
## Square to keep a page as is, Circle back, the birthday and a new name
## spelled on the pad keyboard, R3 with no mic opening the think-out-loud
## presets, Options to file, Cross through his closing lines, and the vat
## opening reached with the route that was chosen. Every on-screen key hint
## is checked to name pad buttons, not keys. No key or mouse event is sent.

const VAT := preload("res://vat_chamber.tscn")
const SPEED := 3.0

var failures: Array[String] = []
var vat
var intake
var keys_sent := 0


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func finish() -> void:
	Engine.time_scale = 1.0
	BrainScreen.force_in_tests = false
	print("INTAKE_PAD_WALK_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		keys_sent += 1


func press(index: JoyButton, held := false) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if held:
		return
	var up := InputEventJoypadButton.new()
	up.device = 0
	up.button_index = index
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()


func axis(which: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = which
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


## His question takes Cross/Square/Triangle first (as on screen), so a player
## answers him before going back to the form. So does this test.
func answer_him() -> void:
	var guard := 0
	while not intake.answers.is_empty() and guard < 4:
		guard += 1
		press(JOY_BUTTON_A)


func wait_for(done: Callable, seconds: float, each := Callable()) -> bool:
	var waited := 0.0
	var since := 0.0
	while waited < seconds:
		if done.call():
			return true
		await get_tree().process_frame
		waited += get_process_delta_time()
		since += get_process_delta_time()
		if each.is_valid() and since >= 0.3:
			since = 0.0
			each.call()
	return done.call()


## Spell `text` on the open pad keyboard by walking the cursor with the d-pad
## and pressing Cross on each key, then Options to submit.
func spell(text: String) -> bool:
	var board = intake.pad_keyboard
	if board == null or not is_instance_valid(board):
		return false
	for character in text:
		var target := Vector2i(-1, -1)
		var rows: Array = board.rows()
		for y in rows.size():
			var row: Array = rows[y]
			if board.presets.size() > 0 and y == 0:
				continue
			var x := row.find(character if character != " " else "SPACE")
			if x >= 0:
				target = Vector2i(x, y)
				break
		if target.x < 0:
			return false
		var guard := 0
		while board.cursor.y != target.y and guard < 12:
			guard += 1
			press(JOY_BUTTON_DPAD_DOWN if board.cursor.y < target.y else JOY_BUTTON_DPAD_UP)
		guard = 0
		while board.cursor.x != target.x and guard < 12:
			guard += 1
			press(JOY_BUTTON_DPAD_RIGHT if board.cursor.x < target.x else JOY_BUTTON_DPAD_LEFT)
		press(JOY_BUTTON_A)
	press(JOY_BUTTON_START)
	return true


func goto_page(wanted: int) -> void:
	var guard := 0
	while intake.page != wanted and guard < 10:
		guard += 1
		answer_him()
		press(JOY_BUTTON_RIGHT_SHOULDER)


func goto_row(wanted: int) -> void:
	var guard := 0
	while intake.row != wanted and guard < 12:
		guard += 1
		press(JOY_BUTTON_DPAD_DOWN if intake.row < wanted else JOY_BUTTON_DPAD_UP)


## No keyboard words in any hint the form draws while the pad is in use.
func hints_are_pad_only(label: String) -> void:
	var texts: Array[String] = []
	for chip: Array in intake.control_chips():
		texts.append(str(chip[0]))
	texts.append(intake._hint_key("SPACE", JOY_BUTTON_X))
	texts.append(intake._hint_key("ENTER", JOY_BUTTON_A))
	texts.append(intake._hint_key("V", intake.TALK_BUTTON))
	var joined := " | ".join(texts)
	var clean := true
	for word in ["SPACE", "ENTER", "CLICK", "ESC", " V", "[V]"]:
		if joined.contains(word):
			clean = false
	check(clean and joined.contains("CROSS"), "%s: hints name pad buttons (%s)" % [label, joined])


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	BrainScreen.force_in_tests = true
	vat = VAT.instantiate()
	get_tree().root.add_child.call_deferred(vat)
	await get_tree().process_frame
	get_tree().current_scene = vat
	await get_tree().process_frame
	Engine.time_scale = SPEED
	check(await wait_for(func() -> bool: return vat.intake != null and vat.intake.intake_armed, 20.0), "the form arms")
	intake = vat.intake
	# Any pad event marks the pad as the device in use (InputProfile).
	axis(JOY_AXIS_LEFT_Y, 0.0)
	press(JOY_BUTTON_DPAD_UP)
	check(InputProfile.using_pad, "a pad press puts the form in pad mode")
	hints_are_pad_only("ROUTE page")
	check(not intake.control_chips().is_empty(), "the control strip lists the pad's controls")

	print("-- ROUTE: d-pad to INSTRUMENT, Cross --")
	answer_him()
	goto_row(3)
	check(intake.row == 3, "the d-pad walks down to INSTRUMENT")
	answer_him()
	press(JOY_BUTTON_A)
	check(intake.sheet.route == "instrument" and intake.touched_pages.has(0), "Cross takes the INSTRUMENT route (%s)" % intake.sheet.route)

	print("-- RACE: R1, stick down, Cross --")
	answer_him()
	press(JOY_BUTTON_RIGHT_SHOULDER)
	check(intake.page == 1, "R1 turns to RACE")
	axis(JOY_AXIS_LEFT_Y, 1.0)
	axis(JOY_AXIS_LEFT_Y, 0.0)
	check(intake.row == 1, "a stick flick moves one row")
	answer_him()
	press(JOY_BUTTON_A)
	var race_id := str(CharacterSheet.RACES.keys()[1])
	check(intake.sheet.race == race_id and intake.touched_pages.has(1), "Cross picks the second race (%s)" % intake.sheet.race)

	print("-- TRAITS: R2 trigger, Square keeps it as is --")
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(intake.page == 2, "R2 turns to TRAITS")
	answer_him()
	press(JOY_BUTTON_X)
	check(intake.touched_pages.has(2), "Square confirms TRAITS as is")

	print("-- FACE: d-pad right turns the dial --")
	answer_him()
	press(JOY_BUTTON_DPAD_RIGHT)
	check(intake.page == 3, "on a list page d-pad right turns the tab (TRAITS -> FACE)")
	goto_page(3)
	var face_before: Dictionary = intake.sheet.face.duplicate()
	answer_him()
	press(JOY_BUTTON_DPAD_RIGHT)
	check(intake.page == 3 and intake.sheet.face != face_before and intake.touched_pages.has(3), "d-pad right on FACE turns the first dial, not the tab")

	print("-- BODY: stick right turns BLOOD --")
	answer_him()
	press(JOY_BUTTON_RIGHT_SHOULDER)
	check(intake.page == 4, "R1 turns to BODY")
	goto_row(1)
	var blood_before := str(intake.sheet.under_skin.get("blood", "O-RUST"))
	axis(JOY_AXIS_LEFT_X, 1.0)
	axis(JOY_AXIS_LEFT_X, 0.0)
	check(str(intake.sheet.under_skin.get("blood", "")) != blood_before and intake.touched_pages.has(4), "the stick sideways cycles BLOOD (%s)" % intake.sheet.under_skin.get("blood", ""))

	print("-- BIRTH: Cross opens the pad keyboard, spelled with the d-pad --")
	answer_him()
	press(JOY_BUTTON_RIGHT_SHOULDER)
	check(intake.page == intake.BIRTH_PAGE, "R1 turns to BIRTH")
	answer_him()
	press(JOY_BUTTON_A)
	check(intake.pad_keyboard != null and is_instance_valid(intake.pad_keyboard), "Cross on TELL HIM opens the pad keyboard, not a text box")
	check(not intake.thought_edit.visible, "the keyboard-only line edit stays shut on the pad")
	check(await spell("11 MAR 1994 14:30"), "the birthday is spelled on the pad keyboard")
	await frames(2)
	var birth: Dictionary = intake.sheet.birth
	check(int(birth.get("day", 0)) == 11 and int(birth.get("month", 0)) == 3 and int(birth.get("year", 0)) == 1994 and int(birth.get("hour", -1)) == 14, "he writes it down: %s" % birth)
	check(intake.touched_pages.has(intake.BIRTH_PAGE), "BIRTH is confirmed")

	print("-- SCHEDULE: Cross signs, Circle stops his procedure --")
	answer_him()
	press(JOY_BUTTON_RIGHT_SHOULDER)
	check(intake.page == 6, "R1 turns to SCHEDULE")
	answer_him()
	press(JOY_BUTTON_A)
	check(intake.touched_pages.has(6), "Cross signs the first line")
	if not intake.procedure.is_empty():
		hints_are_pad_only("during his procedure")
		press(JOY_BUTTON_B)
		check(intake.procedure.is_empty(), "Circle stops the procedure")
	check(intake.page == 6, "Circle during a procedure does not also turn the page")

	print("-- STYLE: R1, d-pad, Cross --")
	answer_him()
	press(JOY_BUTTON_RIGHT_SHOULDER)
	check(intake.page == intake.STYLE_PAGE, "R1 turns to STYLE")
	goto_row(1)
	answer_him()
	press(JOY_BUTTON_A)
	check(intake.sheet.fighting_style == str(BloodTrees.STYLE_ORDER[1]), "Cross picks the second style (%s)" % intake.sheet.fighting_style)

	print("-- back: L1, L2, Circle --")
	answer_him()
	press(JOY_BUTTON_LEFT_SHOULDER)
	check(intake.page == 6, "L1 goes back a tab")
	axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	check(intake.page == 5, "L2 goes back a tab")
	answer_him()
	press(JOY_BUTTON_B)
	check(intake.page == 4, "Circle goes back a tab")

	print("-- rename: Create, Circle deletes, spell, Options --")
	press(JOY_BUTTON_BACK)
	var board = intake.pad_keyboard
	check(board != null and is_instance_valid(board), "Create opens the rename keyboard")
	var guard := 0
	while board != null and is_instance_valid(board) and str(board.text) != "" and guard < 40:
		guard += 1
		press(JOY_BUTTON_B)
	check(str(board.text) == "", "Circle deletes the old name")
	check(await spell("TEST SUBJECT 9"), "a new name is spelled")
	await frames(2)
	check(str(intake.sheet.display_name) == "TEST SUBJECT 9", "the header reads the new name (%s)" % intake.sheet.display_name)

	print("-- R3 with no mic: the think-out-loud presets --")
	var page_before: int = intake.page
	press(JOY_BUTTON_RIGHT_STICK, true)
	board = intake.pad_keyboard
	var has_board: bool = board != null and is_instance_valid(board)
	check(has_board and (board.presets as Array).has("NEXT PAGE"), "R3 with no pickup opens the keyboard with presets")
	press(JOY_BUTTON_RIGHT_STICK)
	if has_board and is_instance_valid(board):
		var preset_index: int = (board.presets as Array).find("NEXT PAGE")
		while board.cursor.x < preset_index:
			press(JOY_BUTTON_DPAD_RIGHT)
		press(JOY_BUTTON_A)
	await frames(2)
	check(intake.page == (page_before + 1) % intake.PAGES.size(), "Cross on NEXT PAGE thinks it at him and the page turns")

	print("-- file: Options, Cross through his lines, the vat opens --")
	check(intake._can_file(), "every page is confirmed (%s)" % [intake._unconfirmed()])
	hints_are_pad_only("ready to file")
	answer_him()
	press(JOY_BUTTON_START)
	check(intake.verdict_started, "Options files the form and his verdict begins")
	check(await wait_for(func() -> bool: return vat.intake == null, 90.0, func() -> void: press(JOY_BUTTON_A)), "Cross hurries his closing lines and the form is filed")
	var player := WorldHistory.subject("player")
	check(str(player.get("intake_route", "")) == "instrument", "the filed record holds the chosen route (%s)" % player.get("intake_route", ""))
	check(str(player.get("name", "")) == "TEST SUBJECT 9" and str(player.get("race", "")) == race_id, "and the name and race chosen on the pad")
	check(vat.phase in ["departure", "brain_screen"], "the vat opening begins: he walks out (%s)" % vat.phase)
	press(JOY_BUTTON_A)
	check(await wait_for(func() -> bool: return vat.phase == "brain_screen", 10.0), "Cross hurries him out and the brain screen opens")
	check(keys_sent == 0, "no key or mouse event was sent (%d)" % keys_sent)
	finish()
