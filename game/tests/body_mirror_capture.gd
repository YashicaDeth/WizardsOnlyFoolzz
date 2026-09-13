extends Node3D

## B9.1/B9.2. What the mirror actually shows.
##
## The claim under test is "with everything done to it", and the only honest way
## to check it is to damage the rig and photograph the glass without touching
## the mirror at all. Nothing between these two frames is a mirror change: one
## arm is taken off the body, and the mirror is asked for another frame.

const BODY_MIRROR := preload("res://systems/body_mirror.gd")

var out_dir := "P:/GameDev/Temp"
var mirror: SubViewport


func _shot(name: String) -> void:
	mirror.call("request_frame")
	for _settle in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("CAPTURED: ", name)


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(640, 800)
	await get_tree().process_frame

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0a0b08")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("2a2a24")
	environment.ambient_light_energy = 0.8
	env.environment = environment
	add_child(env)

	# The one window of AH1.2, off to the side, so the body is modelled rather
	# than flatly lit.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28, 34, 0)
	key.light_energy = 1.5
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -120, 0)
	fill.light_energy = 0.35
	add_child(fill)

	# The body, standing 1.2m off the glass the way somebody actually stands at a
	# mirror. Facing the wall, so the mirror gets the front of them — which in
	# first person is the half they can never look at.
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("player")
	rig.position = Vector3(0, 0, 1.6)
	# Facing the glass. The rig's forward is -Z and the mirror is at z = 0, so
	# no rotation is the one that faces it — PI turned the body around and had
	# the mirror showing its back, which is the exact half first person can
	# already imply and the opposite of what B9.2 is for.
	rig.rotation.y = 0.0

	mirror = BODY_MIRROR.make(get_world_3d(), Vector2i(640, 800))
	add_child(mirror)
	mirror.call("place", Vector3.ZERO, Vector3(0, 0, 1))
	mirror.call("reflect", Transform3D(Basis(), Vector3(0, 1.45, 1.6)))

	# The glass fills the frame, so what is captured is the mirror's own view and
	# nothing else.
	var layer := CanvasLayer.new()
	add_child(layer)
	var glass := TextureRect.new()
	glass.texture = mirror.get_texture()
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.add_child(glass)

	await get_tree().process_frame
	await _shot("mirror_00_whole")

	# Take the left arm off. Nothing about the mirror is touched below this line.
	for blow in 14:
		rig.hit("left_arm", 22.0, 3.0, "sharp", "", Vector3(1, 0, 0))
	await get_tree().process_frame
	await _shot("mirror_01_after_the_arm")

	# And the head, because B9.2 is the half of this that first person can never
	# show: your own face carrying what happened to it.
	for blow in 3:
		rig.hit("head", 12.0, 2.0, "blunt", "", Vector3(0, 0, 1))
	await get_tree().process_frame
	await _shot("mirror_02_the_face")

	print("MIRROR SHEET DONE")
	get_tree().quit(0)
