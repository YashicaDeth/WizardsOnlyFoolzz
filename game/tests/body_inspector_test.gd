extends Node

## B1.4-B1.8: the body page must behave like a physical specimen viewer, and
## each organ must remain recognisable without relying on its caption or colour.

const BODY_INSPECTOR := preload("res://systems/body_inspector.gd")
const PART_VIEWER := preload("res://systems/part_viewer.gd")
const ImplantCatalog := preload("res://systems/implant_catalog.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func has_piece(viewer: SubViewport, piece_name: String) -> bool:
	return viewer._pivot.get_node_or_null(piece_name) != null


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER",
		"wounds": ["burned fingertips"],
		"anatomy": {"cybernetics": [{"id": "salvaged torque arm", "condition": 36.0}]},
	})
	var authored_player := WorldHistory.subject("player")
	check(authored_player.wounds[0] is Dictionary and str(authored_player.wounds[0].zone) == "right_arm", "authored prose wounds migrate once into explicit zone records")
	check(str(ImplantCatalog.resolve("rangefinder eye").zone) == "head", "catalogue identity supplies an implant's real zone")
	check(str(ImplantCatalog.resolve("mystery arm words").zone) == "torso", "unknown hardware does not regain the deleted keyword guesser")

	var inspector: Node = BODY_INSPECTOR.new()
	add_child(inspector)
	await get_tree().process_frame
	inspector.set_subject({
		"name": "Specimen",
		"anatomy_state": {
			"zones": {"torso": {"health": 80.0}},
			"organs": {
				"heart": {"health": 0.0, "max_health": 35.0, "ruptured": true},
				"left_lung": {"health": 30.0, "max_health": 30.0, "ruptured": false},
			},
		},
	})
	inspector._part_rects = [Rect2(0, 0, 100, 30), Rect2(0, 32, 100, 30), Rect2(0, 64, 100, 30)]
	inspector.part_index = 0
	check(inspector.handle_pointer_motion(Vector2(10, 42), Vector2.ZERO) and inspector.hovered_part_index == 1, "hover previews a row without changing the pinned index")
	check(inspector.part_index == 0 and str(inspector.selected_part().id) == "torso", "the temporary preview does not mutate the pin")
	check(inspector.handle_click(Vector2(10, 42)) and inspector.part_index == 1, "click pins the previewed part")
	inspector.handle_pointer_motion(Vector2(220, 220), Vector2.ZERO)
	check(inspector.hovered_part_index == -1 and inspector.part_index == 1, "moving away restores the pinned specimen")

	var viewer: SubViewport = PART_VIEWER.new()
	add_child(viewer)
	await get_tree().process_frame
	viewer.show_part({"kind": "organ", "id": "left_lung", "zone": "torso"}, 1.0)
	check(has_piece(viewer, "UpperLobe") and has_piece(viewer, "LowerLobe") and has_piece(viewer, "MedialLobe"), "a lung is an authored multi-lobe silhouette")
	var wet_piece := viewer._pivot.get_node("UpperLobe") as MeshInstance3D
	var wet_material := wet_piece.material_override as StandardMaterial3D
	check(wet_material.roughness < 0.3 and wet_material.clearcoat_enabled and wet_material.subsurf_scatter_enabled, "soft organs use a slick clearcoat and subsurface wet pass")

	viewer.show_part({"kind": "organ", "id": "liver", "zone": "torso"}, 1.0)
	check(has_piece(viewer, "LiverWedge") and has_piece(viewer, "LiverLobe"), "the liver has a broad wedge and secondary lobe")
	viewer.show_part({"kind": "organ", "id": "gut", "zone": "torso"}, 1.0)
	check(has_piece(viewer, "GutCoil0") and has_piece(viewer, "GutCoil4"), "the gut reads as a five-loop coil")

	viewer.show_part({"kind": "organ", "id": "heart", "zone": "torso", "ruptured": true}, 0.0)
	check(bool(viewer.view_state().ruptured) and has_piece(viewer, "RuptureCavity") and has_piece(viewer, "TornFlap3"), "a ruptured organ gains a cavity and displaced torn flaps")

	inspector._stage_rect = Rect2(200, 100, 240, 240)
	var rotation_before: Vector2 = viewer.view_state().rotation
	inspector._viewer = viewer
	check(inspector.handle_mouse_button(Vector2(250, 150), MOUSE_BUTTON_LEFT, true), "pressing the specimen starts direct manipulation")
	inspector.handle_pointer_motion(Vector2(270, 170), Vector2(20, 20))
	check((viewer.view_state().rotation as Vector2) != rotation_before, "dragging turns the live 3D specimen")
	inspector.handle_mouse_button(Vector2(270, 170), MOUSE_BUTTON_LEFT, false)
	var zoom_before: float = float(viewer.view_state().zoom)
	inspector.handle_mouse_button(Vector2(250, 150), MOUSE_BUTTON_WHEEL_UP, true)
	check(float(viewer.view_state().zoom) > zoom_before, "the wheel zooms the specimen without changing selection")

	var anatomy := AnatomyComponent.new()
	add_child(anatomy)
	anatomy.configure("hardware_probe", 5000.0, {"head": {"name": "rangefinder eye", "condition": 32.0, "max_condition": 64.0}})
	check(is_equal_approx(anatomy.implant_condition("head"), 0.5), "implant condition is a real normalised number")
	anatomy.apply_hit("head", 12.0, 4.0, "blunt")
	check(anatomy.implant_condition("head") < 0.5, "a hit to the occupied zone degrades the installed part")
	var hardware_snapshot := anatomy.snapshot()
	var restored := AnatomyComponent.new()
	add_child(restored)
	restored.configure("hardware_heir")
	restored.restore(hardware_snapshot)
	check(is_equal_approx(restored.implant_condition("head"), anatomy.implant_condition("head")), "implant condition and zone survive save/restore")

	viewer.show_part(ImplantCatalog.resolve("rangefinder eye").merged({"kind": "implant"}, true), 0.5)
	check(has_piece(viewer, "OpticLens") and has_piece(viewer, "OpticBezel"), "the rangefinder catalogue entry selects its authored optic mesh")
	for implant_id in ImplantCatalog.ENTRIES:
		var catalogue_part: Dictionary = ImplantCatalog.resolve(str(implant_id))
		catalogue_part["kind"] = "implant"
		viewer.show_part(catalogue_part, 1.0)
		check(viewer._pivot.get_child_count() >= 2, "%s resolves to authored hardware geometry" % str(implant_id))

	WorldHistory.register_subject("loot_subject", {
		"name": "Loot Subject",
		"anatomy": {"cybernetics": [{"id": "rangefinder eye", "condition": 58.0}]},
	})
	inspector.set_subject(WorldHistory.subject("loot_subject"))
	inspector.zone = "head"
	inspector._rebuild_parts()
	for index in inspector._parts.size():
		if str((inspector._parts[index] as Dictionary).get("kind", "")) == "implant":
			inspector.part_index = index
			break
	var compare: Dictionary = inspector.comparison()
	check(not compare.is_empty() and str(compare.decision) == "ROB" and float(compare.delta) > 0.0, "compare view turns their part versus yours into the robbing decision")

	print("BODY_INSPECTOR_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
