extends Node

## Job 4: the whole opening beat chain on the pad alone, through the real
## input path (`Input.parse_input_event`), from the black of the load-in to
## standing on the Growing Floor: skip the load-in, quick start on the intake,
## skip his walk out, slot both disciplines on the brain screen, skip the hack,
## aim at each wire with the right stick and tear it out with Square, tear the
## cord, hit the glass with R1 until it bursts, Cross to get up. No key and no
## mouse event is sent. Also times the run in game seconds (BUILD_BRIEFS: four
## minutes from load-in to standing).

const VAT := preload("res://vat_chamber.tscn")
## Wall-clock budget for the scene; the run is sped up so it fits a suite.
const SPEED := 3.0
const LIMIT_GAME_SECONDS := 240.0

var failures: Array[String] = []
var vat
var game_seconds := 0.0
var keys_sent := 0


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func finish() -> void:
	Engine.time_scale = 1.0
	TortureLoadIn.force_in_tests = false
	BrainScreen.force_in_tests = false
	preload("res://systems/brain_hack.gd").force_in_tests = false
	print("VAT_PAD_CHAIN_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		keys_sent += 1


func button(index: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = index
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func stick(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## Wait up to `seconds` of game time for `done` to hold, pressing `each` (a
## Callable) every `every` game seconds meanwhile.
func wait_for(done: Callable, seconds: float, each := Callable(), every := 0.35) -> bool:
	var waited := 0.0
	var since := 0.0
	while waited < seconds:
		if done.call():
			return true
		await get_tree().process_frame
		var step := get_process_delta_time()
		waited += step
		since += step
		game_seconds += step
		if each.is_valid() and since >= every:
			since = 0.0
			each.call()
	return done.call()


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	TortureLoadIn.force_in_tests = true
	BrainScreen.force_in_tests = true
	preload("res://systems/brain_hack.gd").force_in_tests = true
	vat = VAT.instantiate()
	vat.hands_on_breakout = true
	# The vat is the current scene, as in the game: PadBridge leaves migrated
	# scenes alone, so no pad press is turned into a key behind our back.
	get_tree().root.add_child.call_deferred(vat)
	await get_tree().process_frame
	get_tree().current_scene = vat
	await get_tree().process_frame
	Engine.time_scale = SPEED

	print("-- load-in: Cross cuts to the glitch --")
	check(vat.load_in != null, "the load-in plays first")
	# Greg, playtest D: the intro played "ultra sped up". Behind the travel
	# plate it must not run, and a long hitch must not leap it forward.
	var plate := get_node("/root/Interstitial")
	var held_clock: float = vat.load_in.clock
	plate.set("travelling", true)
	vat.load_in._process(2.0)
	check(is_equal_approx(vat.load_in.clock, held_clock), "the load-in waits behind the loading plate")
	plate.set("travelling", false)
	vat.load_in._process(2.0)
	check(vat.load_in.clock - held_clock <= 1.0 / 30.0 + 0.0001, "a 2 s hitch moves it one frame, not two seconds (%.3f)" % (vat.load_in.clock - held_clock))
	button(JOY_BUTTON_A)
	check(await wait_for(func() -> bool: return vat.load_in == null, 8.0), "Cross skips the load-in and it hands over")

	print("-- intake: Cross on the default button is the quick start --")
	check(await wait_for(func() -> bool: return vat.intake != null and vat.intake.intake_armed, 20.0), "the form arms")
	button(JOY_BUTTON_A)
	check(await wait_for(func() -> bool: return vat.intake == null, 90.0, func() -> void: button(JOY_BUTTON_A)), "Cross files the quick start (Cross hurries his closing lines)")
	check(str(WorldHistory.subject("player").get("route", "preset")) != "" and vat.phase in ["departure", "brain_screen"], "filed into his walk out (%s)" % vat.phase)

	print("-- departure, then the brain screen --")
	button(JOY_BUTTON_A)
	check(await wait_for(func() -> bool: return vat.phase == "brain_screen", 8.0), "Cross hurries him out and the brain screen opens")
	var screen = vat.brain_screen
	check(screen != null and screen.DISCIPLINES.size() == 2, "the chip offers the two v0.1 disciplines")
	button(JOY_BUTTON_A)
	button(JOY_BUTTON_A)
	check(screen != null and is_instance_valid(screen) and screen.ready_to_lock(), "Cross, Cross slots both")
	button(JOY_BUTTON_A)
	check(await wait_for(func() -> bool: return vat.phase == "hacked", 2.0), "Cross locks them in and the hack begins")
	var slotted: Array = WorldHistory.subject("player").get("disciplines", [])
	check(slotted == ["brawler", "marksman"] and WorldHistory.event_count("brain_disciplines_slotted") == 1, "history holds both disciplines (%s)" % [slotted])
	check(str(WorldHistory.subject("player").get("camera", "")) == "third_person", "third person is switched on")

	print("-- the hack: Cross skips to the card --")
	button(JOY_BUTTON_A)
	check(await wait_for(func() -> bool: return vat.phase == "wired", 15.0), "the hack ends and you hang in the wires (%s)" % vat.phase)
	check(vat.in_fluid() and vat.fluid.visible and not vat.glass_tank.broken, "still under the red medium while you work at the wires")

	print("-- the wires: right stick to aim, Square to tear --")
	var guard := 0
	while not vat.umbilicals.is_empty() and guard < 8:
		guard += 1
		var cable: Node3D = vat.umbilicals[0]
		var aimed := await aim_at(cable)
		check(aimed, "the right stick brings wire %d into the middle of the view" % guard)
		vat._update_hud()
		if guard == 1:
			check(vat.prompt.text.contains("SQUARE") or vat.prompt.text.contains("PAD"), "the prompt names the pad button (%s)" % vat.prompt.text)
		for _tug in vat.WIRE_TUGS:
			button(JOY_BUTTON_X)
		check(not vat.umbilicals.has(cable), "Square tears wire %d out" % guard)
	check(vat.phase == "cord", "with the wires out, the cord in your mouth is left (%s)" % vat.phase)

	print("-- the cord, then the glass with R1 --")
	for _pull in vat.CORD_TUGS:
		button(JOY_BUTTON_X)
	check(vat.phase == "smash", "Square tears the cord out")
	for blow in range(1, vat.GLASS_BLOWS):
		button(JOY_BUTTON_RIGHT_SHOULDER)
		check(vat.glass_tank.crack_stage() == blow and not vat.glass_tank.broken, "R1 blow %d cracks the glass" % blow)
	button(JOY_BUTTON_RIGHT_SHOULDER)
	check(vat.glass_tank.broken and vat.breakout_complete, "the last blow bursts it")
	check(not vat.in_fluid(), "out of the medium")
	check(await wait_for(func() -> bool: return vat.spill.volume() > 0.004, 4.0), "the medium floods the floor (%.4f m3)" % vat.spill.volume())

	print("-- knees, crawl, up --")
	check(await wait_for(func() -> bool: return vat.boot_hud != null and vat.boot_hud.done, 15.0), "the implant boots the HUD while you're down")
	vat._update_hud()
	check(vat.prompt.text.contains("CROSS") or vat.prompt.text.contains("PAD"), "GET UP names Cross (%s)" % vat.prompt.text)
	var down_at: Vector3 = vat.player.global_position
	button(JOY_BUTTON_A)
	check(await wait_for(func() -> bool: return vat.can_move, 10.0), "Cross gets you up and you can move")
	var crawled := Vector2(vat.player.global_position.x - down_at.x, vat.player.global_position.z - down_at.z).length()
	check(crawled > 2.0, "you crawl a few metres first (%.2fm)" % crawled)
	check(absf(vat.camera.global_position.y - 1.62) < 0.15, "standing eye height")
	check(keys_sent == 0, "no key or mouse event was sent (%d)" % keys_sent)
	print("TIMED RUN (pad, skipping every skippable scene): %.1f game seconds" % game_seconds)
	check(game_seconds < LIMIT_GAME_SECONDS, "load-in to standing under four minutes (%.1fs)" % game_seconds)
	finish()


## Push the right stick toward `cable` until the vat aims at it.
func aim_at(cable: Node3D) -> bool:
	for _frame in 400:
		if vat._aimed_wire(vat.PAD_WIRE_CONE) == cable:
			stick(JOY_AXIS_RIGHT_X, 0.0)
			stick(JOY_AXIS_RIGHT_Y, 0.0)
			return true
		var target: Vector3 = (cable.get_child(3) as Node3D).global_position
		var to: Vector3 = (target - vat.camera.global_position).normalized()
		var want_yaw := atan2(-to.x, -to.z)
		var want_pitch := asin(clampf(to.y, -1.0, 1.0))
		var yaw_error := wrapf(want_yaw - float(vat.yaw), -PI, PI)
		var pitch_error := want_pitch - float(vat.pitch)
		# yaw -= x, pitch -= y (InputProfile.apply_stick_look).
		stick(JOY_AXIS_RIGHT_X, clampf(-yaw_error * 2.5, -1.0, 1.0) if absf(yaw_error) > 0.03 else 0.0)
		stick(JOY_AXIS_RIGHT_Y, clampf(-pitch_error * 2.5, -1.0, 1.0) if absf(pitch_error) > 0.03 else 0.0)
		await get_tree().physics_frame
		game_seconds += get_physics_process_delta_time()
	stick(JOY_AXIS_RIGHT_X, 0.0)
	stick(JOY_AXIS_RIGHT_Y, 0.0)
	return false
