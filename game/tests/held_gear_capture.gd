extends Node3D

## Every grip, photographed from where the player's eye is. The request was
## *"holding fists halfsword and holding it like swords correctly and well
## modelled"*, and whether that has been delivered is a thing you look at.

const GEAR := preload("res://systems/held_gear.gd")

var gear: HeldGear
var camera: Camera3D


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	tree.create_timer(120.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))

	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.045, 0.042, 0.05)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.35, 0.36, 0.42)
	settings.ambient_light_energy = 0.6
	environment.environment = settings
	add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 28, 0)
	key.light_energy = 1.5
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.7, 0.8, 1.0)
	add_child(fill)

	camera = Camera3D.new()
	# FOV 106, which is what INTERFACE_DIRECTION.md says first person is in this
	# game. A weapon that reads at 70 can fall apart at 106, so it is judged at
	# the number it will actually be seen at.
	camera.fov = 106.0
	camera.near = 0.02
	camera.current = true
	add_child(camera)
	camera.global_position = Vector3(0, 0, 0)

	gear = GEAR.new()
	add_child(gear)
	# Roughly where hands sit in a first-person frame: below the eye, ahead of
	# it, tilted up into view.
	# No pose set here on purpose: each grip in `HeldGear.GRIPS` carries its own
	# rest, so what is photographed is the stance the game will actually use.
	await tree.process_frame
	await tree.process_frame

	for step: Array in [
		["", "fists", "held_1_fists"],
		["sword", "one_hand", "held_2_sword_one_hand"],
		["sword", "two_hand", "held_3_sword_two_hand"],
		["sword", "half_sword", "held_4_half_sword"],
		["sword", "murder_stroke", "held_5_murder_stroke"],
		["shotgun", "long_gun", "held_6_shotgun"],
		["sidearm", "pistol", "held_7_sidearm"],
	]:
		gear.take(str(step[0]), str(step[1]))
		await _settle(tree, 4)
		var effect := gear.grip_effect()
		print("%-16s reach %.2f	 %s" % [str(step[1]), float(effect["reach"]), str(effect["damage_type"])])
		await _shoot(tree, "%s/%s.png" % [out_dir, str(step[2])])

	# And one from outside, so the geometry can be judged rather than just the
	# silhouette of it in frame.
	gear.take("sword", "two_hand")
	gear.position = Vector3(0, 0, 0)
	gear.rotation = Vector3(0, 0, 0)
	camera.fov = 42.0
	camera.global_position = Vector3(0.58, 0.26, -0.46)
	camera.look_at(Vector3(0, -0.02, -0.26))
	await _settle(tree, 4)
	await _shoot(tree, out_dir + "/held_8_sword_close.png")

	gear.take("shotgun", "long_gun")
	camera.global_position = Vector3(0.52, 0.28, -0.58)
	camera.look_at(Vector3(0, -0.03, -0.26))
	await _settle(tree, 4)
	await _shoot(tree, out_dir + "/held_9_shotgun_close.png")

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
