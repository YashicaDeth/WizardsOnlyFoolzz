extends Node3D

## AH1.5 diagnostic. Why the rig does not appear in the room's glass.
##
## Squinting at renders was not isolating it, so this asks the camera directly:
## where is it, where is it pointed, what can it cull, and is the body inside
## its frustum at all.

const THE_ROOM := preload("res://systems/the_room.gd")


func _ready() -> void:
	var room: Node3D = THE_ROOM.new()
	add_child(room)
	await get_tree().process_frame

	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("player")
	rig.position = Vector3(0, 0, 0.55)
	rig.rotation.y = PI
	await get_tree().process_frame
	var pieces := rig.find_children("*", "GeometryInstance3D", true, false)
	for piece in pieces:
		(piece as GeometryInstance3D).layers = 1 << 1

	var mirror: SubViewport = room.call("hang_mirror", get_world_3d())
	var viewer := Transform3D(Basis(), Vector3(0, 1.62, 0.55))
	viewer.basis = Basis.looking_at(Vector3(0, -0.32, 1.30), Vector3.UP)
	room.call("observe", viewer)
	await get_tree().process_frame

	var camera: Camera3D = mirror.camera
	print("--- the mirror camera ---")
	print("  position        ", camera.global_position)
	print("  looking toward  ", -camera.global_transform.basis.z)
	print("  near / far      ", camera.near, " / ", camera.far)
	print("  cull_mask       ", camera.cull_mask, "  (binary ", String.num_int64(camera.cull_mask, 2), ")")
	print("  body layer bit  ", 1 << 1, " included: ", (camera.cull_mask & (1 << 1)) != 0)
	print("  viewport size   ", mirror.size, "  update mode ", mirror.render_target_update_mode)

	print("--- the body ---")
	var head := rig.global_position + Vector3(0, 1.60, 0)
	var chest := rig.global_position + Vector3(0, 1.25, 0)
	var feet := rig.global_position + Vector3(0, 0.15, 0)
	for named in [["head", head], ["chest", chest], ["feet", feet]]:
		var point: Vector3 = named[1]
		var distance := camera.global_position.distance_to(point)
		print("  %-6s at %s  distance %.2f  beyond near: %s  in frustum: %s" % [
			str(named[0]), str(point), distance, str(distance > camera.near),
			str(camera.is_position_in_frustum(point))])

	print("--- the pieces ---")
	print("  count ", pieces.size())
	var visible_count := 0
	var layer_ok := 0
	for piece in pieces:
		var geometry := piece as GeometryInstance3D
		if geometry.visible and geometry.is_visible_in_tree():
			visible_count += 1
		if (geometry.layers & camera.cull_mask) != 0:
			layer_ok += 1
	print("  visible in tree        ", visible_count)
	print("  passing the cull mask  ", layer_ok)
	var first := pieces[0] as GeometryInstance3D
	print("  first piece            ", first.name, "  layers ", first.layers, "  global ", first.global_position)
	print("  its aabb               ", first.get_aabb())

	# Everything above says the body should be in the glass. So show the
	# viewport's own texture full frame: if the body is there, the fault is in
	# the surface that displays it, not in the reflection.
	var out_dir := "P:/GameDev/Temp/room"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(768, 720)
	var layer := CanvasLayer.new()
	add_child(layer)
	var glass := TextureRect.new()
	glass.texture = mirror.get_texture()
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(glass)
	for _settle in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/diag_raw_mirror.png" % out_dir)
	print("CAPTURED: diag_raw_mirror")
	get_tree().quit(0)
