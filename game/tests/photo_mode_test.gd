extends Node

## Photo mode (item 6): F10 in the Hunt freezes the world, swaps in a free
## camera and hides every HUD layer; leaving puts all three back. The album
## keeps photos newest first. Runs headless (a headless viewport has no
## pixels, so the shutter itself is proven by photo_gallery's windowed shots).

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key(target, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	target._unhandled_input(event)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _f in 5:
		await get_tree().physics_frame
	var field_camera: Camera3D = hunt.camera
	key(hunt, KEY_F10)
	var photo: PhotoMode = hunt.photo_mode
	check(photo.active and get_tree().paused, "F10 enters photo mode and freezes the world")
	check(get_viewport().get_camera_3d() == photo.cam and photo.cam != field_camera, "a separate free camera takes over")
	check(not hunt.get_node("HUD").visible, "the HUD is hidden")
	key(photo, KEY_F10)
	check(photo.active, "the press that opened it does not also close it")
	await get_tree().process_frame
	photo.cam.global_position += Vector3(100, 0, 0)
	photo._process(0.016)
	check(photo.cam.global_position.distance_to(hunt.player_body.global_position) <= PhotoMode.RADIUS + 0.01, "the camera stays on its leash")
	key(photo, KEY_F)
	check(photo.filter == 1, "F cycles the filter")
	key(photo, KEY_ESCAPE)
	check(not photo.active and not get_tree().paused, "Escape leaves and unfreezes")
	check(get_viewport().get_camera_3d() == field_camera, "the field camera is current again")
	check(hunt.get_node("HUD").visible, "the HUD comes back")

	PhotoAlbum.dir = "user://photo_mode_test/"
	for old in PhotoAlbum.list():
		DirAccess.remove_absolute(str(old.path))
		DirAccess.remove_absolute(str(old.path).get_basename() + ".json")
	var image := Image.create(16, 9, false, Image.FORMAT_RGB8)
	var first := PhotoAlbum.save(image, {"hour": 9.5, "filter": "NATURAL", "caption": "first"})
	await get_tree().create_timer(0.05).timeout
	var second := PhotoAlbum.save(image, {"hour": 10.0, "filter": "DIGICAM", "caption": "second"})
	var listed := PhotoAlbum.list()
	check(listed.size() == 2 and str(listed[0].path) == second and str(listed[1].path) == first, "the album lists photos newest first")
	check(str(listed[0].meta.get("filter")) == "DIGICAM", "each photo keeps what the camera knew")
	var album := PhotoAlbum.new()
	album.size = Vector2(900, 500)
	add_child(album)
	album.refresh()
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	check(album.handle_input(right) and album.selected == 1, "arrows move through the album")
	for old in listed:
		DirAccess.remove_absolute(str(old.path))
		DirAccess.remove_absolute(str(old.path).get_basename() + ".json")
	print("PHOTO_MODE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
