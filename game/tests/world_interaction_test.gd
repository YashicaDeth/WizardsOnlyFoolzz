extends Node

const RESTRICTED_STORAGE := preload("res://systems/restricted_storage.gd")
const HANDHELD := preload("res://systems/handheld_device.gd")

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
	await get_tree().process_frame
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	get_tree().root.add_child(hunt)
	get_tree().current_scene = hunt
	for _settle in 45:
		await get_tree().process_frame

	# AX3.5's object is the live proof of the generic path: nothing here knows
	# it is a Black Mirror prototype rather than next month's restraint or
	# clothing — it is just whichever registered object is nearest.
	var case_node: Node3D = hunt.get_node_or_null("RestrictedTechnologyStorage")
	check(case_node != null, "the restricted storage case exists as a real object in the world, not just in code")
	if case_node == null:
		print("WORLD_INTERACTION_TEST_RESULT failures=", failures.size() + 1)
		get_tree().quit(1)
		return

	hunt.player = case_node.global_position + Vector3(50, 0, 0)
	check(hunt._nearest_interactable().is_empty(), "out of range, the generic trigger offers nothing")

	hunt.player = case_node.global_position + Vector3(0.6, 0, 0)
	var candidate: Dictionary = hunt._nearest_interactable()
	check(not candidate.is_empty() and str(candidate.get("prompt", "")).contains("STEAL THE PROTOTYPE"),
		"walking into range surfaces the object's own prompt through the generic path")
	check(not bool(WorldHistory.subject(HANDHELD.DEVICE_ID).get("possessed", true)),
		"being in range does not itself take anything")

	hunt._interact()
	check(RESTRICTED_STORAGE.is_breached(), "one E on the generic trigger runs the object's own registered action")
	check(bool(WorldHistory.subject(HANDHELD.DEVICE_ID).get("possessed", false)),
		"the action taken is the object's real one (restricted_storage.gd), not a stand-in")
	# queue_free() defers the actual removal to frame end, the same as any other
	# freed node in this engine — one frame is real, not a loosened check.
	await get_tree().process_frame
	check(hunt._nearest_interactable().is_empty(),
		"a spent interactable retires itself, the same as dropped_handheld going null already does")

	print("WORLD_INTERACTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
