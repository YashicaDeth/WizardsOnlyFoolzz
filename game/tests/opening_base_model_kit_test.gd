extends Node

const KIT := preload("res://systems/opening_base_model_kit.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var kit := KIT.new()
	add_child(kit)
	kit.build_opening_dressing(22.0)

	check(kit.get_node_or_null("VatCrown") != null, "the concept vat has a replaceable crown model")
	check(kit.get_node_or_null("RitualPlinth") != null, "the vat has a ritual-industrial floor anchor")
	check(kit.get_node_or_null("CableSpine") != null, "the room has a reusable overhead cable spine")
	check(kit.get_node_or_null("ServiceGantryL") != null and kit.get_node_or_null("ServiceGantryR") != null, "both walls receive modular service gantries")

	var meshes := _collect_meshes(kit)
	check(meshes.size() >= 60, "the kit creates a readable dressing pass rather than a single prop")
	check(meshes.all(func(mesh: MeshInstance3D): return mesh.has_meta("placeholder_model") and mesh.has_meta("replacement_id")), "every primitive declares that it is replaceable placeholder art")
	check(meshes.all(func(mesh: MeshInstance3D): return mesh.has_meta("material_slot") and KIT.MATERIAL_SLOTS.has(mesh.get_meta("material_slot"))), "every primitive uses a stable artist-facing material slot")

	var replacement := StandardMaterial3D.new()
	replacement.albedo_color = Color.MAGENTA
	kit.apply_material_overrides({&"iron": replacement})
	var iron_meshes := meshes.filter(func(mesh: MeshInstance3D): return mesh.get_meta("material_slot") == &"iron")
	check(not iron_meshes.is_empty() and iron_meshes.all(func(mesh: MeshInstance3D): return mesh.material_override == replacement), "an artist can retexture one named slot across the whole kit")

	print("OPENING_BASE_MODEL_KIT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			found.append(child)
		found.append_array(_collect_meshes(child))
	return found
