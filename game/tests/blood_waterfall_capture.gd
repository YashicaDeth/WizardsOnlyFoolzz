extends Node

## Visual proof for the dry falls (blood_waterfall_exit.tscn): from inside the
## culvert, standing at the drain mouth, halfway down the track, and from the
## gorge floor downstream looking back up at the falls.
## Run windowed: ... res://tests/blood_waterfall_capture.tscn -- --out=DIR

const SHOTS := [
	["falls_culvert", Vector3(0.0, 1.0, 7.0), 0.0, -0.10],
	["falls_mouth", Vector3(0.0, 1.0, -3.2), -0.15, -0.34],
	["falls_track", Vector3(13.0, -9.0, -35.0), 1.2, -0.28],
	["falls_downstream", Vector3(-2.0, -19.0, -72.0), PI, 0.16],
]


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	WorldHistory.clear_history()
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	var falls = load("res://blood_waterfall_exit.tscn").instantiate()
	add_child(falls)
	falls.set_physics_process(false)
	for shot in SHOTS:
		falls.player.global_position = shot[1]
		falls.yaw = float(shot[2])
		falls.pitch = float(shot[3])
		falls.player.rotation.y = falls.yaw
		falls.camera.rotation = Vector3(falls.pitch, 0, 0)
		falls._update_hud()
		await _hold(12)
		await _capture("%s/%s.png" % [out_dir, str(shot[0])])
	get_tree().quit()


func _hold(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "CAPTURE_FAILED: ", path)
