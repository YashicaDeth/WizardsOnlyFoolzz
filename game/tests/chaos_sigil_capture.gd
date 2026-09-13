extends Node2D

## AJ1. Proves `ChaosSigil.draw()` actually reaches the real seal engine
## rather than only the data half — three different stated intents, drawn
## as three different marks, so a look at the PNG confirms the drawing
## reuses `celloutz_type.gd`'s existing engine correctly rather than only
## the seed math agreeing with itself in the headless test.

const ChaosSigil := preload("res://systems/chaos_sigil.gd")

var _intents := ["I want to be seen", "burn the debt collector's ledger", "let the wound close"]


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(900, 340)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/chaos_sigil_gallery.png" % out_dir
	print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)
	get_tree().quit()


func _draw() -> void:
	for index in _intents.size():
		var intent: String = _intents[index]
		var center := Vector2(150 + index * 300, 170)
		ChaosSigil.draw(self, center, 110.0, intent, Color("dc5827"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-140, 150), intent, HORIZONTAL_ALIGNMENT_CENTER, 280, 14, Color.WHITE)
