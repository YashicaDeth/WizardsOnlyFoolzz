extends Node

## Two captures from the real hunt scene came back near-black while the live
## game looks bright. Camera is confirmed correct, lights are confirmed present.
## The remaining suspect is HUD/ScreenTreatment: a full-screen ColorRect running
## a shader that samples hint_screen_texture. Capture one frame with it on and
## one with it off, and compare the average brightness. That settles it.

func _ready() -> void:
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _settle in 100:
		await get_tree().process_frame
	var treatment: Control = hunt.get_node_or_null("HUD/ScreenTreatment")
	for pass_index in 2:
		if treatment != null:
			treatment.visible = pass_index == 0
		for _frame in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var total := 0.0
		var step := 8
		var samples := 0
		for y in range(0, image.get_height(), step):
			for x in range(0, image.get_width(), step):
				var pixel := image.get_pixel(x, y)
				total += (pixel.r + pixel.g + pixel.b) / 3.0
				samples += 1
		var label := "treatment ON " if pass_index == 0 else "treatment OFF"
		print("BRIGHTNESS %s : %.4f" % [label, total / float(maxi(samples, 1))])
		image.save_png("P:/GameDev/Temp/dark_probe_%s.png" % ("on" if pass_index == 0 else "off"))
	get_tree().quit()
