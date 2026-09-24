extends Node

const PREVIEW := preload("res://systems/vat_body_preview.gd")

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
	var preview = PREVIEW.new()
	preview.size = Vector2(240, 360)
	add_child(preview)
	await get_tree().process_frame
	preview.present({
		"race": "decanted",
		"appearance": {"name": "TEST SUBJECT", "build": 0.0, "wear": 0.2},
		"anatomy": {"blood_type": "O-RUST"},
	})
	await get_tree().process_frame
	check(preview.viewport != null and preview.viewport.own_world_3d, "the intake preview owns an isolated 3D world")
	check(preview.rig != null and is_instance_valid(preview.rig), "the intake preview grows a real BaselineHuman rig")
	var compact_build := float(preview.last_config.get("build", 0.0))
	var first_rig: Node3D = preview.rig as Node3D
	preview.present({
		"race": "decanted",
		"appearance": {"name": "TEST SUBJECT", "build": 1.0, "wear": 0.2},
		"anatomy": {"blood_type": "O-RUST"},
	})
	await get_tree().process_frame
	check(preview.rig != first_rig, "a changed form rebuilds the disposable preview rig")
	check(float(preview.last_config.get("build", 0.0)) > compact_build, "preview build matches the selected BODY/BUILD value")
	check(WorldHistory.recent_events(5).is_empty(), "previewing a body writes no world or ledger events")
	print("VAT_BODY_PREVIEW_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
