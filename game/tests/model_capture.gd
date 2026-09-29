extends Node3D
## A generated model, looked at: on a turntable with its anchors marked, in the
## Hunt's first-person hand, or in the hub body's fist.
##   Godot --path game res://tests/model_capture.tscn -- --mode=turntable \
##       --weapon=breach_nine --out=P:/GameDev/Temp/model
##   --mode=hunt     first person, facility sidearm acquired in the real Hunt
##   --mode=hub      VatBodyPreview holding `--weapon` (facility_sidearm)
##   --mode=restraint the real Growing Floor route with its carried restraint
##   --mode=prop     `--scene-node=res://systems/x.gd` is not needed: use
##                   --glb=res://art/generated/props/cctv.glb for a bare model

var out_dir := "P:/GameDev/Temp/model"
var mode := "turntable"
var weapon := "breach_nine"
var glb := ""
var hour := 13.0
var slot := -1
var acquire := ""
var distance := 0.0
var target_y := 0.9


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
		elif argument.begins_with("--acquire="):
			acquire = argument.trim_prefix("--acquire=")
		elif argument.begins_with("--distance="):
			distance = float(argument.trim_prefix("--distance="))
		elif argument.begins_with("--target-y="):
			target_y = float(argument.trim_prefix("--target-y="))
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	var tree := get_tree()
	tree.create_timer(150.0, true, false, true).timeout.connect(func() -> void: tree.quit(3))
	match mode:
		"hunt":
			await _hunt(tree)
		"hub":
			await _hub(tree)
		"drop":
			await _drop_phone(tree)
		"restraint":
			await _restraint_in_hand(tree)
		"prop":
			await _prop(tree)
		"stats":
			_stats()
		"axes":
			_axes()
		"skeleton":
			_skeleton()
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
	elif not acquire.is_empty():
		print("ACQUIRE ", acquire, " ", arsenal.acquire_melee(acquire), " select=", arsenal.select_weapon(acquire), " current=", arsenal.current_id)
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
	if model != null and acquire == "shiv":
		# Blade tip and pommel from the measured axes (model units), on screen.
		var generated := model.find_child("generated_shiv", true, false) as Node3D
		var camera_now := hunt.camera as Camera3D
		if generated != null:
			var native := generated.get_child(0) as Node3D
			var centroid := Vector3(0.009, 0.072, -0.086)
			var forward := Vector3(0.134, -0.627, 0.767)
			for named: Array in [["tip", 0.776], ["pommel", -0.508]]:
				var at := native.global_transform * (centroid + forward * float(named[1]))
				print("SHIV %s screen=%s distance=%.3f" % [named[0], camera_now.unproject_position(at).round(), at.distance_to(camera_now.global_position)])
	var tag := "slot%d" % slot if slot >= 0 else (acquire if not acquire.is_empty() else "facility")
	await _shoot(tree, "%s/hunt_%s.png" % [out_dir, tag])
	if slot < 0 and acquire.is_empty():
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
	var centre := box.get_center()
	if distance > 0.0:
		# A rigged model's mesh box is in its own units (the Armature is scaled
		# 0.01), so frame it from a fixed distance at a fixed height instead.
		reach = distance
		centre = Vector3(0, target_y, 0)
	camera.fov = 40.0
	for shot: Array in [["front", Vector3(0, 0.15, 1)], ["side", Vector3(1, 0.15, 0)], ["3q", Vector3(0.7, 0.4, 0.8)], ["top", Vector3(0.001, 1, 0.001)]]:
		camera.global_position = centre + (shot[1] as Vector3).normalized() * reach
		camera.look_at(centre, Vector3.UP)
		await _shoot(tree, "%s/%s_%s.png" % [out_dir, glb.get_file().get_basename(), shot[0]])


## The dropped Black Mirror in the real Hunt, on the ground in front of you.
func _drop_phone(tree: SceneTree) -> void:
	WorldHistory.clear_history()
	WorldHistory.world_minute = hour * WorldClock.MINUTES_PER_HOUR
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _frame in 60:
		await tree.process_frame
	hunt.handheld.possessed = true
	hunt.handheld.battery = 0.72
	hunt.handheld.condition = 0.64
	hunt.handheld.drop()
	await tree.physics_frame
	var forward: Vector3 = -hunt.camera.global_transform.basis.z.normalized()
	hunt.dropped_handheld.freeze = true
	hunt.dropped_handheld.global_position = hunt.camera.global_position + forward * 0.9 + Vector3.DOWN * 0.45
	hunt.dropped_handheld.rotation_degrees = Vector3(0.0, 25.0, 0.0)
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.0
	lamp.omni_range = 4.0
	(hunt.camera as Camera3D).add_child(lamp)
	for _frame in 20:
		await tree.process_frame
	await _shoot(tree, "%s/dropped_black_mirror.png" % out_dir)


