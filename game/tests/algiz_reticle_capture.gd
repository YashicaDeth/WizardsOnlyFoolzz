extends Node

## Photographs the Algiz cursor in both of its states and once mid-turn, because
## "it inverts" is a claim about a picture and has to be checked as one.
##
## Three plates: upright (out of combat, life), edge-on (the halfway frame of the
## flip, which is the frame that proves it turns rather than cuts) and inverted
## (in combat, death). Each is shot twice — once at cursor scale over a dark
## plate, once blown up large so the stroke geometry can actually be read.

const RETICLE := preload("res://systems/algiz_reticle.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	await tree.process_frame

	var plate := ColorRect.new()
	plate.color = Color("14161a")
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(plate)

	# A crosshair-height rule through the exact centre, so the capture also shows
	# whether dead centre is clear enough to aim through.
	var guide := ColorRect.new()
	guide.color = Color(1, 1, 1, 0.10)
	guide.position = Vector2(0, 359)
	guide.size = Vector2(1280, 1)
	add_child(guide)

	var small: Control = RETICLE.new()
	add_child(small)
	small.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	small.position = Vector2.ZERO
	small.size = Vector2(1280, 720)
	small.set("mark_size", 36.0)

	# The same control at six times the size, parked off to one side, so the bars
	# and the stencil bridge are legible in the PNG.
	var large: Control = RETICLE.new()
	add_child(large)
	large.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	large.position = Vector2(-320, 0)
	large.size = Vector2(1280, 720)
	large.set("mark_size", 220.0)

	await tree.process_frame

	# Upright. Out of combat: life and protection.
	small.call("snap_state", false)
	large.call("snap_state", false)
	await _shoot(tree, out_dir + "/algiz_upright.png")
	print("facing upright: %.3f" % float(small.call("facing")))

	# Mid-turn. Held at exactly halfway rather than caught by timing, so the plate
	# is reproducible; processing is stopped so the ease does not walk off the
	# mark during the four frames the shot takes.
	small.set_process(false)
	large.set_process(false)
	small.set("_flip", 0.5)
	large.set("_flip", 0.5)
	small.queue_redraw()
	large.queue_redraw()
	await _shoot(tree, out_dir + "/algiz_turning.png")
	print("facing edge-on: %.3f" % float(small.call("facing")))
	small.set_process(true)
	large.set_process(true)

	# Inverted. In combat: death.
	small.call("snap_state", true)
	large.call("snap_state", true)
	await _shoot(tree, out_dir + "/algiz_inverted.png")
	print("facing inverted: %.3f" % float(small.call("facing")))

	# And the eased transition actually runs when driven by the real entry point,
	# rather than only when poked. Report how long it takes to complete.
	small.call("snap_state", false)
	small.call("set_in_combat", true)
	var elapsed := 0.0
	while absf(float(small.call("facing")) + 1.0) > 0.001 and elapsed < 3.0:
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()
	print("flip completed in %.2fs, facing %.3f" % [elapsed, float(small.call("facing"))])
	tree.quit(0)


func _shoot(tree: SceneTree, path: String) -> void:
	for _frame in 4:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)
