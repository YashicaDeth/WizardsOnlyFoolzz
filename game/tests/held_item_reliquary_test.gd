extends Node

const RELIQUARY := preload("res://systems/held_item_reliquary.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _mesh(parent: Node3D, name: String, size: Vector3, shown := true) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = name
	var box := BoxMesh.new()
	box.size = size
	result.mesh = box
	result.visible = shown
	parent.add_child(result)
	return result


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var reliquary := RELIQUARY.new()
	add_child(reliquary)
	await get_tree().process_frame

	var long_item := Node3D.new()
	add_child(long_item)
	_mesh(long_item, "blade", Vector3(0.05, 0.05, 1.0))
	_mesh(long_item, "hidden_magazine", Vector3(0.2, 0.2, 0.2), false)
	reliquary.show_item(long_item, "AN EXTREMELY LONG AUTHORED OBJECT LABEL", "100 PERCENT CONDITION")
	check(reliquary.mesh_count == 1, "the reliquary copies only geometry currently visible in the live object")
	check(float(reliquary.get("_fit_scale")) > 2.0, "a long thin object uses the wide aperture instead of shrinking to a bounding sphere")
	check(is_zero_approx(float(reliquary.get("_clock"))), "a newly presented object starts from the shared readable orbit register")

	var tall_item := Node3D.new()
	add_child(tall_item)
	_mesh(tall_item, "bottle", Vector3(0.08, 1.0, 0.08))
	reliquary.show_item(tall_item, "TALL BOTTLE", "SEALED")
	check(float(reliquary.get("_fit_scale")) <= RELIQUARY.FIT_HEIGHT + 0.01, "a tall object still respects the aperture height")
	check(reliquary.displayed_source_id == tall_item.get_instance_id() and reliquary.mesh_count == 1,
		"switching class replaces the previous presentation immediately instead of overlaying it for a frame")

	print("HELD_ITEM_RELIQUARY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
