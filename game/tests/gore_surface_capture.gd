extends Node

## Where the gore actually lands. Greg photographed two things in the sandbox:
## blood hanging in the air in a stack instead of lying on the floor, and an
## untextured black box floating in the sky.
##
## A headless run says neither, so this drives the sandbox the way he does —
## empty a magazine into every body, blast the room twice, put rounds into a
## wall — and then does two things a screenshot cannot: it photographs the
## floor, the wall and the sky, and it prints the measured placement of every
## surviving mark. `FLOATING` counts splats whose lift off the surface beneath
## them is larger than the z-fight offset they are supposed to have, which is
## the number that was wrong and the number that proves it is not any more.

const DEMO := preload("res://gore_demo.tscn")

## Untyped: a `Node3D`-typed handle cannot reach the sandbox's own fields.
var demo


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	tree.create_timer(180.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))
	await tree.process_frame

	demo = DEMO.instantiate()
	tree.root.add_child(demo)
	tree.current_scene = demo
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _settle(tree, 4)

	# Rounds into every body, from close enough that the spray has somewhere to
	# land other than the body it came out of.
	for entry: Dictionary in demo.bodies:
		var rig := entry["rig"] as BaselineHuman
		if rig == null or not is_instance_valid(rig):
			continue
		var target: Vector3 = rig.global_position + Vector3(0.0, 1.35, 0.0)
		demo.eye = target + (Vector3(demo.eye.x, 0.0, demo.eye.z) - Vector3(target.x, 0.0, target.z)).normalized() * 3.4
		demo.eye.y = 1.68
		_aim(demo.eye, target)
		await _settle(tree, 3)
		for _shot in 4:
			demo._fire()
			await _settle(tree, 2)
		demo._cut()
		await _settle(tree, 4)

	# And a wall, so there is blood that had to climb something.
	demo.eye = Vector3(0.0, 1.68, -20.0)
	_aim(demo.eye, Vector3(0.0, 1.5, -25.6))
	await _settle(tree, 3)
	for _shot in 6:
		demo._fire()
		await _settle(tree, 2)
	demo._explode(Vector3(0.0, 1.2, -24.0), 92.0)
	await _settle(tree, 40)
	await _shoot(tree, out_dir + "/gore_surface_wall.png")

	# Back to the middle for the floor, and let every drop finish its arc.
	demo.eye = Vector3(0.0, 1.68, 8.0)
	_aim(demo.eye, Vector3(0.0, 0.0, -2.0))
	demo._explode(Vector3(0.0, 1.0, -2.0), 92.0)
	await _settle(tree, 20)
	demo._explode(Vector3(3.5, 1.0, -4.0), 92.0)
	await _settle(tree, 120)
	await _shoot(tree, out_dir + "/gore_surface_floor.png")

	# Low and close, which is the angle a floating splat cannot hide from.
	demo.eye = Vector3(0.0, 0.42, 3.0)
	_aim(demo.eye, Vector3(0.0, 0.0, -3.0))
	await _settle(tree, 4)
	await _shoot(tree, out_dir + "/gore_surface_grazing.png")

	# Straight up. If anything is parked in the sky it is in this frame.
	demo.eye = Vector3(0.0, 1.68, 6.0)
	_aim(demo.eye, Vector3(0.0, 40.0, -4.0))
	await _settle(tree, 4)
	await _shoot(tree, out_dir + "/gore_surface_sky.png")

	_report_splats()
	_report_sky()
	tree.quit(0)


## Aim the sandbox's own camera rig. It builds its basis from `yaw`/`pitch` every
## physics frame, so pointing it anywhere means solving for those two.
func _aim(from: Vector3, at: Vector3) -> void:
	var direction := (at - from).normalized()
	demo.pitch = asin(clampf(direction.y, -1.0, 1.0))
	demo.yaw = atan2(-direction.x, -direction.z)


## Each splat, re-measured against the surface actually under it. A mark that is
## doing its job sits within a couple of centimetres of that surface and lies
## along its normal; one that floats does neither.
func _report_splats() -> void:
	var space := demo.get_world_3d().direct_space_state
	var floating := 0
	var tilted := 0
	var worst := 0.0
	var heights := 0.0
	for splat: Node3D in BaselineHuman.splats:
		if not is_instance_valid(splat):
			continue
		var origin := splat.global_transform.origin
		var normal := splat.global_transform.basis.z.normalized()
		heights += origin.y
		var query := PhysicsRayQueryParameters3D.create(origin + normal * 0.25, origin - normal * 0.6)
		query.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			floating += 1
			worst = maxf(worst, origin.y)
			continue
		var lift: float = origin.distance_to(hit.get("position", origin) as Vector3)
		if lift > 0.06:
			floating += 1
			worst = maxf(worst, lift)
		if (hit.get("normal", Vector3.UP) as Vector3).normalized().dot(normal) < 0.9:
			tilted += 1
	var count := BaselineHuman.splats.size()
	print("SPLATS %d // FLOATING %d // TILTED OFF SURFACE %d // WORST LIFT %.3f // MEAN Y %.3f"
		% [count, floating, tilted, worst, heights / maxf(1.0, float(count))])


## Anything drawn with its feet off the ground. The sandbox's tallest real
## geometry is a six-metre wall, so a mesh whose lowest corner clears that is
## either a mistake or in the sky on purpose.
func _report_sky() -> void:
	var airborne := 0
	for node in _all_meshes(demo):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.mesh.get_aabb()
		if box.position.y < 6.5:
			continue
		airborne += 1
		print("  IN THE SKY: %s (%s) at %v size %v parent %s"
			% [mesh.name, mesh.mesh.get_class(), box.position, box.size, mesh.get_parent().name])
	print("SKY GEOMETRY %d" % airborne)


func _all_meshes(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_all_meshes(child))
	return found


func _settle(tree: SceneTree, frames: int) -> void:
	for _frame in frames:
		await tree.physics_frame


func _shoot(tree: SceneTree, path: String) -> void:
	for _frame in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)
