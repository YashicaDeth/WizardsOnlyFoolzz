extends Node

## Greg, latest playtest: *"the map in the maingame is completly broken"*.
##
## `map_perf_test` reports the map costing 0.00 ms at every zoom and passes. That
## is not evidence the map is fine — it is exactly what a map drawing *nothing*
## measures, and a headless run renders nothing at all, so the perf number cannot
## tell a fast map from an absent one. A map is a look problem and look problems
## have to be looked at.
##
## This opens the real map over the real game, at the same three zooms the perf
## test uses, and writes one PNG each.
##
## Usage:
##   Godot --path game res://tests/map_capture.tscn -- --out=P:/GameDev/Temp

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")

	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	await tree.process_frame

	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	tree.root.add_child(hunt)
	tree.current_scene = hunt
	for _settle in 90:
		await tree.process_frame

	var map: Control = hunt.get("living_map")
	if map == null:
		print("CAPTURE_FAILED: bone_yard_hunt has no living_map")
		tree.quit(1)
		return

	# Walk, so the veil has a real explored edge rather than a uniform field —
	# the same walk map_perf_test does, so the two are looking at one map.
	for step in 40:
		map.observe(Vector3(float(step) * 5.0, 0.0, 22.0 - float(step) * 3.0), 0.4)

	hunt.call("_toggle_panel", "map")
	for _settle in 30:
		await tree.process_frame

	print("map visible=%s size=%s zoom=%s" % [str(map.visible), str(map.size), str(map.get("zoom"))])

	for zoom in [0.7, 1.25, 2.6]:
		map.set("zoom", zoom)
		map.queue_redraw()
		for _settle in 20:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/map_zoom_%s.png" % [out_dir, str(zoom).replace(".", "_")]
		if get_viewport().get_texture().get_image().save_png(path) != OK:
			print("CAPTURE_FAILED ", path)
			tree.quit(1)
			return
		print("CAPTURED: ", path)

	tree.quit()
