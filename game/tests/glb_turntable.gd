extends Node3D
## Look at a generated model before it goes anywhere near the game: loads a
## GLB from disk at runtime, frames it, and saves front / right / back / left
## as one 2x2 sheet, with its triangle count printed.
##   Godot --path game res://tests/glb_turntable.tscn -- --glb=P:/x.glb --out=P:/x.png

func _ready() -> void:
	var glb := ""
	var out := "P:/GameDev/Temp/turntable.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--glb="):
			glb = argument.trim_prefix("--glb=")
		elif argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(glb, state) != OK:
		print("TURNTABLE_FAILED could not read ", glb)
		get_tree().quit(1)
		return
	var model := doc.generate_scene(state) as Node3D
	add_child(model)
	# Frame it: centre and size from every mesh's bounds.
	var bounds := AABB()
	var first := true
	var triangles := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var box := mesh_node.global_transform * mesh_node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			triangles += (indices.size() if indices.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	# A rigged model's mesh bounds are its unposed skin, often in centimetres;
	# the skeleton's bones say where the body really stands.
	for node in model.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		var bone_box := AABB()
		for bone in skeleton.get_bone_count():
			var at := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
			bone_box = AABB(at, Vector3.ZERO) if bone == 0 else bone_box.expand(at)
		if bone_box.size.length() > bounds.size.length():
			bounds = bone_box.grow(bone_box.size.y * 0.12)
	var centre := bounds.get_center()
	var radius := bounds.size.length() * 0.5
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.5, 0.0)
	sun.light_energy = 1.6
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, PI + 0.5, 0.0)
	fill.light_energy = 0.7
	add_child(fill)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.16, 0.17)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.58)
	add_child(env)
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var shots: Array[Image] = []
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		camera.global_position = centre + Vector3(sin(angle), 0.35, cos(angle)).normalized() * radius * 1.45
		camera.look_at(centre, Vector3.UP)
		for _f in 4:
			await get_tree().process_frame
		# The project stretches its 1280x720 base, so take the centre square
		# rather than resizing the window.
		var frame := get_viewport().get_texture().get_image()
		var side := mini(frame.get_width(), frame.get_height())
		var shot := frame.get_region(Rect2i((frame.get_width() - side) / 2, (frame.get_height() - side) / 2, side, side))
		shot.resize(640, 640)
		shots.append(shot)
	var sheet := Image.create(1280, 1280, false, shots[0].get_format())
	for index in 4:
		sheet.blit_rect(shots[index], Rect2i(Vector2i.ZERO, Vector2i(640, 640)), Vector2i((index % 2) * 640, (index / 2) * 640))
	sheet.save_png(out)
	print("TURNTABLE %s triangles=%d size=%s -> %s" % [glb.get_file(), triangles, bounds.size, out])
	get_tree().quit()
