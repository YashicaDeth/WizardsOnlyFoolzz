extends Node

## Captures the Living Map so the bezel, the place markers and the travel panel
## can be reviewed. No Hunt Grounds: the map reads its survey out of
## `WorldHistory` and its districts out of a constant, so it draws standalone.

const LIVING_MAP := preload("res://systems/living_map.gd")


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	WorldHistory.clear_history()
	# Survey a band of ground, so the chart shows both walked and withheld cells
	# and the place panel has something to say either way.
	var survey: Dictionary = {}
	for x in range(-9, 8):
		for y in range(-7, 6):
			if absf(float(x) * 0.55 + float(y) * 0.8) < 4.5:
				survey["%d,%d" % [x, y]] = true
	WorldHistory.register_subject("ashbloom_survey", {"cells": survey.keys()})

	var layer := CanvasLayer.new()
	add_child(layer)
	var map: Control = LIVING_MAP.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(map)
	map.open_map()
	map.observe(Vector3(-40, 0, 30), 0.7)
	map.selected_place = 2  # The Bone Yard, inside the surveyed band.
	map.hovered_place = 4
	map.travel_hold = 0.55

	for _settle in 20:
		await get_tree().process_frame
	# `_process` bleeds the hold back down when T is not held, so it is restored
	# immediately before the shutter rather than fought with.
	map.travel_hold = 0.55
	map.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/map.png" % out_dir
	if image.save_png(path) != OK:
		print("CAPTURE_FAILED")
		get_tree().quit(1)
		return
	print("CAPTURED: ", path)
	get_tree().quit()
