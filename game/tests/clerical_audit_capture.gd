extends Node

## D2.4 v2. The AUDIT prompt before and after use, on the player's own FILE
## page.

const SHEET := preload("res://systems/character_sheet.gd")
const WORLD_INDEX := preload("res://systems/world_index.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	var sheet: CharacterSheet = SHEET.new()
	sheet.display_name = "THE HUNTER"
	sheet.traits.append("clerical_error")
	sheet.apply_to_world()

	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var layer := CanvasLayer.new()
	add_child(layer)
	var index: Control = WORLD_INDEX.new()
	layer.add_child(index)
	index.size = Vector2(1280, 720)
	index.open()
	index._jump_to_subject("player")
	index.cursor_at = Vector2(900, 400)
	for _settle in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/clerical_audit_before.png" % out_dir)
	print("CAPTURED: %s/clerical_audit_before.png" % out_dir)

	for link: Dictionary in index._link_rects:
		if str(link.get("kind", "")) == "audit":
			index._follow_link(link)
	for _settle in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/clerical_audit_after.png" % out_dir)
	print("CAPTURED: %s/clerical_audit_after.png" % out_dir)
	get_tree().quit()
