extends Node

## B3.3-B3.6. Seeing into a body becomes something you do in the world rather
## than a page in the dossier, it reaches a real distance, it beats the wall in
## front of it, and holding the button turns the ring into the wheel.
##
## Also guards the key map. A second `KEY_F` branch was added to the hunt's
## input match while `KEY_F` already toggled the camera, and because every test
## called `_begin_extraction()` directly the whole of B5 was unreachable from
## the keyboard with a full green suite.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- range is real ------------------------------------------------------
	check(WorldXray.strength_at(0.0) >= 1.0, "a body at your feet reads fully")
	check(WorldXray.strength_at(WorldXray.RANGE + 4.0) == 0.0, "one past the reach does not read at all")
	var near := WorldXray.strength_at(WorldXray.RANGE * 0.8)
	var far := WorldXray.strength_at(WorldXray.RANGE * 0.95)
	check(near > far and far > 0.0, "and it fades out toward the edge rather than popping (%.2f -> %.2f)" % [near, far])

	# --- the sweep turns bodies on and off ----------------------------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("settings", {"gore": "FULL"})
	BaselineHuman.apply_gore_setting()
	var close := BaselineHuman.new()
	add_child(close)
	close.build("close_body", {})
	close.position = Vector3(0, 0, 3)
	var distant := BaselineHuman.new()
	add_child(distant)
	distant.build("distant_body", {})
	distant.position = Vector3(0, 0, WorldXray.RANGE + 10.0)
	await get_tree().physics_frame

	var lit: Array = WorldXray.sweep(Vector3.ZERO, [close, distant], true)
	var lit_ids: Array = []
	for entry in lit:
		lit_ids.append(str(entry.subject_id))
	check(lit_ids.has("close_body"), "a body in reach lights up")
	check(not lit_ids.has("distant_body"), "one out of reach does not")

	var heart: MeshInstance3D = close.organ_parts.heart
	check(heart.visible, "the organs of a swept body are actually shown")
	var heart_material: StandardMaterial3D = (heart.mesh as PrimitiveMesh).material as StandardMaterial3D
	check(heart_material.no_depth_test, "and they draw through whatever is in front of them")
	var skull: MeshInstance3D = (close.bones.head as Node3D).get_child(0)
	check((skull.material_override as StandardMaterial3D).no_depth_test, "so does the bone")

	# --- and it puts them back ----------------------------------------------
	WorldXray.sweep(Vector3.ZERO, [close, distant], false)
	check(not heart.visible, "letting go hides the organs again")
	check(not heart_material.no_depth_test, "and stops them drawing through walls")
	check(not (skull.material_override as StandardMaterial3D).no_depth_test, "a rig is never left permanently see-through")

	# --- the key map actually reaches the verbs -----------------------------
	var source := FileAccess.get_file_as_string("res://bone_yard_hunt.gd")
	var bound := {}
	var duplicates: Array[String] = []
	for raw in source.split("\n"):
		var line := str(raw).strip_edges()
		if not line.begins_with("KEY_"):
			continue
		var key := line.split(":")[0].strip_edges()
		if bound.has(key):
			duplicates.append(key)
		bound[key] = true
	check(duplicates.is_empty(), "no key is bound twice in the input match (%s)" % str(duplicates))
	check(bound.has("KEY_H"), "the dig has a key that is actually reachable")

	print("WORLD_XRAY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
