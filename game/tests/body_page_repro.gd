extends Node

## Reproduction for the crash Greg hit opening the BODY page of the index and
## looking at the parts. Drives the real panel with real pointer events rather
## than calling its methods, because the report is specifically about pointing
## at things.

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame
	for _settle in 20:
		await get_tree().physics_frame

	hunt._toggle_panel("index")
	for _tick in 8:
		await get_tree().physics_frame
	var index = hunt.world_index
	print("PAGE_BEFORE=", index.page)

	# Straight to BODY, the way the page tabs and the number keys both do it.
	index._go_to_page(3, 1.0)
	for _tick in 20:
		await get_tree().physics_frame
	print("PAGE_AFTER=", index.page)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/body_page.png")

	# Sweep the pointer over the whole panel, then click everywhere on a grid.
	# Part rects are only populated by a draw, so motion precedes buttons.
	for y in range(80, 700, 28):
		for x in range(60, 1240, 44):
			var motion := InputEventMouseMotion.new()
			motion.position = Vector2(x, y)
			motion.relative = Vector2(4, 4)
			index._unhandled_input(motion)
		await get_tree().physics_frame
	print("SWEEP_OK hovered=", index._inspector.hovered_part_index)

	for y in range(90, 700, 60):
		for x in range(70, 1240, 90):
			var down := InputEventMouseButton.new()
			down.position = Vector2(x, y)
			down.button_index = MOUSE_BUTTON_LEFT
			down.pressed = true
			index._unhandled_input(down)
		await get_tree().physics_frame
	print("CLICK_OK zone=", index._inspector.zone, " part=", index._inspector.part_index)

	# And the key the BODY page owns.
	for _press in 8:
		var key := InputEventKey.new()
		key.keycode = KEY_TAB
		key.pressed = true
		index._unhandled_input(key)
		await get_tree().physics_frame
	print("KEY_OK part=", index._inspector.part_index)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/body_page_after.png")
	print("REPRO_DONE")
	get_tree().quit()
