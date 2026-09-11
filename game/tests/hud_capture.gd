extends Node

## Captures the rebuilt derby HUD on its own, without running a heat. The old
## one was judged from a play screenshot and the corners are the point, so the
## harness supplies telemetry that puts every instrument in a readable state:
## a damaged hull, a live rival with a real grudge, and a pit full of contacts.

const HUD := preload("res://systems/celloutz_hud.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var layer := CanvasLayer.new()
	add_child(layer)
	var hud: Control = HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	hud.show_title = false

	var rng := RandomNumberGenerator.new()
	rng.seed = 90211
	var contacts: Array = []
	for index in 9:
		contacts.append({
			"offset": Vector2(rng.randf_range(-34, 34), rng.randf_range(-34, 34)),
			"integrity": rng.randi_range(18, 100),
			"rival": index == 2,
		})
	hud.set_telemetry({
		"speed": 17.4, "score": 2380, "integrity": 61, "active_wreckers": 9,
		"memory_count": 47, "rival_status": "HUNTING", "rival_grudge": 64,
		"rival_elo": 1180, "contacts": contacts, "arena_limit": 40.0,
	})
	hud.announce_impact(12, true)

	# Settle the eased readouts so the numbers shown are the numbers sent.
	for _settle in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/hud.png" % out_dir
	if image.save_png(path) != OK:
		print("CAPTURE_FAILED")
		get_tree().quit(1)
		return
	print("CAPTURED: ", path)
	get_tree().quit()
