extends Node

## A10 verification. The satellite layer is a picture of the real region, so the
## only way to know it works is to look at it.

func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _settle in 120:
		await get_tree().process_frame

	# Walk a little so some ground is actually surveyed and the veil has an edge.
	var map: Control = hunt.get("living_map")
	for step in 14:
		map.observe(Vector3(float(step) * 6.0, 0.0, 19.0 - float(step) * 4.0), 0.4)
	hunt.call("_toggle_panel", "map")
	for _settle in 30:
		await get_tree().process_frame

	var has_sat: bool = map.get("satellite") != null
	print("REPORT satellite attached: ", has_sat)

	for shot in [{"name": "sat_top", "zoom": 0.9}, {"name": "sat_oblique", "zoom": 2.2}, {"name": "sat_street", "zoom": 2.9}]:
		map.set("zoom", float(shot["zoom"]))
		for _frame in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [out_dir, str(shot["name"])]
		if get_viewport().get_texture().get_image().save_png(path) != OK:
			print("CAPTURE_FAILED ", path)
			get_tree().quit(1)
			return
		print("CAPTURED: ", path, "  descent=", map.get("descent"))
	get_tree().quit()
