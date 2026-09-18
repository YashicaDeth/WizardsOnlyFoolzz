extends Node

## Visual proof for the recovery pass: the actual underground venue from the
## playable cab, with the enclosing roof in frame and the real escape contract
## on the live HUD.

func _ready() -> void:
	var out_path := "res://captures/opening_underground_colosseum.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var derby: Node = load("res://underground_colosseum.tscn").instantiate()
	add_child(derby)
	await get_tree().physics_frame
	for target: Node in derby.targets.duplicate():
		if is_instance_valid(target):
			target.queue_free()
	derby.targets.clear()
	derby.round_state = "active"
	derby.countdown = 0.0
	derby.lockdown_briefing = 5.0
	derby.boat.freeze = true
	derby.boat.position = Vector3(0, 0.8, COLOSSEUM_VIEW_Z)
	derby.boat.rotation.y = PI
	derby.aim_pitch = -0.22
	derby._update_cab_camera(1.0)
	derby._update_hud()
	for _frame in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(out_path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", out_path)
	get_tree().quit(0 if error == OK else 1)


const COLOSSEUM_VIEW_Z := 28.0
