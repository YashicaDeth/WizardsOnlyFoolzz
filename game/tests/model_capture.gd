extends Node3D
## A generated model, looked at: on a turntable with its anchors marked, in the
## Hunt's first-person hand, or in the hub body's fist.
##   Godot --path game res://tests/model_capture.tscn -- --mode=turntable \
##       --weapon=breach_nine --out=P:/GameDev/Temp/model
##   --mode=hunt     first person, facility sidearm acquired in the real Hunt
##   --mode=hub      VatBodyPreview holding `--weapon` (facility_sidearm)
##   --mode=prop     `--scene-node=res://systems/x.gd` is not needed: use
##                   --glb=res://art/generated/props/cctv.glb for a bare model

var out_dir := "P:/GameDev/Temp/model"
var mode := "turntable"
var weapon := "breach_nine"
var glb := ""
var hour := 13.0
var slot := -1


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--weapon="):
			weapon = argument.trim_prefix("--weapon=")
		elif argument.begins_with("--glb="):
			glb = argument.trim_prefix("--glb=")
		elif argument.begins_with("--hour="):
			hour = float(argument.trim_prefix("--hour="))
		elif argument.begins_with("--slot="):
			slot = int(argument.trim_prefix("--slot="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	tree.create_timer(150.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))
	match mode:
		"hunt":
			await _hunt(tree)
		"hub":
			await _hub(tree)
		"prop":
			await _prop(tree)
		"stats":
			_stats()
		_:
			await _turntable(tree)
	tree.quit(0)


func _stage(background := Color(0.06, 0.055, 0.065)) -> Camera3D:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = background
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.4, 0.4, 0.46)
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 28, 0)
	key.light_energy = 1.6
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.6
	add_child(fill)
	var camera := Camera3D.new()
	camera.current = true
	add_child(camera)
	return camera


func _turntable(tree: SceneTree) -> void:
	var camera := _stage()
	var gear := HeldGear.build_weapon(weapon)
	add_child(gear)
	var markers := {"anchor_grip": Color(0, 1, 0), "anchor_grip_support": Color(0, 0.6, 1), "anchor_muzzle": Color(1, 0.1, 0.1)}
	for anchor_name: String in markers:
		var anchor := gear.get_node_or_null(anchor_name) as Node3D
		if anchor == null:
			print("MISSING ", anchor_name)
			continue
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.008
		sphere.height = 0.016
		var material := StandardMaterial3D.new()
		material.albedo_color = markers[anchor_name]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		sphere.material = material
		ball.mesh = sphere
		anchor.add_child(ball)
		print("ANCHOR %s at %s" % [anchor_name, anchor.position])
	var box := _bounds(gear)
	print("BOUNDS centre=%s size=%s (muzzle should be +Z)" % [box.get_center(), box.size])
	var centre := box.get_center()
	var reach := maxf(box.size.length(), 0.1) * 1.15
	camera.fov = 40.0
	for shot: Array in [["side", Vector3(1, 0.1, 0)], ["top", Vector3(0.001, 1, 0.001)], ["front3q", Vector3(0.7, 0.35, 0.8)], ["back3q", Vector3(-0.7, 0.35, -0.8)]]:
		camera.global_position = centre + (shot[1] as Vector3).normalized() * reach
		camera.look_at(centre, Vector3.UP)
		await _shoot(tree, "%s/%s_%s.png" % [out_dir, weapon, shot[0]])


func _hunt(tree: SceneTree) -> void:
	WorldHistory.clear_history()
	WorldHistory.world_minute = hour * WorldClock.MINUTES_PER_HOUR
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _frame in 90:
		await tree.process_frame
	var arsenal: Node = hunt.arsenal
	# The Hunt is dusk-dark and the hand sits in the player's own shadow; a lamp
	# on the camera lights the weapon so it can be judged at all.
	var lamp := OmniLight3D.new()
	lamp.light_energy = 5.0
	lamp.omni_range = 4.0
	lamp.shadow_enabled = false
	(hunt.camera as Camera3D).add_child(lamp)
	lamp.position = Vector3(0.1, -0.1, -0.2)
	if slot >= 0:
		print("SLOT ", slot, " ", arsenal.select_slot(slot), " current=", arsenal.current_id)
	else:
		print("ACQUIRED ", arsenal.acquire_facility_sidearm(12), " current=", arsenal.current_id)
	for _frame in 20:
		await tree.process_frame
	var model := arsenal.models.get(arsenal.current_id) as Node3D
	if model != null:
		var cam := hunt.camera as Camera3D
		var muzzle := model.find_child("anchor_muzzle", true, false) as Node3D
		var grip := model.find_child("anchor_grip", true, false) as Node3D
		if muzzle != null and grip != null:
			var direction := cam.global_transform.basis.inverse() * (muzzle.global_position - grip.global_position)
			print("HUNT %s muzzle-from-grip in camera space = %s  (camera -Z is forward; length %.3f)" % [arsenal.current_id, direction.snapped(Vector3.ONE * 0.001), direction.length()])
	var tag := "slot%d" % slot if slot >= 0 else "facility"
	await _shoot(tree, "%s/hunt_%s.png" % [out_dir, tag])
	if slot < 0:
		arsenal.reload()
		for _frame in 14:
			await tree.process_frame
		await _shoot(tree, "%s/hunt_%s_reload.png" % [out_dir, tag])


