extends Node

## The lab's cables (Greg: "intricate Lain / Evangelion wiring, not one long
## tube"): hundreds of cables in a handful of meshes, none of them low enough
## over the aisle to meet a head, and none of them solid.

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
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var report: Dictionary = vat.cable_report
	check(int(report.get("cables", 0)) >= 200, "the lab is wired, not piped (%d cables)" % int(report.get("cables", 0)))
	check(int(report.get("meshes", 99)) <= 5, "in one mesh per sheath (%d)" % int(report.get("meshes", 99)))
	check(float(report.get("lowest_over_aisle", 0.0)) >= 2.9, "nothing hangs into a head walking the aisle (lowest %.2f m)" % float(report.get("lowest_over_aisle", 0.0)))
	var triangles := 0
	var solid := 0
	for node in vat.get_children():
		if str(node.name).begins_with("Cables_"):
			triangles += (node.mesh as ArrayMesh).surface_get_array_len(0) / 3 if (node.mesh as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FORMAT_INDEX == 0 else (node.mesh as ArrayMesh).surface_get_array_index_len(0) / 3
			solid += node.find_children("*", "CollisionShape3D", true, false).size()
	check(solid == 0, "the cables are scenery: no colliders")
	check(triangles > 0 and triangles < 200000, "and cheap enough (%d triangles)" % triangles)
	var lit := vat.get_node_or_null("Cables_lit") as MeshInstance3D
	check(lit != null and (lit.material_override as StandardMaterial3D).emission_enabled, "some of the lines are lit")
	print("LAB_CABLES_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
