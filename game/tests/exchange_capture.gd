extends Node

## The Wire exchange as a player sees it: the reel mid-spin, the SKINS tab and
## the WARDROBE tab. `-- --out=DIR`.

var menu: CaseMenu


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.update_subject("inventory", {"rust_scrip": 5000})
	var carry := Carry.new()
	for skin_id in ["sidearm_midas_nine", "shotgun_case_hardened", "sword_abattoir_marble", "sidearm_dry_falls", "jester_doublet_fade"]:
		carry.items.append(WeaponSkins.mint(skin_id, 0.3, 42))
	carry.items.append(SkinCase.case_item("abattoir_case"))
	var layer := CanvasLayer.new()
	add_child(layer)
	menu = CaseMenu.new()
	layer.add_child(menu)
	menu.open_menu(carry, null)
	menu.selected = menu.case_ids().find("wetwork_case")
	menu.handle_input(_key(KEY_ENTER))
	menu._reel_clock = 2.2
	await _shot("%s/exchange_reel.png" % out_dir)
	menu._finish_reel()
	menu.handle_input(_key(KEY_D))
	await _shot("%s/exchange_skins.png" % out_dir)
	menu.handle_input(_key(KEY_D))
	await _shot("%s/exchange_wardrobe.png" % out_dir)
	get_tree().quit()


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _shot(path: String) -> void:
	menu.set_process(false)
	menu.queue_redraw()
	for _frame in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("CAPTURED: " if get_viewport().get_texture().get_image().save_png(path) == OK else "CAPTURE_FAILED: ", path)
