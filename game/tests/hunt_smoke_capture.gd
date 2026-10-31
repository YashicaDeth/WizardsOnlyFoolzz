extends Node

## drug-70 PROOF in the real Hunt. Windowed only (headless draws nothing):
##   P:/GameDev/AgentHub/render_one.cmd hunt_smoke_capture --shots=P:/GameDev/Temp/drug70_hunt
## A joint drawn and breathed out through the Hunt's own smoking methods, shot
## from the first-person view and from the side, 0.5 / 1.2 / 2.4 s after the
## breath leaves. Pass "volume" is the simulated SmokeVolume (the default);
## pass "puffs" is the old ContaminatedAir particles, for comparison.

var shots := "P:/GameDev/Temp/drug70_hunt"
var hunt: Node
var side: Camera3D


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	await get_tree().process_frame
	WorldHistory.clear_history()
	hunt = load("res://bone_yard_hunt.tscn").instantiate()
	get_tree().root.add_child(hunt)
	get_tree().current_scene = hunt
	await _frames(75)
	hunt.set("third_person", false)
	hunt.set("perspective_blend", 0.0)
	hunt.get("body_motion").set_perspective(true)
	print("clock %s  daylight %.2f" % [WorldClock.stamp(), WorldClock.daylight()])
	for pass_name in ["volume", "puffs"]:
		hunt.set("smoke_volume_enabled", pass_name == "volume")
		await _breath(pass_name)
	print("HUNT_SMOKE_CAPTURE_DONE %s" % shots)
	get_tree().quit()


func _breath(pass_name: String) -> void:
	hunt.call("_equip_smokeable", "joint")
	await _frames(20)
	hunt.call("_begin_smoking_draw")
	await _seconds(1.1)
	hunt.call("_finish_smoking_draw")
	var pose: Dictionary = hunt.call("_smoke_emission_pose")
	var mouth: Vector3 = pose.mouth
	var forward: Vector3 = pose.forward
	var across := forward.cross(Vector3.UP).normalized()
	var eye := get_viewport().get_camera_3d()
	if side == null:
		side = Camera3D.new()
		side.fov = 55.0
		add_child(side)
	side.global_position = mouth + across * 1.6 + forward * 0.7 + Vector3.UP * 0.15
	side.look_at(mouth + forward * 0.8 + Vector3.UP * 0.2, Vector3.UP)
	# The breath leaves after the Hunt's own short hold at the lips.
	await _seconds(0.3)
	var t := 0.0
	for stamp in [0.5, 1.2, 2.4]:
		await _seconds(stamp - t)
		t = stamp
		await _save("%s_fp_%s" % [pass_name, str(stamp).replace(".", "")])
		side.current = true
		await _frames(1)
		await _save("%s_side_%s" % [pass_name, str(stamp).replace(".", "")])
		if eye != null:
			eye.current = true
	var volume = hunt.get("smoke_volume")
	print("%s  parcels %d" % [pass_name, volume.count() if volume != null else 0])
	await _seconds(3.0)


func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(shot_name + ".png"))


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
