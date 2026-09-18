extends Node

## The gore sandbox, photographed. Headless cannot render, so a passing test
## says the anatomy resolved and says nothing at all about whether the room
## looks like anything. This drives the scene the way a player would — stand
## there, shoot one, blast the rest, hold the slow, open a body up — and takes
## the picture at each step.

const DEMO := preload("res://gore_demo.tscn")

## Untyped on purpose: a `Node3D`-typed handle cannot see the sandbox fields.
var demo


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	tree.create_timer(120.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))
	await tree.process_frame

	demo = DEMO.instantiate()
	tree.root.add_child(demo)
	tree.current_scene = demo
	# The sandbox grabs the mouse on the way in, which is correct when a person
	# opened it and rude when a script did.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await tree.physics_frame
	await tree.physics_frame

	# Stand where you can see the ring of them.
	demo.eye = Vector3(0.0, 1.68, 7.0)
	demo.yaw = 0.0
	demo.pitch = -0.06
	await _settle(tree, 6)
	await _shoot(tree, out_dir + "/gore_demo_room.png")

	# Put one of the actual anatomy bodies inside reach and take it into the
	# shared captive pose. This proves C is teaching a physical clinch now, not
	# toggling an unrelated menu state.
	var grapple_holder := (demo.bodies[0] as Dictionary).get("holder") as Node3D
	grapple_holder.global_position = Vector3(demo.eye.x, 0.9, demo.eye.z - 1.5)
	demo._begin_grapple(0)
	await _settle(tree, 5)
	await _shoot(tree, out_dir + "/gore_sandbox_grapple.png")
	demo._release_grapple()

	# The training room now speaks the same firearm language as the Hunt. Hold
	# aim long enough for the lens and viewmodel to settle, then photograph the
	# live stance readout rather than relying on a unit assertion alone.
	demo.firearm_aiming = true
	await _settle(tree, 12)
	await _shoot(tree, out_dir + "/gore_sandbox_aim.png")
	demo.firearm_aiming = false

	# Capture the middle of an actual paid sidestep. The displaced viewpoint and
	# DODGE stance are the visual evidence that this is movement, not a label.
	demo.stamina = 100.0
	demo.dodge_cooldown = 0.0
	demo.vertical_velocity = 0.0
	demo._begin_dodge(Vector3.RIGHT)
	await _settle(tree, 3)
	await _shoot(tree, out_dir + "/gore_sandbox_dodge.png")

	# The same range bodies, switched live from passive anatomy targets into a
	# closing combat drill. Capture the production control and the advancing
	# bodies together so the mode is not verified by label alone.
	demo._set_enemies_enabled(true)
	await _settle(tree, 22)
	await _shoot(tree, out_dir + "/gore_sandbox_enemy_mode.png")
	demo._set_enemies_enabled(false)

	# One shot, aimed at the nearest body, so there is a wound before there is
	# a crater.
	demo.yaw = 0.55
	demo.pitch = -0.02
	await _settle(tree, 4)
	demo._fire()
	await _settle(tree, 10)
	await _shoot(tree, out_dir + "/gore_demo_shot.png")

	# Then the thing it is named after.
	var centre: Vector3 = (demo.bodies[0] as Dictionary)["rig"].global_position
	demo._explode(centre + Vector3(0, 1.0, 0), 92.0)
	await _settle(tree, 3)
	await _shoot(tree, out_dir + "/gore_demo_blast.png")
	await _settle(tree, 50)
	await _shoot(tree, out_dir + "/gore_demo_after.png")

	# And what is inside whatever is left.
	demo._set_xray(true)
	await _settle(tree, 8)
	await _shoot(tree, out_dir + "/gore_demo_xray.png")

	print("standing %d / %d, on the floor %d, taken off %d"
		% [_standing(), demo.BODY_COUNT, GoreChunks.live_count(), demo.severed_total])
	tree.quit(0)


func _standing() -> int:
	var count := 0
	for entry: Dictionary in demo.bodies:
		var rig := entry["rig"] as BaselineHuman
		if rig != null and is_instance_valid(rig) and not rig.anatomy.dead:
			count += 1
	return count


func _settle(tree: SceneTree, frames: int) -> void:
	for _frame in frames:
		await tree.physics_frame


func _shoot(tree: SceneTree, path: String) -> void:
	for _frame in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)
