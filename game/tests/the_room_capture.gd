extends Node3D

## AH1.1/AH1.2/AH1.5. The room, from inside it.
##
## First person on purpose: the capture is taken from the viewer's own eye, so
## what is photographed is what the player sees. That is the difference between
## a room and a menu background, and it is also the only way to check B9.2 —
## the head is behind this camera, and the only place it appears is the glass.

const THE_ROOM := preload("res://systems/the_room.gd")

var out_dir := "P:/GameDev/Temp"
var room: Node3D
var camera: Camera3D


func _shot(name: String) -> void:
	for _settle in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("CAPTURED: ", name)


func _look(from: Vector3, at: Vector3) -> void:
	camera.position = from
	camera.look_at(at, Vector3.UP)
	var viewer := Transform3D(camera.global_transform.basis, from)
	room.call("observe", viewer)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 800)
	await get_tree().process_frame

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("05060a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("2b2a26")
	environment.ambient_light_energy = 0.55
	env.environment = environment
	add_child(env)

	room = THE_ROOM.new()
	add_child(room)
	await get_tree().process_frame

	# The body standing in it, facing the glass. The room's mirror is on +Z and
	# the rig's forward is -Z, so it is turned to meet it.
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("player")
	rig.position = Vector3(0, 0, 0.55)
	rig.rotation.y = PI

	# B9.2, and the reason it is a segment at all. In first person the camera
	# sits inside the player's own head, so the body has to be culled from the
	# view that is looking out of it — the first frame of this capture was the
	# inside of a skull. Layer 2 carries the player's body: the eye camera
	# drops that layer, the mirror camera keeps every layer, and the only place
	# the player's own body exists for them is the glass.
	await get_tree().process_frame
	# 56 pieces; the build is complete by the frame after `build()`.
	var pieces := rig.find_children("*", "GeometryInstance3D", true, false)
	for piece in pieces:
		(piece as GeometryInstance3D).layers = 1 << 1

	camera = Camera3D.new()
	camera.fov = 66.0
	camera.near = 0.05
	add_child(camera)
	camera.current = true
	camera.cull_mask = 0xFFFFF & ~(1 << 1)

	room.call("hang_mirror", get_world_3d())
	await get_tree().process_frame

	# AH1.5. Standing at the glass, which is where the body is.
	_look(Vector3(0, 1.62, 0.55), Vector3(0, 1.30, 1.85))
	await _shot("room_00_at_the_mirror")

	# AH1.2. The bed and the one window, from the door.
	_look(Vector3(-1.0, 1.62, -1.5), Vector3(-0.6, 0.9, 1.2))
	await _shot("room_01_bed_and_window")

	# AH1.8. Turn to the poster wall.
	_look(Vector3(0.6, 1.62, 0.4), Vector3(-0.2, 1.35, -1.9))
	await _shot("room_02_the_wall")

	# AH1.11. The recursion, from the corner: the whole room and the glass in it.
	_look(Vector3(-1.35, 1.85, -1.55), Vector3(0.1, 1.15, 1.4))
	await _shot("room_03_the_corner")

	print("ROOM SHEET DONE")
	get_tree().quit(0)