func _hub(tree: SceneTree) -> void:
	var preview := VatBodyPreview.new()
	preview.custom_minimum_size = Vector2(640, 720)
	preview.size = Vector2(640, 720)
	var holder := Control.new()
	add_child(holder)
	holder.add_child(preview)
	await tree.process_frame
	preview.present({})
	for _frame in 6:
		await tree.process_frame
	preview.hold("facility_sidearm" if weapon == "breach_nine" else weapon)
	preview.held = true
	for _frame in 12:
		await tree.process_frame
	await _shoot(tree, "%s/hub_%s.png" % [out_dir, weapon])
	# Side close-up on the fist: which way it points, where it sits in the hand.
	preview.set_process(false)
	var held_weapon := preview.rig.parts["right_arm"].get_node("HeldWeapon") as Node3D
	var hub_muzzle := held_weapon.find_child("anchor_muzzle", true, false) as Node3D
	var hub_grip := held_weapon.find_child("anchor_grip", true, false) as Node3D
	if hub_muzzle != null and hub_grip != null:
		var hub_direction := preview.rig.global_transform.basis.inverse() * (hub_muzzle.global_position - hub_grip.global_position)
		print("HUB %s muzzle-from-grip in body space = %s (body forward is -Z; length %.3f)" % [weapon, hub_direction.snapped(Vector3.ONE * 0.001), hub_direction.length()])
	var look := held_weapon.global_position
	var lamp := OmniLight3D.new()
	lamp.light_energy = 3.0
	lamp.omni_range = 3.0
	preview.stage.add_child(lamp)
	for view: Array in [["side", Vector3(1, 0.15, 0)], ["front", Vector3(0, 0.15, 1)]]:
		preview.camera.global_position = look + (view[1] as Vector3).normalized() * 0.55
		preview.camera.look_at(look, Vector3.UP)
		lamp.global_position = preview.camera.global_position + Vector3(0, 0.2, 0)
		for _frame in 4:
			await tree.process_frame
		await _shoot(tree, "%s/hub_%s_%s.png" % [out_dir, weapon, view[0]])


func _prop(tree: SceneTree) -> void:
	var camera := _stage()
	var scene: PackedScene = load(glb)
	var model := scene.instantiate() as Node3D
	add_child(model)
	var box := _bounds(model)
	print("BOUNDS %s centre=%s size=%s" % [glb.get_file(), box.get_center(), box.size])
	var reach := maxf(box.size.length(), 0.1) * 1.3
	camera.fov = 40.0
	for shot: Array in [["front", Vector3(0, 0.15, 1)], ["side", Vector3(1, 0.15, 0)], ["3q", Vector3(0.7, 0.4, 0.8)], ["top", Vector3(0.001, 1, 0.001)]]:
		camera.global_position = box.get_center() + (shot[1] as Vector3).normalized() * reach
		camera.look_at(box.get_center(), Vector3.UP)
		await _shoot(tree, "%s/%s_%s.png" % [out_dir, glb.get_file().get_basename(), shot[0]])


## Triangles, surfaces and texture sizes of every --glb=a.glb,b.glb given.
func _stats() -> void:
	for path in glb.split(","):
		var scene: PackedScene = load(path)
		var model := scene.instantiate() as Node3D
		var triangles := 0
		var surfaces := 0
		var textures := {}
		var skeletons := 0
		var players := 0
		var stack: Array[Node] = [model]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			if node is Skeleton3D:
				skeletons += (node as Skeleton3D).get_bone_count()
			if node is AnimationPlayer:
				players += 1
			if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
				var mesh := (node as MeshInstance3D).mesh
				for surface in mesh.get_surface_count():
					surfaces += 1
					var arrays := mesh.surface_get_arrays(surface)
					var indices = arrays[Mesh.ARRAY_INDEX]
					triangles += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
					var material := mesh.surface_get_material(surface) as BaseMaterial3D
					if material != null and material.albedo_texture != null:
						textures[material.albedo_texture.get_size()] = true
		print("STATS %-28s triangles=%-7d surfaces=%d bones=%d animplayers=%d albedo=%s" % [path.get_file(), triangles, surfaces, skeletons, players, str(textures.keys())])
		model.free()


## The bounds of every mesh under `root`, in `root`'s own space.
func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var local := (node as MeshInstance3D).mesh.get_aabb()
			var transform := root.global_transform.affine_inverse() * (node as MeshInstance3D).global_transform
			var moved := transform * local
			box = moved if first else box.merge(moved)
			first = false
	return box


func _shoot(tree: SceneTree, path: String) -> void:
	for _frame in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("CAPTURED: " if image.save_png(path) == OK else "FAILED: ", path)
