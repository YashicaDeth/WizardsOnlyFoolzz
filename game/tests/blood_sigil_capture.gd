extends Node3D

## Windowed only through AgentHub/render_one.cmd. Stages the production
## RebirthSite recovery mark beside the exact body and inventory it belongs to.

var out_path := "P:/GameDev/Temp/job7-death-saves-screen/blood_sigil.png"


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("BLOOD_SIGIL_CAPTURE headless draws nothing; use AgentHub/render_one.cmd")
		get_tree().quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"kind": "person", "blood_fragments": 7})
	var carry := Carry.new()
	carry.items = [{"label": "HOTLINE CLEAVER", "kind": "weapon"}]
	carry.save_to_history()
	VatRebirth.die("service_arcade", "capture", "numbered_guard", Vector3.ZERO)
	VatRebirth.complete()

	var world := WorldEnvironment.new()
	world.environment = WorldLook.environment("facility")
	add_child(world)
	var floor := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(7.0, 0.12, 7.0)
	var slab_material := StandardMaterial3D.new()
	slab_material.albedo_color = Color("171a17")
	slab_material.roughness = 0.88
	slab.material = slab_material
	floor.mesh = slab
	floor.position.y = -0.08
	add_child(floor)
	var overhead := OmniLight3D.new()
	overhead.position = Vector3(-0.7, 2.4, 1.0)
	overhead.light_color = Color("d8e0b5")
	overhead.light_energy = 3.2
	overhead.omni_range = 7.0
	add_child(overhead)

	var player := CharacterBody3D.new()
	player.position = Vector3(2.8, 0.0, 2.8)
	add_child(player)
	var site := RebirthSite.new()
	add_child(site)
	site.setup("service_arcade", player)
	var camera := Camera3D.new()
	camera.position = Vector3(0.8, 1.25, 2.65)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.18, 0.0))
	camera.fov = 58.0
	add_child(camera)
	camera.current = true
	for _frame in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(out_path)
	print("CAPTURED: %s" % out_path if result == OK else "CAPTURE_FAILED: %s" % out_path)
	get_tree().quit(0 if result == OK else 1)
