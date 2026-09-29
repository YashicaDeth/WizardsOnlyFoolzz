extends Node
## Generated models standing in the world (Higgsfield, 29 September): each keeps
## its drawn fallback and the contract its owner and its tests rely on.
## Grows with each prop: the dropped Black Mirror and the den's phone and shiv.

const DROPPED := preload("res://systems/dropped_handheld.gd")
const VAT := preload("res://vat_chamber.tscn")
var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


## Tight bounds from the real vertices, in `root`'s space.
func _vertex_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as MeshInstance3D).visible:
			var to_root := root.global_transform.affine_inverse() * (node as MeshInstance3D).global_transform
			for surface in (node as MeshInstance3D).mesh.get_surface_count():
				for vertex: Vector3 in (node as MeshInstance3D).mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var point := to_root * vertex
					box = AABB(point, Vector3.ZERO) if first else box.expand(point)
					first = false
	return box


func _albedo_luminance(root: Node) -> float:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh != null and instance.visible and instance.get_surface_override_material(0) is BaseMaterial3D:
			return (instance.get_surface_override_material(0) as BaseMaterial3D).albedo_color.get_luminance()
	return -1.0


func _ready() -> void:
	WorldHistory.clear_history()

	# --- The dropped Black Mirror. ---
	var fresh := DROPPED.new()
	add_child(fresh)
	fresh.configure({"serial": 7, "condition": 1.0, "battery": 1.0})
	check(fresh.get_node_or_null("generated_black_mirror") != null, "the dropped device is the generated phone")
	check(fresh.get_node_or_null("Case") is MeshInstance3D and fresh.get_node_or_null("MirrorGlass") is MeshInstance3D, "the drawn Case and MirrorGlass stay in the tree (tests and finders rely on them)")
	check(not (fresh.get_node("Case") as MeshInstance3D).visible and not (fresh.get_node("MirrorGlass") as MeshInstance3D).visible, "hidden, so only one phone shows")
	var box := _vertex_bounds(fresh.get_node("generated_black_mirror"))
	check(box.size.z > 0.30 and box.size.z < 0.38 and box.size.x > 0.15 and box.size.x < 0.24 and box.size.y > 0.02 and box.size.y < 0.07, "phone-sized, lying flat (%.3f x %.3f x %.3f m)" % [box.size.x, box.size.y, box.size.z])
	check(absf(box.get_center().y) < 0.02, "centred on the body, so it sits in its collider")
	var worn := DROPPED.new()
	add_child(worn)
	worn.configure({"serial": 8, "condition": 0.2, "battery": 0.0})
	check(_albedo_luminance(worn) > 0.0 and _albedo_luminance(worn) < _albedo_luminance(fresh), "a beaten device is dirtier than a new one")
	check((worn.get_node("ScreenGlow") as OmniLight3D).light_energy < (fresh.get_node("ScreenGlow") as OmniLight3D).light_energy, "and a dead battery glows less than a live one")

	# --- The den: their phone and their shiv, lying on the floor. ---
	var vat: Node3D = VAT.instantiate()
	add_child(vat)
	await get_tree().process_frame
	var mirror := vat.get_node("DenMirror") as Node3D
	var shiv := vat.get_node("DenShiv") as Node3D
	check(not (mirror is MeshInstance3D), "the den's Black Mirror is the generated phone")
	check(not (shiv is MeshInstance3D), "and the den's shiv is the generated blade")
	var mirror_box := _vertex_bounds(mirror)
	check(mirror_box.size.y < 0.07 and mirror.global_position.y < 0.08, "the phone lies on the floor, not in it or over it")
	print("MODEL_WORLD_PROPS_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
