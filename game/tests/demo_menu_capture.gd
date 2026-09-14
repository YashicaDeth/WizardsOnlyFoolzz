extends Node

## Fast proof of the P2 front door. The production title sequence is already
## covered by `title_capture`; this freezes its end state instead of spending
## minutes advancing a heavy procedural street for a layout-only check.


func _ready() -> void:
	var out_path := "P:/GameDev/Temp/lane4_demo_menu.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	WorldHistory.update_subject("settings", {"gore": "FULL", "violence_acknowledged": "yes"}, "capture_setup")
	await get_tree().process_frame

	var menu := preload("res://country_town_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await get_tree().process_frame
	menu.get_node("HUD/TitleLogo").modulate.a = 1.0
	menu.get_node("HUD/Algiz").modulate.a = 1.0
	for button: Button in menu.menu_buttons:
		button.modulate.a = 1.0
	if menu.intro_veil != null:
		menu.intro_veil.hide()
	if menu.splash != null:
		menu.splash.reveal = 1.0
	# Give the procedural stroke plate and its shader-backed backdrop enough
	# rendered frames to finish. One frame can contain only a suffix of several
	# labels while pipelines are still compiling, which is not a truthful shot.
	for _frame in 12:
		WorldHistory.world_minute = WorldClock.OPENING_MINUTE
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(out_path)
	print("shot at hour %.2f (%s), daylight %.3f" % [WorldClock.hour(), WorldClock.phase(), WorldClock.daylight()])
	print("CAPTURED: " if result == OK else "CAPTURE_FAILED: ", out_path)
	get_tree().quit(0 if result == OK else 1)
