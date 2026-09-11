extends SceneTree


func _init() -> void:
	var generator = load("res://systems/ashbloom_world_generator.gd").new()
	root.add_child(generator)
	generator.generate(774013)
	if generator.generated_buildings.is_empty():
		push_error("SILHOUETTE_TEST: no generated buildings")
		quit(1)
		return
	var first: Node3D = generator.generated_buildings[0]
	var mesh_count := 0
	for child in first.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
	var settled := not first.rotation.is_zero_approx()
	if mesh_count < 12 or not settled:
		push_error("SILHOUETTE_TEST: meshes=%d settled=%s" % [mesh_count, settled])
		quit(1)
		return
	print("SILHOUETTE_TEST_OK buildings=%d meshes=%d rotation=%s" % [generator.generated_buildings.size(), mesh_count, first.rotation])
	quit(0)
