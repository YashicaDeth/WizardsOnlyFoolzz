extends Node

## Photographs `body_showcase.tscn`. The showcase has existed since the rig was
## built and could only ever be looked at by running it and leaving a window
## open, which is how a rendering fault in it went unnoticed — headless runs
## prove the body has no script errors and prove nothing about what it looks
## like. Every visual bug in this project was found by reading a PNG.

func _ready() -> void:
	var out_dir := OS.get_environment("ATG_CAPTURE_DIR")
	if out_dir == "":
		out_dir = OS.get_environment("TEMP")
	var showcase: Node = load("res://tests/body_showcase.tscn").instantiate()
	add_child(showcase)
	# The rig builds its zones, organs and bones over several frames, and the
	# environment needs a frame of its own before anything is lit.
	for _settle in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/showcase.png" % out_dir
	if image.save_png(path) != OK:
		print("CAPTURE_FAILED ", path)
		get_tree().quit(1)
		return
	print("CAPTURED: ", path, " ", image.get_width(), "x", image.get_height())
	_report_oversized(get_tree().root)
	get_tree().quit(0)


## Anything big enough to cross the whole set, named with where it came from.
func _report_oversized(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var extent: Vector3 = mesh_node.get_aabb().size * mesh_node.global_transform.basis.get_scale()
		if extent.length() < 2.0:
			continue
		var tint := "?"
		var material := mesh_node.material_override as StandardMaterial3D
		if material == null and mesh_node.mesh.get_surface_count() > 0:
			material = mesh_node.mesh.surface_get_material(0) as StandardMaterial3D
		if material != null:
			tint = "%s a=%.2f" % [material.albedo_color.to_html(false), material.albedo_color.a]
		print("OVERSIZED %s parent=%s class=%s extent=%.2f tint=%s" % [
			mesh_node.name, str(mesh_node.get_parent().name), mesh_node.mesh.get_class(), extent.length(), tint,
		])
