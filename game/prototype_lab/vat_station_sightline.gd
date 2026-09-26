extends Node

## Look-check for the examination station: the man, his desk and his terminal,
## framed from outside the tank.
##
## Filing the intake is what puts the examiner at his post and opens the room,
## so that is what this does. The chamber's own camera is the player's eye at 88
## degrees inside a dark tank, which frames the workstation too loosely to
## judge, so it is freed and replaced with a fixed look-check camera square to
## the post. These are look-check frames: they are about the geometry of the
## workstation and claim nothing about gameplay framing or staging.

var out_dir := "P:/GameDev/Temp"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()

	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame

	# Filing opens his departure from the terminal, with him standing at it.
	var state: Dictionary = vat.intake.sheet.apply_to_world()
	vat.intake.filed.emit(state)
	for _frame in 8:
		await get_tree().process_frame

	var station := vat.get_node("UnknownExaminerStation") as Node3D
	var post: Vector3 = station.to_global(Vector3(vat.EXAMINER_AT_DESK.x, 0.0, vat.EXAMINER_AT_DESK.z))
	# Square to the post, across the line running from the tank to the station:
	# any offset along that line walks into the tank or behind the glass.
	var to_tank := Vector3(-post.x, 0.0, -post.z).normalized()
	var side := Vector3(-to_tank.z, 0.0, to_tank.x)
	var aim := post + Vector3(0.0, 1.10, 0.0)

	# The chamber's own camera is moved rather than replaced. Adding a second
	# camera does not win: two different transforms came back byte-identical
	# from this scene, which means the viewport kept rendering the camera it
	# already had. The chamber's loop is also stopped, or it puts the examiner
	# back at his door and re-aims the camera before the shot.
	vat.set_process(false)
	vat.set_physics_process(false)
	var look := vat.camera
	look.fov = 50.0
	look.global_position = post + side * 2.5 + Vector3(0.0, 1.45, 0.0)
	look.look_at(aim, Vector3.UP)
	look.current = true
	for _frame in 3:
		await get_tree().process_frame
	await _capture("%s_vat_station_at_post.png" % out_dir)

	# And the mirrored angle, so the workstation is judged from both sides
	# rather than from one flattering spot.
	look.global_position = post - side * 2.5 + Vector3(0.0, 1.45, 0.0)
	look.look_at(aim, Vector3.UP)
	for _frame in 3:
		await get_tree().process_frame
	await _capture("%s_vat_station_mirrored.png" % out_dir)
	get_tree().quit(0)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)
