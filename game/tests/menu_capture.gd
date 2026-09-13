extends Node

## Y2/Y4. The front end as a player meets it: one door that says START GAME,
## two that say SOON and do not open, and the support row in settings.

var out_dir := "P:/GameDev/Temp"
var size := Vector2i(1280, 720)


func _shot(menu: Node, name: String) -> void:
	for _settle in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("CAPTURED: ", name)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		if argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = size
	await get_tree().process_frame

	var menu: Node = preload("res://country_town_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	# The warning card covers the column on a first run, and this is a photograph
	# of the menu, not of the card.
	var card := menu.get_node_or_null("HUD/WarningCard")
	if card != null:
		card.hide()
	await _shot(menu, "menu_00_the_column")

	menu.get_node("HUD/SettingsPanel").visible = true
	await _shot(menu, "menu_01_settings_support")

	# And what pressing it says when no mail client answers, which on this
	# machine is the honest case.
	menu.get_node("HUD/SettingsPanel/VBox/Support").emit_signal("pressed")
	await _shot(menu, "menu_02_support_pressed")

	print("MENU SHEET DONE")
	get_tree().quit(0)
