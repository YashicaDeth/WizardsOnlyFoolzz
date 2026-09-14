extends Node

## Verifies the escalating gore preview and the expanded per-tier copy on the
## content-rating card actually read correctly, not just that the code runs.

const WARNING_CARD := preload("res://systems/warning_card.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1000, 700)
	await get_tree().process_frame

	var card: Control = WARNING_CARD.new()
	add_child(card)
	await get_tree().process_frame
	card.open_card()
	for _settle in 5:
		await get_tree().process_frame

	for tier in 3:
		card._highlight(tier)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/warning_card_tier%d.png" % [out_dir, tier]
		print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)

	get_tree().quit()
