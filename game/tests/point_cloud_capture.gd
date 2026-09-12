extends Node3D

## The five particle tutorials, photographed against Greg's own artwork and
## against a body out of the gore sandbox — because the whole argument for one
## system rather than five is that the same dials do all of it, and that is
## either visible in a row of pictures or it is not true.
##
## Pass `--art=<path>` to point it at a different piece. It reads straight off
## the desktop rather than importing anything into the project: the art folder
## is Greg's, and a capture harness has no business copying a 14MB painting into
## a git repository on its own.

const BASELINE := preload("res://systems/baseline_human.gd")

var cloud: PointCloud
var spirit: PointCloud
var camera: Camera3D
var body: BaselineHuman


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	var art := "C:/Users/Greg/Desktop/Art Collections/powers that be.jpg"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--art="):
			art = argument.trim_prefix("--art=")
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	tree.create_timer(180.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))

	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.02, 0.02, 0.03)
	settings.glow_enabled = true
	settings.glow_intensity = 0.55
	settings.glow_bloom = 0.15
	environment.environment = settings
	add_child(environment)

	camera = Camera3D.new()
	camera.fov = 55.0
	camera.current = true
	add_child(camera)
	camera.global_position = Vector3(0, 0, 6.4)

	await tree.process_frame

	# ---- a picture becomes points.
	var image := Image.load_from_file(art)
	if image == null:
		print("FAILED: could not read ", art)
		tree.quit(1)
		return
	print("art %s  %dx%d" % [art.get_file(), image.get_width(), image.get_height()])
	cloud = PointCloud.new()
	add_child(cloud)
	cloud.from_image(image, 220, Vector2(6.0, 0.0))
	print("points: %d" % cloud.points)
	await _settle(tree, 6)
	await _shoot(tree, out_dir + "/cloud_1_picture.png")

	# ---- "image to visual": the flat thing becomes a relief and turns.
	cloud.set_dial("relief", 1.9)
	cloud.set_dial("spread", 0.02)
	cloud.set_dial("swirl", 0.25)
	await _settle(tree, 24)
	await _shoot(tree, out_dir + "/cloud_2_relief.png")

	# ---- "Glitch Spider": bands torn off on a stepped clock.
	cloud.set_dial("swirl", 0.0)
	cloud.set_dial("relief", 0.7)
	cloud.set_dial("glitch", 0.85)
	await _settle(tree, 10)
	await _shoot(tree, out_dir + "/cloud_3_glitch.png")

	# ---- "3D Matrix": the same field, falling in lanes.
	cloud.set_dial("glitch", 0.0)
	cloud.set_dial("relief", 0.25)
	cloud.set_dial("fall", 0.9)
	cloud.set_dial("fall_span", 7.0)
	await _settle(tree, 30)
	await _shoot(tree, out_dir + "/cloud_4_matrix.png")

	# ---- the radio, standing in for itself: one band of a spectrum pushing
	# the field out and lighting it up.
	cloud.set_dial("fall", 0.25)
	cloud.set_dial("audio_lift", 1.4)
	cloud.set_dial("audio_glow", 2.2)
	cloud.set_dial("audio", 0.85)
	await _settle(tree, 8)
	await _shoot(tree, out_dir + "/cloud_5_audio.png")
	cloud.visible = false

	# ---- "Animated .fbx into Particles": a body out of the gore sandbox,
	# standing there as a spirit. This is the wizard's eye and the insane TV.
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = Vector3(0, -1.0, 0)
	body = BASELINE.new()
	holder.add_child(body)
	body.build("spirit", {"flesh": Color("70201c"), "gore": false, "variation": 3})
	await _settle(tree, 4)

	spirit = PointCloud.new()
	body.add_child(spirit)
	spirit.from_node(body, 42000, Color(0.55, 0.95, 1.0))
	spirit.set_dial("point_size", 0.012)
	spirit.set_dial("size_from_luma", 0.0)
	spirit.set_tint(Color(0.6, 1.0, 1.0, 0.85))
	camera.global_position = Vector3(0, 0.9, 2.6)
	camera.look_at(Vector3(0, 0.75, 0))
	await _settle(tree, 8)
	print("spirit points: %d" % spirit.points)
	await _shoot(tree, out_dir + "/cloud_6_spirit.png")

	# ---- and the spirit coming apart, which is the same two dials again.
	body.visible = false
	spirit.set_dial("spread", 0.06)
	spirit.set_dial("glitch", 0.5)
	spirit.set_dial("presence", 0.55)
	spirit.set_field(Vector3(0, 1, 0), Vector3(0, 0.9, 0))
	spirit.set_dial("swirl", 0.8)
	await _settle(tree, 20)
	await _shoot(tree, out_dir + "/cloud_7_spirit_apart.png")

	tree.quit(0)


func _settle(tree: SceneTree, frames: int) -> void:
	for _frame in frames:
		await tree.process_frame


func _shoot(tree: SceneTree, path: String) -> void:
	for _frame in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)
