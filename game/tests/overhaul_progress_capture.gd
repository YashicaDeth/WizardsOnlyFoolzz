extends Node3D

const HUD := preload("res://systems/gothic_field_hud.gd")
const CAMERA := preload("res://systems/black_mirror_camera.gd")

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "status": "active"})
	get_window().size = Vector2i(1280, 720)
	var environment := WorldLook.environment("ashbloom_night")
	environment.volumetric_fog_enabled = false
	environment.fog_density = 0.008
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.0, 11)
	add_child(camera)
	camera.look_at(Vector3(0, 1.2, -6))
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	floor_mesh.mesh = plane
	floor_mesh.material_override = WorldLook.surface(Color("403c37"), "dirt", 15)
	add_child(floor_mesh)
	for i in 14:
		var column := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0 + float(i % 3), 3.0 + float(i % 4), 2.0)
		column.mesh = box
		column.position = Vector3(float(i % 2) * 16.0 - 8.0, box.size.y * 0.5, 4.0 - float(i / 2) * 6.0)
		column.material_override = WorldLook.surface(Color("635248"), "rust", i)
		add_child(column)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, -50, 0)
	moon.light_color = Color("8392bc")
	moon.light_energy = 0.32
	add_child(moon)
	for i in 3:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-6 if i % 2 == 0 else 6, 2.4, -float(i) * 9)
		lamp.light_color = Color("dd6d38")
		lamp.light_energy = 2.0
		lamp.omni_range = 8
		add_child(lamp)
	var layer := CanvasLayer.new()
	add_child(layer)
	var sensor := CAMERA.new()
	layer.add_child(sensor)
	sensor.bind(camera, environment)
	var hud := HUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	hud.set_state({"health": 67, "magic": 82, "stamina": 49, "portrait": WorldHistory.subject("player"), "weapon": {"id": "sword"}, "map_context": {"heading": 0.3, "label": "ASHBLOOM · NIGHT SURVEY"}})
	for frame in 65:
		await get_tree().process_frame
	await _capture("overhaul_hud_rails")
	hud.style = "arcs"
	for frame in 8:
		await get_tree().process_frame
	await _capture("overhaul_hud_arcs")
	hud.style = "rails"
	sensor.set_active(true)
	for frame in 90:
		sensor._process(1.0 / 60.0)
		await get_tree().process_frame
	await _capture("overhaul_night_sensor")
	print("OVERHAUL_PROGRESS_CAPTURE_OK")
	get_tree().quit()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "P:/GameDev/Temp/%s.png" % label
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " error=", error)
