extends Node
## Generated models standing in the world (Higgsfield, 29 September): each keeps
## its drawn fallback and the contract its owner and its tests rely on.
## Grows with each prop: the dropped Black Mirror and the den's phone and shiv.

const DROPPED := preload("res://systems/dropped_handheld.gd")
const VAT := preload("res://vat_chamber.tscn")
const GENERATED_MODEL_SCRIPT := preload("res://systems/generated_model.gd")
var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


## Tight bounds from the vertices the triangles actually use, in `root`'s space
## (a cut mesh keeps its whole vertex array and only drops indices).
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
				var arrays := (node as MeshInstance3D).mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var used := PackedVector3Array()
				if arrays[Mesh.ARRAY_INDEX] != null:
					for index: int in arrays[Mesh.ARRAY_INDEX]:
						used.append(vertices[index])
				else:
					used = vertices
				for vertex: Vector3 in used:
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

	# --- The wall CCTV: the housing turns on the head, the bracket stays. ---
	var wall_camera := SecurityCamera.new()
	add_child(wall_camera)
	wall_camera.build("model_props_camera")
	var bracket := wall_camera.get_node_or_null("Bracket") as Node3D
	var housing_model := wall_camera.head.get_node_or_null("HousingModel") as Node3D
	check(bracket != null and housing_model != null, "the CCTV is the generated model: a bracket on the mount, a housing on the head")
	check(not (wall_camera.get_node("Arm") as MeshInstance3D).visible and not (wall_camera.head.get_node("Housing/Body") as MeshInstance3D).visible, "the drawn arm and box hide")
	check(wall_camera.lens != null and not wall_camera.lens.visible, "the lens glow is off, so the model's own lens shows")
	var assembly := _vertex_bounds(wall_camera)
	check(assembly.end.z > -0.03 and assembly.end.z < 0.03, "the wall plate sits flat on the mount (%.3f)" % assembly.end.z)
	check(assembly.position.z < -0.5, "and the lens looks out along -Z, away from the wall (front at %.3f)" % assembly.position.z)
	var housing_box := _vertex_bounds(housing_model)
	check(housing_box.size.z > 0.35 and housing_box.size.z < 0.5 and housing_box.size.x < 0.3 and housing_box.size.y < 0.28, "the housing is the size of the box it replaces (%.3f x %.3f x %.3f m)" % [housing_box.size.x, housing_box.size.y, housing_box.size.z])
	var bracket_at := bracket.global_transform
	wall_camera.head.rotation.y = wall_camera.sweep_half
	check(bracket.global_transform.is_equal_approx(bracket_at), "the bracket stays put while the head sweeps")
	check(not housing_model.global_transform.basis.is_equal_approx(bracket_at.basis), "and the housing turns with it")
	wall_camera.tracking = true
	wall_camera._tint()
	check(wall_camera.lens.visible, "the glow lights when it has you")
	wall_camera.smash("test")
	check(not wall_camera.lens.visible and wall_camera.broken, "smashed, the glow is gone")

	# --- His surgery: the lamp over the gurney, the drill on the tray. ---
	var route := vat.find_child("DoctorRoute", true, false) as Node3D
	var lamp := route.get_node_or_null("generated_surgical_lamp") as Node3D if route != null else null
	var drill := route.get_node_or_null("generated_bone_drill") as Node3D if route != null else null
	check(lamp != null and drill != null, "the doctor's room has the generated lamp and drill")
	if lamp != null and drill != null:
		var spot := route.get_node("SurgeryLamp") as SpotLight3D
		var lamp_box := _vertex_bounds(lamp)
		var head := lamp.global_position + GENERATED_MODEL_SCRIPT.LAMP_HEAD
		check(Vector2(head.x - spot.global_position.x, head.z - spot.global_position.z).length() < 0.12, "the head hangs right over the SurgeryLamp light")
		check(lamp_box.size.x < 1.0 and lamp_box.size.y < 1.0 and lamp_box.size.z < 1.0 and lamp_box.size.x > 0.4, "the lamp is lamp-sized (%.3f x %.3f x %.3f m)" % [lamp_box.size.x, lamp_box.size.y, lamp_box.size.z])
		# The drawn SurgeryLamp hangs 0.98 m under the ceiling (lamp_at - 0.08).
		var under_ceiling := spot.position.y + 0.98 - (lamp.position.y + lamp_box.end.y)
		check(under_ceiling > 0.02 and under_ceiling < 0.4, "the tilted ceiling plate stays under the ceiling, on its short pole (%.3f m below)" % under_ceiling)
		var drill_box := _vertex_bounds(drill)
		check(drill_box.size.z > 0.25 and drill_box.size.z < 0.31 and drill_box.size.y < 0.08, "the drill is 0.28 m and lies on its side (%.3f x %.3f x %.3f m)" % [drill_box.size.x, drill_box.size.y, drill_box.size.z])
		check(absf(drill_box.position.y) < 0.01, "lying on the tray, not in it (bottom %.3f)" % drill_box.position.y)

	print("MODEL_WORLD_PROPS_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
