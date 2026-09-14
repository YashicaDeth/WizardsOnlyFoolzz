extends Node

## The front door, photographed past the consent gate.
##
## `capture_scene.gd` against `country_town_menu.tscn` photographs the gore
## warning card instead of the menu, because the card shows until a choice is on
## record and a fresh capture never has one. That makes the title card — the
## wordmark, the menu, the whole first impression Greg keeps asking about —
## unphotographable by the harness that exists to photograph it.
##
## This puts a choice on record first, then shoots the menu.
##
## Usage:
##   Godot --path game res://tests/title_capture.tscn -- --out=P:/GameDev/Temp/title.png

func _ready() -> void:
	var out_path := "P:/GameDev/Temp/title.png"
	var settle_frames := 260
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
		elif argument.begins_with("--frames="):
			settle_frames = int(argument.trim_prefix("--frames="))

	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	await tree.process_frame

	# The same key `warning_card.gd:112` writes when the player picks a level.
	# `--panel=warning` shoots the consent card itself, which means arriving
	# without the acknowledgement a previous capture may have left on record.
	var want_warning := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--panel=warning":
			want_warning = true
	if want_warning:
		WorldHistory.update_subject("settings", {"violence_acknowledged": ""}, "gore_setting_cleared")
	else:
		WorldHistory.update_subject("settings", {"gore": "FULL", "violence_acknowledged": "yes"}, "gore_setting_chosen")
	await tree.process_frame

	var menu: Node = load("res://country_town_menu.tscn").instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu

	# The cold open runs on a timer before the menu is reachable, so this waits
	# it out rather than photographing a blackout and calling it a title card.
	for _settle in settle_frames:
		await tree.process_frame

	# Greg named the settings and continue screens directly, and both are panels
	# over this menu rather than scenes of their own, so they cannot be shot by
	# loading something.
	var panel := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--panel="):
			panel = argument.trim_prefix("--panel=")
	if panel.begins_with("prologue"):
		# Straight to the cutscene, then held on one card. `--panel=prologue2`
		# shoots the third card, and so on — a fade cycle is CARD_FADE*2 +
		# CARD_HOLD long and the prologue cannot be scrubbed any other way.
		var want_card := 0
		if panel.length() > 9:
			want_card = int(panel.substr(9))
		menu.call("_play_decanting_prologue")
		var pro = menu.get("prologue")
		# Read off the instance rather than the global class name: a freshly
		# added `class_name` is not registered until the project is rescanned,
		# and a test that cannot run until then is a test that silently fails.
		for _settle in 8:
			await tree.process_frame
		pro.card = want_card
		pro.clock = float(pro.get("CARD_FADE")) + float(pro.get("CARD_HOLD")) * 0.4
		pro.set_process(false)
		pro._card_alpha = 1.0
		pro.queue_redraw()
		for _settle in 4:
			await tree.process_frame
	elif panel == "settings":
		menu.call("_open_settings")
	elif panel == "continue":
		menu.call("_open_continue_runs")
	if not panel.is_empty():
		for _settle in 60:
			await tree.process_frame

	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(out_path) != OK:
		print("CAPTURE_FAILED ", out_path)
		tree.quit(1)
		return
	print("CAPTURED: ", out_path)
	tree.quit()
