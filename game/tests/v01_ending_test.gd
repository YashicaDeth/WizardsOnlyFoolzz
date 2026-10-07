extends Node
## Greg, 5 Oct: v0.1 ends at the Surface Gate. Walking out of it on the one
## facility map whites out, cuts to silence, opens on the world with the
## title, shows TO BE CONTINUED with the run card, then returns to the menu.
## The first time it cannot be skipped before the card; after that it can.

const ENDING := preload("res://systems/v01_ending.gd")

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _scene_path() -> String:
	var scene := get_tree().current_scene
	return "" if scene == null else scene.scene_file_path


func _press_accept(ending: Node) -> void:
	var press := InputEventAction.new()
	press.action = "ui_accept"
	press.pressed = true
	ending._unhandled_input(press)


func _press_gamepad_start(ending: Node) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_START
	press.pressed = true
	ending._unhandled_input(press)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var before_db := AudioServer.get_bus_volume_db(0)
	RunTimer.start()
	RunTimer.enter("growing_floor")
	RunTimer.enter("service_arcade")
	RunTimer.enter("lower_works")
	# The facility becomes the current scene; this node stays on the root so
	# it watches the ending carry the game into the world and the menu.
	var facility: Node = load("res://facility.tscn").instantiate()
	facility.set("play_ending_in_tests", true)
	get_tree().root.add_child.call_deferred(facility)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = facility
	await get_tree().physics_frame
	# Up the heat elevator and out of the head-house, through the gate.
	facility.player.global_position = Vector3(28, facility.SURFACE_Y + 0.4, facility.GATE_Z - 0.6)
	for _frame in 4:
		await get_tree().physics_frame
	var ending: Node = facility.ending
	check(facility.exit_reached, "walking through the Surface Gate is the exit")
	check(ending != null and ending.get_parent() == get_tree().root, "the gate starts the v0.1 ending on the tree root")
	if ending == null:
		_finish()
		return
	check(AudioServer.get_bus_volume_db(0) <= -79.0, "the facility hum cuts to silence at the gate")
	check(ending.white_alpha() > 0.99, "blinding daylight: the screen is white")
	check(not ending.skippable and not ending.can_skip(), "first view: it cannot be skipped")
	_press_accept(ending)
	check(not ending.menu_reached, "a press during the first view does nothing")
	check(bool(RunTimer.record().get("finished", false)), "the timed run ends at the gate")
	check(not ending.run_summary.is_empty() and (ending.run_summary.rows as Array).size() == 3, "the run card has a row per area")
	Engine.time_scale = 3.0
	var saw_world := false
	var hunt_surfacing := false
	var saw_title_over_world := false
	var saw_wind := false
	var saw_card := false
	var saw_eyes_adjust := false
	var view_model_hidden := false
	var deadline := Time.get_ticks_msec() + 90000
	while is_instance_valid(ending) and not ending.menu_reached and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not is_instance_valid(ending):
			break
		if _scene_path() == ENDING.WORLD_SCENE:
			saw_world = true
			hunt_surfacing = hunt_surfacing or get_tree().current_scene.get_node_or_null("Surfacing") != null
			var hunter_body := get_tree().current_scene.find_child("HunterBody", true, false) as Node3D
			view_model_hidden = view_model_hidden or (hunter_body != null and not hunter_body.visible)
			saw_eyes_adjust = saw_eyes_adjust or ending.white_alpha() < 0.2
			saw_title_over_world = saw_title_over_world or ending.title_alpha() > 0.9
		saw_wind = saw_wind or ending._wind.playing
		if ending.card_alpha() >= 1.0 and ending._card != null:
			if not saw_card:
				check(ending.can_skip(), "once TO BE CONTINUED is up, it can be skipped")
				check(ending.return_key() in ["CROSS", "ENTER"], "and the card names the button that skips it (%s)" % ending.return_key())
				check(is_equal_approx(float(ending._card.presentation_scale), 1.55), "the ending run card uses its couch-readable scale")
			saw_card = true
			var hidden_body := ending._hidden_view_model as Node3D
			var hidden_hud := ending._hidden_hud as CanvasLayer
			_press_gamepad_start(ending)
			check(ending.menu_reached, "gamepad Start returns from the card")
			check(hidden_body != null and hidden_body.visible, "return restores the view model before leaving play")
			check(hidden_hud != null and hidden_hud.visible, "return restores the held-item HUD before leaving play")
	Engine.time_scale = 1.0
	check(saw_world, "the world loads under the white")
	check(not hunt_surfacing, "the Hunt's own surfacing stands down for the ending")
	check(saw_eyes_adjust, "the eyes adjust out of the white onto the world")
	check(saw_wind, "open air and wind come in")
	check(saw_title_over_world, "the WIZARDS ONLY FOOLS logo drops over the first view")
	check(view_model_hidden, "the first-person body and held view model stay out of the ending")
	check(saw_card, "then the TO BE CONTINUED card with the run times")
	for _frame in 6:
		await get_tree().process_frame
	check(_scene_path() == ENDING.MENU_SCENE, "and back to the title menu (%s)" % _scene_path())
	check(absf(AudioServer.get_bus_volume_db(0) - before_db) < 0.01, "sound is back at the menu")
	check(not get_tree().root.has_meta(ENDING.ACTIVE_META), "the Hunt is no longer stood down")
	check(WorldHistory.event_count(ENDING.SEEN_EVENT) == 1, "the ending is recorded as seen")
	# A second ending on this save can be skipped straight away.
	var again: Node = ENDING.new()
	get_tree().root.add_child(again)
	again.begin("")
	check(again.skippable and again.can_skip(), "seen once, the next ending is skippable from the start")
	_press_accept(again)
	check(again.menu_reached, "a press skips it to the menu")
	for _frame in 4:
		await get_tree().process_frame
	check(_scene_path() == ENDING.MENU_SCENE, "skipped to the title menu")
	check(absf(AudioServer.get_bus_volume_db(0) - before_db) < 0.01, "skipping never leaves the game silent")
	_finish()


func _finish() -> void:
	Engine.time_scale = 1.0
	print("V01_ENDING_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
