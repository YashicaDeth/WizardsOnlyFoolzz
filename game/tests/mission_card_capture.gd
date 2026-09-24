extends Node

## Renders the mission card at a few moments so it can be looked at.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var layer := CanvasLayer.new()
	add_child(layer)
	var card := MissionCard.new()
	layer.add_child(card)
	card.play("end_all_suffering", "END ALL SUFFERING", 5.2)
	card.set_process(false)
	for at in [0.3, 1.4, 3.1, 4.8]:
		card.clock = at
		card.queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/card_%s.png" % [out_dir, str(at)])
	card.play("get_revenge", "GET REVENGE", 3.6)
	card.set_process(false)
	card.clock = 1.2
	card.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/card_revenge.png" % out_dir)
	get_tree().quit()
