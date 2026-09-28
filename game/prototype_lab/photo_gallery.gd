extends Node

## Photo mode in the real Hunt, shot for looking at (item 6). Enters photo
## mode, pulls the camera up and back, takes one photo per filter, then opens
## the album over them. `-- --shots=DIR` writes the viewfinder and the album
## as PNGs and quits. Photos go to user://photo_gallery, never the real album.

var shots := "P:/GameDev/Temp/photo"


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])
	print("CAPTURED: %s/%s.png" % [shots, name])


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(shots)
	get_window().size = Vector2i(1280, 720)
	PhotoAlbum.dir = "user://photo_gallery/"
	for old in PhotoAlbum.list():
		DirAccess.remove_absolute(str(old.path))
		DirAccess.remove_absolute(str(old.path).get_basename() + ".json")
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _f in 90:
		await get_tree().process_frame
	var photo: PhotoMode = hunt.photo_mode
	photo.rigs = hunt._all_rigs()
	photo.location = hunt.HUNT_LOCATION
	photo.enter(hunt.camera, hunt.player_body.global_position)
	photo._yaw += 0.5
	photo.cam.global_position += Vector3(0, 2.2, 0) + photo.cam.global_transform.basis.z * 3.0
	photo._pitch = -0.35
	for _f in 3:
		await get_tree().process_frame
	for index in PhotoMode.FILTERS.size():
		photo.filter = index
		photo._apply_filter()
		# Let the last shutter flash fade out of the viewfinder shot.
		for _f in 40:
			await get_tree().process_frame
		await _snap("viewfinder_%s" % PhotoMode.FILTERS[index].to_lower())
		await photo.shoot()
	photo.exit()
	var layer := CanvasLayer.new()
	layer.layer = 125
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.05, 0.06)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	var album := PhotoAlbum.new()
	album.position = Vector2(90, 60)
	album.size = Vector2(1100, 600)
	layer.add_child(album)
	album.refresh()
	album.selected = 1
	album.queue_redraw()
	for _f in 3:
		await get_tree().process_frame
	await _snap("album")
	get_tree().quit()
