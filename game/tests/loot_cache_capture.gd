extends Node3D

## The orange box, replaced. Four caches with different contents, so the item
## silhouettes can be judged against each other — the whole argument for
## building real geometry here is that a player should read a cache at distance
## without reading its label.

const LOOT := preload("res://systems/loot_cache.gd")

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 520)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("171310")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b9a893")
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 34, 0)
	key.light_energy = 1.7
	add_child(key)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("2b2420")
	floor_mesh.material_override = fm
	add_child(floor_mesh)

	# The old placeholder, for comparison, at the far left.
	var old := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	old.mesh = box
	old.scale = Vector3.ONE * 0.35
	old.position = Vector3(-1.35, 0.35, 0)
	var om := StandardMaterial3D.new()
	om.albedo_color = Color("c08134")
	old.material_override = om
	add_child(old)

	var sets := [
		["gate scrip", "brass knuckle"],
		["cutting torch", "soot rag"],
		["haul ledger", "spare chain"],
		["relay coil", "tinned meat"],
	]
	for index in sets.size():
		var cache := Node3D.new()
		cache.position = Vector3(-0.25 + 0.62 * float(index), 0, 0)
		add_child(cache)
		LOOT.build(cache, sets[index], index * 7919 + 3)

	var cam := Camera3D.new()
	cam.position = Vector3(0.5, 0.78, 1.85)
	cam.fov = 42.0
	add_child(cam)
	cam.look_at(Vector3(0.5, 0.22, 0), Vector3.UP)
	for _s in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/loot_cache_vs_placeholder.png"))
	print("LOOT_CAPTURE_RESULT saved")
	get_tree().quit(0)
