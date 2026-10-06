extends Node

## bughunt-79: the title menu as a player meets it after it settles, and the
## START input chooser (which every test skips through ATG_TEST_MODE).
## Run windowed: render_one.cmd menu_chooser_capture --out=DIR

var out_dir := "P:/GameDev/Temp"


func _shot(name: String, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("CAPTURED: ", name)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	OS.set_environment("ATG_TEST_MODE", "0")
	var menu: Node = preload("res://country_town_menu.tscn").instantiate()
	add_child(menu)
	var card := menu.get_node_or_null("HUD/WarningCard")
	if card != null:
		card.hide()
	await _shot("chooser_0_menu_settled", 4.0)
	menu.call("_start_demo")
	await _shot("chooser_1_open", 0.6)
	var press := InputEventAction.new()
	press.action = "ui_down"
	press.pressed = true
	Input.parse_input_event(press)
	await _shot("chooser_2_down", 0.4)
	print("MENU CHOOSER CAPTURE DONE focus=", get_viewport().gui_get_focus_owner())
	get_tree().quit(0)
