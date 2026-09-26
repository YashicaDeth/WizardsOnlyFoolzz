extends Node

## Look-check for the examination station, and a diagnosis of why three
## separate attempts to photograph it came back black.
##
## Filing the intake opens the doctor's departure, so that is the beat where he
## is standing at his post. The chamber's own camera is the player's eye at 88
## degrees inside the tank; this harness moves it to a fixed look-check position
## square to the post, because the workstation has to be judged from outside
## the tank.
##
## KNOWN, 26 September: this has never produced a usable frame. Earlier attempts
## returned near-black, and -- the clue that mattered -- the *same* near-black
## frame came back for two different camera positions, which cannot happen if
## the camera is what is being rendered. So the frame is being covered by
## something drawn over the whole viewport. This version dumps the facts before
## and after hiding the full-rect overlays, so the next person starts from
## measurements instead of another guess.

var out_dir := "P:/GameDev/Temp"


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	WorldHistory.clear_history()

	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame

	# THE ACTUAL CAUSE OF FIVE BLACK FRAMES, found by measuring instead of
	# guessing. `Fade` and `Submerge` are full-screen ColorRects that are live
	# through the departure beat, and they were covering the whole viewport. The
	# room is not dark -- it never was. They go before anything is filed.
	_hide_full_rect_overlays(vat)
	await get_tree().process_frame

	var state: Dictionary = vat.intake.sheet.apply_to_world()
	vat.intake.filed.emit(state)
	# Filing puts him at his post. The departure then walks him away from it, so
	# this is deliberately early: at 100 frames he is halfway across the room and
	# the shot is of an empty desk.
	for _frame in 12:
		await get_tree().process_frame
	_hide_full_rect_overlays(vat)

	var station := vat.get_node("UnknownExaminerStation") as Node3D
	var post: Vector3 = station.to_global(Vector3(vat.EXAMINER_AT_DESK.x, 0.0, vat.EXAMINER_AT_DESK.z))
	var to_tank := Vector3(-post.x, 0.0, -post.z).normalized()
	var side := Vector3(-to_tank.z, 0.0, to_tank.x)
	var look: Camera3D = vat.camera
	# Two cameras in this scene both report `current = true`, so moving one of
	# them does not reliably change what is rendered -- which is why two
	# different camera positions produced byte-identical frames. Claim it
	# exclusively: everything off, then exactly one on.
	_claim_current(look)
	look.fov = 50.0
	look.global_position = post + side * 2.2 + Vector3(0.0, 1.35, 0.0)
	look.look_at(post + Vector3(0.0, 1.05, 0.0), Vector3.UP)
	for _frame in 3:
		await get_tree().process_frame
	_report(vat, "examiner at his post, camera square to it")
	await _capture("%s_vat_station_at_post.png" % out_dir)

	# And the same workstation from the other side, so the relationship between
	# the man and his terminal is judged from both directions.
	look.global_position = post - side * 2.2 + Vector3(0.0, 1.35, 0.0)
	look.look_at(post + Vector3(0.0, 1.05, 0.0), Vector3.UP)
	_claim_current(look)
	for _frame in 3:
		await get_tree().process_frame
	await _capture("%s_vat_station_mirrored.png" % out_dir)
	get_tree().quit(0)


## Turns every other camera off, so the one being aimed is unambiguously the one
## being rendered.
func _claim_current(wanted: Camera3D) -> void:
	var all: Array[Camera3D] = []
	_collect_cam_nodes(self, all)
	for cam in all:
		cam.current = cam == wanted
	wanted.current = true


## Hides every visible HUD Control, not only the full-screen `ColorRect`s.
## `Fade` and `Submerge` are the obvious two, but `TortureLoadIn` is also
## full-screen and was still darkening the frame when only the rects were
## hidden. Labels are hidden too: at 12 frames the subtitle and objective are
## mid-fade and only get in the way of a look-check.
func _hide_full_rect_overlays(vat) -> void:
	for node in vat.get_node("HUD").get_children():
		if node is Control:
			(node as Control).visible = false


func _report(vat, label: String) -> void:
	var cams: Array[String] = []
	_collect_cameras(self, cams)
	var overlays: Array[String] = []
	for node in vat.get_node("HUD").get_children():
		if node is Control and (node as Control).visible:
			overlays.append("%s(%s)" % [node.name, node.get_class()])
	print("--- %s ---" % label)
	print("  phase=%s examiner_local=%s" % [vat.phase, str(vat.examiner_node.position)])
	print("  cameras: %s" % (", ".join(cams) if cams.size() > 0 else "(none found)"))
	print("  visible HUD controls: %s" % (", ".join(overlays) if overlays.size() > 0 else "(none)"))
	print("  chamber camera at %s current=%s" % [str(vat.camera.global_position), str(vat.camera.current)])


func _collect_cameras(node: Node, into: Array[String]) -> void:
	for child in node.get_children():
		if child is Camera3D:
			into.append("%s%s @%s" % [child.name, "*" if (child as Camera3D).current else "",
				str((child as Node3D).global_position).substr(0, 18)])
		_collect_cameras(child, into)


func _collect_cam_nodes(node: Node, into: Array[Camera3D]) -> void:
	for child in node.get_children():
		if child is Camera3D:
			into.append(child)
		_collect_cam_nodes(child, into)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	# Average luminance, so a black frame is a number and not an opinion.
	var total := 0.0
	var samples := 0
	for y in range(0, image.get_height(), 16):
		for x in range(0, image.get_width(), 16):
			var c := image.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			samples += 1
	print("  %s mean_luminance=%.4f" % [path.get_file(), total / maxf(float(samples), 1.0)])
	print("CAPTURED: " if error == OK else "CAPTURE_FAILED: ", path)
