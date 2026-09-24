extends Node

const FACILITY := preload("res://systems/facility_territory.gd")
const MAP := preload("res://systems/living_map.gd")


func _ready() -> void:
	var out_dir := "res://captures"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	WorldHistory.clear_history()
	FACILITY.apply_event("opening_woke")
	FACILITY.apply_event("opening_entered_pit")
	FACILITY.apply_event("derby_round_won")

	var map := MAP.new()
	map.name = "CellOutzTargetAreaEvidence"
	map.size = Vector2(1280, 720)
	add_child(map)
	map.observe(Vector3(-132, 0, 18), 0.32)
	map.open_map()
	map.facility_sheet = false
	map.zoom = 1.55
	map.clock = 1.8
	for _settle in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var arriving := get_viewport().get_texture().get_image()
	var arriving_path := "%s/ashbloom_holding_reveal.png" % out_dir
	if arriving.save_png(arriving_path) != OK:
		print("CAPTURE_FAILED ", arriving_path)
		get_tree().quit(1)
		return
	print("CAPTURED: ", arriving_path)
	for _settle in 100:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var settled := get_viewport().get_texture().get_image()
	var settled_path := "%s/celloutz_target_area.png" % out_dir
	if settled.save_png(settled_path) != OK:
		print("CAPTURE_FAILED ", settled_path)
		get_tree().quit(1)
		return
	print("CAPTURED: ", settled_path)
	get_tree().quit()
