extends Node3D

## Job 2 visual proof without a window: stages rigged bodies headless and
## writes what each one would draw (skin sections baked in their pose, the
## rig's own parts, wounds, stumps, thrown limbs) as a static glTF per shot,
## for tools/blender/render_rigged_shots.py to render in Blender's background
## mode. Not a test (no `_test` suffix).
##
##   ATG_TEST_MODE=1 godot --headless --path game res://tests/rigged_body_pose_export.tscn -- --out=P:/GameDev/Temp/job2/shots

var out_dir := "P:/GameDev/Temp/job2/shots"


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if "--hunt" in OS.get_cmdline_user_args():
		await _export_hunt()
		get_tree().quit(0)
		return
	var floor := StaticBody3D.new()
	add_child(floor)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 0.10, 80.0)
	collider.shape = box
	collider.position.y = -0.05
	floor.add_child(collider)
	var shots := {
		"idle": _body("shot_idle", Vector3(0, 0, 0), true),
		"swing": _body("shot_swing", Vector3(6, 0, 0), true),
		"wounded": _body("shot_wounded", Vector3(12, 0, 0), true),
		"severed": _body("shot_severed", Vector3(18, 0, 0), true),
		"ragdoll": _body("shot_ragdoll", Vector3(24, 0, 0), true),
		"old_unrigged": _body("shot_old", Vector3(30, 0, 0), false),
	}
	for index in 30:
		await get_tree().process_frame
	(shots.swing as BaselineHuman).rigged.play_action("sword_attack")
	var wounded := shots.wounded as BaselineHuman
	var arm := wounded.parts.left_arm as Node3D
	wounded.hit_at(arm.global_position + Vector3(0, 0.05, -0.08), 14.0, 2.0, "cut", Vector3.BACK)
	var severed := shots.severed as BaselineHuman
	var guard := 0
	while not severed.severed.has("right_arm") and guard < 20:
		severed.hit("right_arm", 60.0, 2.0, "cut", "", Vector3.RIGHT)
		guard += 1
	(shots.ragdoll as BaselineHuman).hit("head", 400.0, 6.0, "puncture", "brain", Vector3.BACK, 1.0, null, null, "heavy")
	for index in 21:
		await get_tree().process_frame
	_export("swing", shots.swing)
	for index in 220:
		await get_tree().physics_frame
	for shot: String in shots:
		if shot != "swing":
			_export(shot, shots[shot])
	print("POSE_EXPORT_DONE ", out_dir)
	get_tree().quit(0)


## The real Hunt: the player's own body in third person, and one of the
## encounter bodies, as the Hunt builds and dresses them.
func _export_hunt() -> void:
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	if "--first-person" in OS.get_cmdline_user_args():
		hunt.third_person = false
	else:
		hunt.third_person = true
	for index in 90:
		hunt._update_camera()
		await get_tree().process_frame
	var player_rigged: RiggedBody = hunt.player_rig.rigged
	print("HUNT first_person=%s arms_driven=%s modes=%s xray=%s lens=%.2f" % [hunt.body_motion.first_person, player_rigged.arms_driven, player_rigged.modes, hunt.player_rig.get("_xray"), hunt.camera.global_position.distance_to(hunt.player + Vector3.UP * (hunt.EYE_ABOVE_CENTRE - 0.6))])
	_export("hunt_player_fp" if "--first-person" in OS.get_cmdline_user_args() else "hunt_player", hunt.player_rig)
	for actor: Dictionary in hunt.encounter_actors:
		var actor_rig := actor.get("rig") as BaselineHuman
		if actor_rig != null and is_instance_valid(actor_rig):
			_export("hunt_enemy", actor_rig)
			break
	print("POSE_EXPORT_DONE ", out_dir)


func _body(id: String, at: Vector3, rigged: bool) -> BaselineHuman:
	var holder := Node3D.new()
	holder.name = id + "_holder"
	holder.position = at + Vector3(0, 0.9, 0)
	add_child(holder)
	var body := BaselineHuman.new()
	body.position.y = -0.9
	holder.add_child(body)
	body.build(id, {"gore": true, "ragdoll": true, "rigged": rigged, "flesh": Color("8a6a52")})
	body.dress(ClothingShell.humiliation_wardrobe())
	return body


## Everything this body would draw, frozen, under one root at the body's own
## origin, plus thrown limbs and stumps near it.
func _export(shot: String, body: BaselineHuman) -> void:
	var root := Node3D.new()
	root.name = shot
	var origin := body.global_transform
	var sources: Array[Node] = body.find_children("*", "MeshInstance3D", true, false)
	for node in get_children():
		if node is RigidBody3D and str(node.name).ends_with("_severed") and (node.find_child("SeveredSkin", true, false) != null):
			# The thrown limb, laid beside the body it came off so it is in frame.
			var limb := node as RigidBody3D
			limb.global_position = body.global_position + Vector3(0.7, 0.12, 0.2)
			sources.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for node in sources:
		var instance := node as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree() or instance.transparency >= 0.99:
			continue
		if _effect(instance):
			continue
		var mesh: Mesh = instance.mesh
		var at := instance.global_transform
		if instance.skin != null and body.rigged != null:
			mesh = body.rigged.call("_bake_pose", instance)
			at = body.rigged.skeleton.global_transform
		if mesh == null:
			continue
		var copy := MeshInstance3D.new()
		copy.name = str(instance.name)
		copy.mesh = _plain(mesh, _colour(instance))
		root.add_child(copy)
		copy.transform = origin.affine_inverse() * at
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	add_child(root)
	var error := document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, "%s/%s.glb" % [out_dir, shot])
	print("EXPORT %s meshes=%d -> %s" % [shot, root.get_child_count(), error_string(error)])
	root.queue_free()


## Glows, flames and other see-through effects: an opaque export of them
## hides the body (the undying flame's halo is a sphere round the player).
func _effect(instance: MeshInstance3D) -> bool:
	var material: Material = instance.material_override
	if material == null and instance.mesh.get_surface_count() > 0:
		material = instance.mesh.surface_get_material(0)
	if material is ShaderMaterial:
		return true
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		return base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or base.albedo_color.a < 0.95 or base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	return false


func _colour(instance: MeshInstance3D) -> Color:
	var material: Material = instance.material_override
	if material == null and instance.mesh != null and instance.mesh.get_surface_count() > 0:
		material = instance.mesh.surface_get_material(0)
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).albedo_color
	return Color(0.55, 0.5, 0.45)


func _plain(mesh: Mesh, colour: Color) -> ArrayMesh:
	var out := ArrayMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour.r, colour.g, colour.b, 1.0)
	material.roughness = 0.8
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var clean := []
		clean.resize(Mesh.ARRAY_MAX)
		clean[Mesh.ARRAY_VERTEX] = arrays[Mesh.ARRAY_VERTEX]
		clean[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
		clean[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		if (clean[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, clean)
		out.surface_set_material(out.get_surface_count() - 1, material)
	return out