## The real DoctorRoute reads the real Carry record and hangs its tool from the
## vat camera. This is intentionally not a turntable stand-in: it proves the
## object the player sees while battering his door.
func _restraint_in_hand(tree: SceneTree) -> void:
	WorldHistory.clear_history()
	var vat: Node = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await tree.process_frame
	if vat.load_in != null:
		vat.load_in.skip()
	var carry := Carry.new()
	carry.items.append({"label": DoctorRoute.RESTRAINT_LABEL, "kind": "tool", "mass": 0.0, "perishes": false, "age": 0.0, "from": "growing_floor"})
	carry.save_to_history()
	for _frame in 8:
		await tree.physics_frame
	var route: DoctorRoute = vat.doctor_route
	vat._unhandled_input(InputEventMouseMotion.new())
	vat.player.global_position = Vector3(route.DOOR_AT.x, vat.BODY_HALF_HEIGHT + 0.02, route.WALL_Z - 1.3)
	vat.player.velocity = Vector3.ZERO
	vat.yaw = PI
	vat.pitch = -0.12
	vat.player.rotation.y = vat.yaw
	vat.camera.rotation = Vector3(vat.pitch, 0, 0)
	var lamp := OmniLight3D.new()
	lamp.light_energy = 3.0
	lamp.omni_range = 3.0
	lamp.shadow_enabled = false
	vat.camera.add_child(lamp)
	lamp.position = Vector3(0.1, -0.1, -0.2)
	for _frame in 12:
		await tree.process_frame
	print("RESTRAINT held=", route.held_restraint != null, " generated=", route.held_restraint != null and route.held_restraint.name == "generated_restraint")
	await _shoot(tree, "%s/restraint_in_hand.png" % out_dir)


## Bones, clips and skinning of every rigged --glb=a.glb,b.glb.
func _skeleton() -> void:
	for path in glb.split(","):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		add_child(model)
		var stack: Array[Node] = [model]
		print("SKELETON %s  root=%s" % [path.get_file(), model.name])
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			if node is Skeleton3D:
				var skeleton := node as Skeleton3D
				print("  Skeleton3D %s path=%s bones=%d" % [skeleton.name, model.get_path_to(skeleton), skeleton.get_bone_count()])
				for bone in skeleton.get_bone_count():
					var rest := skeleton.get_bone_global_rest(bone).origin
					print("    bone %2d %-22s parent=%-3d rest_y=%.3f rest_x=%.3f" % [bone, skeleton.get_bone_name(bone), skeleton.get_bone_parent(bone), rest.y, rest.x])
			elif node is MeshInstance3D:
				var instance := node as MeshInstance3D
				var box := instance.mesh.get_aabb() if instance.mesh != null else AABB()
				print("  MeshInstance3D %s path=%s skeleton=%s skin=%s aabb_size=%s aabb_pos=%s" % [instance.name, model.get_path_to(instance), instance.skeleton, instance.skin != null, box.size, box.position])
			elif node is AnimationPlayer:
				var player := node as AnimationPlayer
				print("  AnimationPlayer %s root_node=%s" % [player.name, player.root_node])
				for clip in player.get_animation_list():
					var animation := player.get_animation(clip)
					print("    clip '%s' length=%.2f tracks=%d loop=%s" % [clip, animation.length, animation.get_track_count(), animation.loop_mode])
					if animation.get_track_count() > 0:
						print("      first tracks: %s | %s" % [animation.track_get_path(0), animation.track_get_path(mini(3, animation.get_track_count() - 1))])
		model.queue_free()


