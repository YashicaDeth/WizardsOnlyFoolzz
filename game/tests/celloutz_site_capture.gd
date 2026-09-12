extends Node

## I3.2. celloutz.xyz, seen the way a player actually would: opened from the
## WIRE page while standing in range of the Ossuary terminal.

const WORLD_INDEX := preload("res://systems/world_index.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	var layer := CanvasLayer.new()
	add_child(layer)
	var index: Control = WORLD_INDEX.new()
	layer.add_child(index)
	index.size = Vector2(1280, 720)
	index.open()
	index.page = index.PAGES.find("WIRE")
	index.current_emitter_id = "ossuary_terminal"
	for _settle in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var wire_image := get_viewport().get_texture().get_image()
	wire_image.save_png("%s/wire_sites_in_range.png" % out_dir)
	print("CAPTURED: %s/wire_sites_in_range.png" % out_dir)

	# Click the storefront link directly rather than simulating a mouse event
	# at a coordinate that would drift with layout - the link list itself is
	# the thing under test, not pixel-picking.
	for link: Dictionary in index._link_rects:
		if str(link.get("kind", "")) == "site" and str(link.get("id", "")) == "celloutz_store":
			index._follow_link(link)
	for _settle in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var site_image := get_viewport().get_texture().get_image()
	site_image.save_png("%s/celloutz_storefront.png" % out_dir)
	print("CAPTURED: %s/celloutz_storefront.png" % out_dir)
	get_tree().quit()
