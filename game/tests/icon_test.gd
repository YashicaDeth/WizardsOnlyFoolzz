extends Node

## B0.4/B0.5. The spinning head is not decorative: it must reflect damage and
## it must be available in the FILE rail without growing an unbounded viewport
## collection. This checks the face state and the six-slot pooling contract.

const SUBJECT_ICON := preload("res://systems/subject_icon.gd")
const WORLD_INDEX := preload("res://systems/world_index.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var icon: SubViewport = SUBJECT_ICON.new()
	add_child(icon)
	await get_tree().process_frame

	icon.set_subject({
		"name": "Whole Face",
		"anatomy_state": {"zones": {"head": {"health": 45.0}}, "wounds": []},
	}, Color("b0552a"))
	var healthy: Dictionary = icon.damage_state()
	check(not healthy.left_eye_missing and not healthy.right_eye_missing and not healthy.jaw_broken, "an undamaged subject keeps both eyes and an aligned jaw")
	check(icon._left_eye.visible and icon._right_eye.visible and not icon._socket.visible, "the healthy face geometry is visible")

	icon.set_subject({
		"name": "Mara Voss",
		"wounds": ["missing left eye", "broken jaw"],
		"anatomy_state": {"zones": {"head": {"health": 10.0}}, "wounds": []},
	}, Color("a8281a"))
	var damaged: Dictionary = icon.damage_state()
	check(damaged.left_eye_missing and not damaged.right_eye_missing and damaged.jaw_broken, "authored eye and jaw wounds become icon state")
	check(not icon._left_eye.visible and icon._right_eye.visible and icon._socket.visible, "the missing eye becomes a socket rather than a caption")
	check(icon._jaw.rotation.length_squared() > 0.01, "the broken jaw is visibly displaced")

	icon.set_xray(true)
	check(icon._skull.visible and not icon._left_eye.visible and not icon._right_eye.visible and not icon._jaw.visible, "X-ray still replaces the flesh features with real skull geometry")

	var index: Control = WORLD_INDEX.new()
	add_child(index)
	await get_tree().process_frame
	index.page = 0
	index.rail_index = 3
	check(index._icons.size() == 6, "FILE and dossier share a bounded six-head viewport pool")
	check(index._file_rail_icon_slot(1) == 1 and index._file_rail_icon_slot(3) == 3 and index._file_rail_icon_slot(5) == 5, "the selected FILE row and two neighbours on either side receive live head slots")
	check(index._file_rail_icon_slot(0) == -1 and index._file_rail_icon_slot(6) == -1, "offscreen FILE rows do not allocate 3D worlds")
	index.page = 1
	check(index._file_rail_icon_slot(3) == -1, "the FILE rail pool does not leak into other pages")

	print("ICON_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
