extends Node

const PART_VIEWER := preload("res://systems/part_viewer.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER"})
	var viewer: SubViewport = PART_VIEWER.new()
	add_child(viewer)
	await get_tree().process_frame
	viewer.show_part({"kind": "organ", "id": "brain", "zone": "head"}, 1.0)
	await get_tree().process_frame

	var glass := viewer._pivot.get_node_or_null("CurvedCrtGlass") as MeshInstance3D
	check(glass != null, "the brain specimen owns a CRT glass mesh")
	check(viewer._pivot.get_node_or_null("Hemisphere") != null and viewer._pivot.get_node_or_null("CrtUpperRail") != null, "cortex and inset CRT hardware occupy the same turning specimen")
	if glass != null:
		var vertices: PackedVector3Array = glass.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var edge_z: float = vertices[0].z
		var centre_z: float = vertices[(vertices.size() / 2) as int].z
		check(vertices.size() == 24 and centre_z > edge_z + 0.010, "the emitted face is an eleven-segment convex curve, not a flat quad")
		var material := glass.material_override as ShaderMaterial
		check(material != null and material.get_shader_parameter("phosphor") is ViewportTexture, "the curved glass is driven by a live emissive viewport")

	var display: SubViewport = viewer.get_node_or_null("CortexIndex")
	check(display != null, "the index surface lives inside the organ viewer")
	if display != null:
		var rows: Array[String] = display.displayed_rows()
		check(not rows.is_empty() and rows.any(func(row): return "[SEALED]" in row), "the cortex screen renders BrainIndex's sealed memory rows")
		check(str(display.get_node("PhosphorFace/Path").text).contains("CORTEX:/TRAUMA"), "the display identifies the region as an internal cortex path")

	viewer.show_part({"kind": "organ", "id": "heart", "zone": "torso"}, 1.0)
	await get_tree().process_frame
	check(viewer.get_node_or_null("CortexIndex") == null and viewer._pivot.get_node_or_null("CurvedCrtGlass") == null, "the embedded display belongs only to the brain specimen")

	print("BRAIN_CRT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
