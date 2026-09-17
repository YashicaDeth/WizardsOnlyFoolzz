extends Node3D

const HANDHELD := preload("res://systems/handheld_device.gd")

## LivingMap's ordinary region binding reads this authored footprint list.
## The proof scene has no buildings, but it still exposes the real contract.
var lots: Array = []

## AE10.11/AK10.12 visual proof: MAP keeps remembered survey ink underground,
## but the live orbital photograph, minimap and player fix are gone.

func _ready() -> void:
	var out_path := "res://captures/underground_satellite_occluded.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var cells: Array[String] = []
	for x in range(-8, 9):
		for y in range(-6, 7):
			cells.append("%d,%d" % [x, y])
	WorldHistory.register_subject("ashbloom_survey", {"cells": cells})
	var layer := CanvasLayer.new()
	add_child(layer)
	var device: Control = HANDHELD.new()
	layer.add_child(device)
	await get_tree().process_frame
	device.bind(self, null, Callable())
	device.open_device()
	device.set_mode("MAP")
	device._advance_page_transition(device.PAGE_TRANSITION_SECONDS)
	device.stand_at(Vector2(135.0, 40.0))
	for _settle in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(out_path)
	print("UNDERGROUND_SATELLITE_CAPTURE_RESULT path=", out_path, " result=", result)
	get_tree().quit(0 if result == OK else 1)
