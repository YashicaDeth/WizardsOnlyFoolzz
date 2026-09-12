extends Node

## The other half of Greg's report: the BODY page reached through the *device*
## (G, then Tab to the INDEX page) rather than through the HUD-level index.
## The hosted panel is sized into the handheld's aperture rather than the whole
## screen, which is exactly the kind of difference a pointer bug hides in.

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame
	for _settle in 20:
		await get_tree().physics_frame

	hunt.handheld.toggle_device()
	for _tick in 30:
		await get_tree().physics_frame
	print("DEVICE_OPEN=", hunt.handheld.is_open, " mode=", hunt.handheld.mode_index)

	var hosted = hunt.handheld._index
	print("HOSTED_VISIBLE=", hosted.visible, " rect=", hosted.get_global_rect())
	hosted._go_to_page(3, 1.0)
	for _tick in 20:
		await get_tree().physics_frame
	print("HOSTED_PAGE=", hosted.page)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/device_body.png")

	for y in range(0, 720, 24):
		for x in range(0, 1280, 40):
			var motion := InputEventMouseMotion.new()
			motion.position = Vector2(x, y)
			motion.relative = Vector2(6, 6)
			hosted._unhandled_input(motion)
		await get_tree().physics_frame
	print("SWEEP_OK hovered=", hosted._inspector.hovered_part_index)

	for y in range(0, 720, 40):
		for x in range(0, 1280, 60):
			var down := InputEventMouseButton.new()
			down.position = Vector2(x, y)
			down.button_index = MOUSE_BUTTON_LEFT
			down.pressed = true
			hosted._unhandled_input(down)
		await get_tree().physics_frame
	print("CLICK_OK zone=", hosted._inspector.zone)

	# And the same through the handheld's own mode cycling, which is the route
	# the player actually takes: Tab until INDEX comes round.
	for _cycle in 8:
		hunt.handheld.cycle_mode(1)
		for _tick in 6:
			await get_tree().physics_frame
	print("CYCLE_OK mode=", hunt.handheld.mode_index)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/device_body_after.png")
	print("REPRO_DONE")
	get_tree().quit()