## Principal axes of every --glb=a.glb,b.glb: how the generator oriented it,
## so a model can be turned to the game's convention (long axis on +Z, tip
## forward) by a measured angle instead of a guessed one.
func _axes() -> void:
	for path in glb.split(","):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		add_child(model)
		var points := PackedVector3Array()
		var stack: Array[Node] = [model]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
				var to_model := model.global_transform.affine_inverse() * (node as MeshInstance3D).global_transform
				for surface in (node as MeshInstance3D).mesh.get_surface_count():
					for vertex: Vector3 in (node as MeshInstance3D).mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
						points.append(to_model * vertex)
		var centroid := Vector3.ZERO
		for point in points:
			centroid += point
		centroid /= float(points.size())
		var covariance := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
		for point in points:
			var d := point - centroid
			for row in 3:
				for column in 3:
					covariance[row][column] += d[row] * d[column]
		var eigen := _jacobi(covariance)
		print("AXES %s  points=%d centroid=%s" % [path.get_file(), points.size(), centroid.snapped(Vector3.ONE * 0.001)])
		for index in 3:
			var axis: Vector3 = eigen.vectors[index]
			var low := INF
			var high := -INF
			for point in points:
				var t := (point - centroid).dot(axis)
				low = minf(low, t)
				high = maxf(high, t)
			# Thickness (distance from the axis) at each end: the thin end is the tip.
			var span := high - low
			var near_low := 0.0
			var near_high := 0.0
			var count_low := 0
			var count_high := 0
			for point in points:
				var d := point - centroid
				var t := d.dot(axis)
				var radial := (d - axis * t).length()
				if t < low + span * 0.15:
					near_low += radial
					count_low += 1
				elif t > high - span * 0.15:
					near_high += radial
					count_high += 1
			print("  axis%d=%s  extent[%.3f .. %.3f]  end radius low=%.3f high=%.3f" % [index, axis.snapped(Vector3.ONE * 0.001), low, high, near_low / maxf(1.0, count_low), near_high / maxf(1.0, count_high)])
		# Profile down the long axis: thickness and cross-section by 0.1 steps.
		var main: Vector3 = eigen.vectors[0]
		var side_a: Vector3 = eigen.vectors[1]
		var side_b: Vector3 = eigen.vectors[2]
		var bins := {}
		for point in points:
			var d := point - centroid
			var bin := int(floorf(d.dot(main) * 10.0))
			if not bins.has(bin):
				bins[bin] = {"n": 0, "radial": 0.0, "a_lo": INF, "a_hi": -INF, "b_lo": INF, "b_hi": -INF}
			var entry: Dictionary = bins[bin]
			entry.n += 1
			entry.radial += (d - main * d.dot(main)).length()
			entry.a_lo = minf(entry.a_lo, d.dot(side_a))
			entry.a_hi = maxf(entry.a_hi, d.dot(side_a))
			entry.b_lo = minf(entry.b_lo, d.dot(side_b))
			entry.b_hi = maxf(entry.b_hi, d.dot(side_b))
		var keys := bins.keys()
		keys.sort()
		for key in keys:
			var entry: Dictionary = bins[key]
			print("    t=%+.1f n=%-4d mean-radius=%.3f  widthA=%.3f widthB=%.3f" % [float(key) / 10.0, entry.n, entry.radial / entry.n, entry.a_hi - entry.a_lo, entry.b_hi - entry.b_lo])
		model.queue_free()


## Symmetric 3x3 eigen decomposition (Jacobi), largest eigenvalue first.
func _jacobi(matrix: Array) -> Dictionary:
	var a := matrix.duplicate(true)
	var v := [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
	for _sweep in 30:
		var off: float = absf(a[0][1]) + absf(a[0][2]) + absf(a[1][2])
		if off < 1e-12:
			break
		for pair: Array in [[0, 1], [0, 2], [1, 2]]:
			var p: int = pair[0]
			var q: int = pair[1]
			if absf(a[p][q]) < 1e-15:
				continue
			var theta: float = (a[q][q] - a[p][p]) / (2.0 * a[p][q])
			var t: float = signf(theta) / (absf(theta) + sqrt(theta * theta + 1.0)) if theta != 0.0 else 1.0
			var c: float = 1.0 / sqrt(t * t + 1.0)
			var sn: float = t * c
			for k in 3:
				var akp: float = a[k][p]
				var akq: float = a[k][q]
				a[k][p] = c * akp - sn * akq
				a[k][q] = sn * akp + c * akq
			for k in 3:
				var apk: float = a[p][k]
				var aqk: float = a[q][k]
				a[p][k] = c * apk - sn * aqk
				a[q][k] = sn * apk + c * aqk
			for k in 3:
				var vkp: float = v[k][p]
				var vkq: float = v[k][q]
				v[k][p] = c * vkp - sn * vkq
				v[k][q] = sn * vkp + c * vkq
	var order := [0, 1, 2]
	order.sort_custom(func(x, y): return a[x][x] > a[y][y])
	var vectors := []
	for index in order:
		vectors.append(Vector3(v[0][index], v[1][index], v[2][index]).normalized())
	return {"vectors": vectors}


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
					if material != null:
						print("   MATERIAL %s metallic=%.2f roughness=%.2f metal_tex=%s rough_tex=%s ao=%s albedo=%s emission=%s" % [path.get_file(), material.metallic, material.roughness, material.metallic_texture != null, material.roughness_texture != null, material.ao_enabled, material.albedo_color, material.emission_enabled])
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
