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
	check(not bool(preview.last_config.get("seated", true)), "the intake specimen uses the standing anatomy layout")
	preview._process(0.2)
	check(preview._feed != null and not (preview._feed.mesh is CylinderMesh), "the mouth feed is a curved mesh rather than a straight cylinder")
	check(preview._cables.size() == 3, "three curved skull leads are present")
	var head := preview.rig.parts.get("head") as Node3D
	var torso := preview.rig.parts.get("torso") as Node3D
	var forward: Vector3 = -preview.rig.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var mouth: Vector3 = head.global_position + forward * 0.11 + Vector3.DOWN * 0.075
	check((preview._feed.get_meta("to", Vector3.ZERO) as Vector3).distance_to(mouth) < 0.06, "the curved feed terminates at the mouth")
	var back: Vector3 = -forward
	var lead_targets := [head.global_position + back * 0.10 + Vector3.UP * 0.03, head.global_position + back * 0.08 + Vector3.DOWN * 0.12, torso.global_position + back * 0.12 + Vector3.UP * 0.18]
	for index in preview._cables.size():
		var lead: MeshInstance3D = preview._cables[index]
		check(not (lead.mesh is CylinderMesh), "skull lead %d is a curved mesh" % index)
		check((lead.get_meta("to", Vector3.ZERO) as Vector3).distance_to(lead_targets[index]) < 0.06, "skull lead %d terminates on the back of the head/body" % index)
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
