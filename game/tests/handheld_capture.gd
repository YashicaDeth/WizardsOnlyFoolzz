extends Node

## Captures the handheld in each mode. The point of C1 is that the device hosts
## the *real* panels rather than summarising them, so the INDEX and MAP shots
## are the actual World Index and Living Map seen through a cracked aperture.

const HANDHELD := preload("res://systems/handheld_device.gd")


func _seed() -> void:
	WorldHistory.register_subject("inventory", {"items": ["salvaged torque arm", "ceramic sternum (someone else's)", "two litres of tar"]})
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor", "faction": "Unbound",
		"elo": 1000, "status": "awake", "memory": "The derby door opened into Limbo.",
		"anatomy": {"blood_type": "unresolved", "cybernetics": ["salvaged torque arm"]},
		"relations": {"mara_voss": {"kind": "grudge", "strength": 1}},
	})
	WorldHistory.register_subject("mara_voss", {
		"name": "Mara Voss", "kind": "person", "role": "Bone Yard Captain", "faction": "Ashline Wreckers",
		"faction_id": "ashline_wreckers", "elo": 1180, "grudge": 41, "injury": "fractured left clavicle",
		"status": "active", "memory": "You put her into the wall on the second lap.",
		"wounds": ["fractured left clavicle"],
		"anatomy": {"blood_type": "O-RUST", "cybernetics": ["jaw telemetry nail"]},
		"relations": {"player": {"kind": "hunts", "strength": 8}, "ashline_wreckers": {"kind": "command", "strength": 72}},
	})
	WorldHistory.register_subject("ashline_wreckers", {
		"name": "Ashline Wreckers", "kind": "faction", "role": "Road murder syndicate", "threat": "SEVERE",
		"territory": "Bone Yard / Burnt Highway", "doctrine": "Rank is won by remembered impact.",
	})
	WorldHistory.record_event("derby_round_won", {"subject": "player", "rival": "mara_voss"})
	WorldHistory.record_event("rival_injured", {"subject": "mara_voss", "zone": "left clavicle"})
	var survey: Dictionary = {}
	for x in range(-9, 8):
		for y in range(-7, 6):
			if absf(float(x) * 0.55 + float(y) * 0.8) < 4.5:
				survey["%d,%d" % [x, y]] = true
	WorldHistory.register_subject("ashbloom_survey", {"cells": survey.keys()})


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	WorldHistory.clear_history()
	_seed()

	var layer := CanvasLayer.new()
	add_child(layer)
	var device: Control = HANDHELD.new()
	layer.add_child(device)
	device.open_device()
	# Standing inside the Bone Yard transmitter's reach, so the radio has
	# something to receive rather than carrier.
	device.stand_at(Vector2(-150.0, 10.0))

	# Carried parts, so CARRY has objects with provenance rather than an empty
	# tab - taken as if they came off a real body, because that is how they do.
	device.carry.take_chunk({"layer_name": "organ", "organ_id": "heart", "zone": "torso", "subject_id": "mara_voss"})
	device.carry.take_chunk({"layer_name": "cybernetic", "implant": "jaw telemetry nail", "zone": "head", "subject_id": "mara_voss"})
	device.carry.take_chunk({"layer_name": "bone", "zone": "left_arm", "subject_id": "mara_voss"})
	# Playtest reproduction: the first player picked up everything on the ground.
	for _spare in 11:
		device.carry.take_chunk({"layer_name": "skin", "zone": "torso", "subject_id": "mara_voss"})
	for _muscle in 7:
		device.carry.take_chunk({"layer_name": "muscle", "zone": "left_leg", "subject_id": "mara_voss"})
	for _bone in 4:
		device.carry.take_chunk({"layer_name": "bone", "zone": "right_arm", "subject_id": "mara_voss"})
	device.carry.items[0]["age"] = 300.0

	for mode in ["INDEX", "MAP", "RADIO", "CARRY", "WIRE"]:
		device.set_mode(mode)
		if mode == "RADIO":
			device.radio.khz = 88.6
		for _settle in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/handheld_%s.png" % [out_dir, mode.to_lower()]
		if image.save_png(path) != OK:
			print("CAPTURE_FAILED ", path)
			get_tree().quit(1)
			return
		print("CAPTURED: ", path)

	# The wheel, held up over the device.
	device.set_mode("INDEX")
	device.open_radial()
	device.radial.centre = Vector2(640, 360)
	device.radial.pointer = Vector2(640, 360) + Vector2(96, -60)
	for _settle in 30:
		await get_tree().process_frame
	device.radial.pointer = Vector2(640, 360) + Vector2(96, -60)
	device.radial._resolve_highlight()
	device.radial.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var wheel_image := get_viewport().get_texture().get_image()
	if wheel_image.save_png("%s/handheld_radial.png" % out_dir) == OK:
		print("CAPTURED: %s/handheld_radial.png" % out_dir)
	Engine.time_scale = 1.0
	get_tree().quit()
