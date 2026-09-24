extends Node

## The opening, driven the way a player drives it, up to the moment control
## becomes theirs.
##
## This used to send a single F one physics frame after the scene loaded and
## then wait for `can_move`. It could never have passed. Two gates sit in front
## of filing, and both are deliberate:
##
##   - the form is not armed until `FORM_REVEAL_AT` (5.5s), and until then
##     `vat_intake._unhandled_input()` swallows every key;
##   - `_can_file()` wants every tab visited and a route and a race chosen --
##     "he does not let you leave without telling you what it was for".
##
## So the F landed on a dead handler, nothing filed, and all six checks failed
## on the same missing cause. The gates are the design; the test was asserting a
## shortcut past them that the scene deliberately does not have.
##
## The budget was wrong too, and wrong in a way worth stating rather than
## quietly widening. The live route is 5.5s of form reveal, then an eleven
## second verdict he will not be hurried through, then a 4.4s departure and an
## 8.8s vat sequence: thirty seconds, by construction. A 25s bound asserted
## something the opening does not do. What is worth holding is that the handoff
## *arrives*, and arrives intact -- so the bound is generous and the real figure
## is printed, where a pacing regression is still visible.

## Long enough for the whole authored opening with headroom, short enough that a
## sequence which stops advancing fails rather than hanging the suite.
## 75 s since 2026-09-24: every line of his closing verdict is now held long
## enough to read (Greg: the text went by too fast), not a flat three seconds.
const HANDOFF_BUDGET := 75.0

var failures: Array[String] = []
var opening: Node


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## One key, delivered the way the scene receives them.
func press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	opening.intake._unhandled_input(event)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	opening = load("res://vat_chamber.tscn").instantiate()
	add_child(opening)
	await get_tree().physics_frame

	print("-- the form does not take a key until it is on screen --")
	press(KEY_F)
	check(not opening.intake.verdict_started, "F before the form is armed does nothing")

	# Waited out rather than armed by hand, because the waiting is the gate and
	# a test that reaches past it stops testing it.
	var waited := 0.0
	while not opening.intake.intake_armed and waited < 12.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	check(opening.intake.intake_armed, "the form arms itself (%.1fs)" % waited)

	print("-- filing it, one tab at a time --")
	# Page 0 is ROUTE, and row 2 is CHART: a deliberate pass, rather than PRESET
	# which depends on whether anything is on file, or RANDOM which fills the
	# rest of the sheet behind the test's back.
	press(KEY_DOWN)
	press(KEY_DOWN)
	press(KEY_ENTER)
	check(str(opening.intake.sheet.route) == "chart", "the route is chosen (%s)" % str(opening.intake.sheet.route))
	# Every remaining tab has to be visited, which is the gate he enforces.
	# Committing the first row of each is what accepting the defaults looks like.
	for _page in range(1, opening.intake.PAGES.size()):
		press(KEY_RIGHT)
		press(KEY_ENTER)
		await get_tree().physics_frame
	check(not str(opening.intake.sheet.race).is_empty(), "a race is on the sheet (%s)" % str(opening.intake.sheet.race))
	check(int(opening.intake.touched_pages.size()) == int(opening.intake.PAGES.size()), "every tab was confirmed (%d of %d)" % [int(opening.intake.touched_pages.size()), int(opening.intake.PAGES.size())])

	# D8.3. Confirming a tab can start a procedure, and while he is working the
	# form does not take keys -- "you are not filling in a form". A player waits
	# him out, so this does too. Pressing F through it was the last thing
	# swallowing the filing.
	var settling := 0.0
	while not opening.intake.procedure.is_empty() and settling < 25.0:
		await get_tree().physics_frame
		settling += get_physics_process_delta_time()
	check(opening.intake.procedure.is_empty(), "the procedure he started finishes (%.1fs)" % settling)

	print("-- and he says what it was for before he goes --")
	press(KEY_F)
	check(opening.intake.verdict_started, "F on a complete form starts the verdict")

	var elapsed := 0.0
	while not opening.can_move and elapsed < HANDOFF_BUDGET:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	check(opening.can_move, "one filing reaches free movement on the live route (%.1fs after filing)" % elapsed)

	print("-- and what arrives is someone who can stand and walk --")
	var handoff_height: float = opening.camera.global_position.y
	var lowest := handoff_height
	var start: Vector3 = opening.player.position
	Input.action_press("move_forward")
	for frame in 120:
		await get_tree().physics_frame
		lowest = minf(lowest, opening.camera.global_position.y)
	Input.action_release("move_forward")
	check(handoff_height - lowest < 0.12, "standing eye does not fall when physics takes over (drop %.3fm)" % (handoff_height - lowest))
	check(absf(opening.camera.global_position.y - 1.62) < 0.12, "first steps retain standing eye height")
	check(opening.player.position.z < start.z - 3.0 and opening.player.is_on_floor(), "first movement walks forward on the grating")
	check(opening.breakout_complete and opening.first_acquisition_complete, "breakout and existing restraint acquisition survive the handoff")
	var cybernetics: Array = WorldHistory.subject("player").get("anatomy_state", {}).get("cybernetics", [])
	check(cybernetics.any(func(part): return str((part as Dictionary).get("id", "")) == "wetwire chip"), "the wetwire implant is installed as catalogue hardware")
	check(opening.get_node("HUD/Objective").text.contains("ESCAPE THE FACILITY"), "escape purpose remains visible during the first steps")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--capture=")) == OK, "live first-step capture saved")
	print("OPENING_HANDOFF_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
