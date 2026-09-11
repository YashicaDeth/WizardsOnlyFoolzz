extends Node

## B1.4-B1.8: the body page must behave like a physical specimen viewer, and
## each organ must remain recognisable without relying on its caption or colour.

const BODY_INSPECTOR := preload("res://systems/body_inspector.gd")
const PART_VIEWER := preload("res://systems/part_viewer.gd")

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

	print("BODY_INSPECTOR_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
