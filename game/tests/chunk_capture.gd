extends Node3D

## Shows B4 rather than describing it: a body, a deep cut, and the layers that
## came out of it lying on the floor as separate physical objects.

const CellOutzType := preload("res://systems/celloutz_type.gd")

var _label: Control


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame

	WorldHistory.clear_history()
	WorldHistory.register_subject("settings", {"gore": "FULL"})
	BaselineHuman.apply_gore_setting()
	GoreChunks.clear()

	var ground := StaticBody3D.new()
	var plane := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	plane.shape = box
	plane.position = Vector3(0, -0.5, 0)
	ground.add_child(plane)
	var visual := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(40, 1, 40)
	visual.mesh = slab
	visual.position = Vector3(0, -0.5, 0)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color("241c16")
	dirt.roughness = 1.0
	visual.material_override = dirt
	ground.add_child(visual)
	add_child(ground)

	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("120d0a")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color("4a3a2c")
	world.ambient_light_energy = 0.9
	environment.environment = world
	add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 34, 0)
	key.light_energy = 1.6
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-8, -148, 0)
	rim.light_energy = 1.0
	rim.light_color = Color("b0552a")
	add_child(rim)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.15, 2.35)
	camera.rotation_degrees = Vector3(-16, 0, 0)
	camera.fov = 52.0
	add_child(camera)

	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("display_subject", {"cybernetics": {"torso": {"name": "ceramic sternum"}}})
	await get_tree().physics_frame

	# Escalating blows into the same zone, which is the behaviour worth showing:
	# each one reaches further because the one before it opened the way.
	rig.hit("torso", 26.0, 12.0, "cut", "heart")
	await get_tree().physics_frame
	rig.hit("torso", 44.0, 18.0, "cut", "left_lung")
	await get_tree().physics_frame
	rig.hit("torso", 70.0, 26.0, "ballistic", "liver")
	rig.hit("left_arm", 52.0, 20.0, "shear")
	await get_tree().physics_frame

	var counts: Dictionary = {}
	for chunk in GoreChunks.live:
		var info := GoreChunks.identify(chunk)
		var name := str(info.get("layer_name", "?"))
		counts[name] = int(counts.get(name, 0)) + 1

	_label = Control.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.draw.connect(func() -> void:
		CellOutzType.draw_stamped(_label, Vector2(44, 42), "SHED LAYERS", 22.0, Color("e6d4ac"), Color("a8281a"), 1.4)
		var y := 88.0
		for layer_name in GoreChunks.LAYER_NAMES:
			var tally := int(counts.get(layer_name, 0))
			var tone := Color("e6d4ac") if tally > 0 else Color(0.9, 0.85, 0.7, 0.28)
			CellOutzType.draw_text(_label, Vector2(44, y), "%s %02d" % [str(layer_name).to_upper(), tally], 13.0, tone, 1.0)
			y += 22.0
		CellOutzType.draw_text(_label, Vector2(44, y + 10), "EXPOSED TO %s" % GoreChunks.LAYER_NAMES[rig.exposed_layer("torso")].to_upper(), 11.0, Color("b0552a"), 1.0)
	)
	var layer_node := CanvasLayer.new()
	add_child(layer_node)
	layer_node.add_child(_label)

	# Let the pieces actually land.
	for _settle in 150:
		await get_tree().physics_frame
	_label.queue_redraw()
	for _frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/chunks.png" % out_dir
	if image.save_png(path) != OK:
		print("CAPTURE_FAILED")
		get_tree().quit(1)
		return
	print("CAPTURED: ", path, " live=", GoreChunks.live.size(), " ", counts)
	get_tree().quit()
