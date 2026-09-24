extends Node

const BARRIER := preload("res://systems/biometric_barrier.gd")
const BODY := preload("res://systems/baseline_human.gd")

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
	var barrier := BARRIER.new()
	barrier.authorized_subject_ids = ["guard_hollis"]
	add_child(barrier)

	var guard := BODY.new()
	guard.build("guard_hollis")
	guard.set_meta("subject_id", "guard_hollis")
	add_child(guard)
	await get_tree().process_frame

	check(bool(barrier.present_body(guard).accepted), "a living guard opens the biometric barrier")
	barrier.opened = false
	guard.anatomy.consciousness = 0.0
	guard.anatomy.downed = true
	check(bool(barrier.present_body(guard).accepted), "an unconscious guard remains a valid coerced credential")
	barrier.opened = false
	guard.anatomy.dead = true
	check(bool(barrier.present_body(guard).accepted), "a dead guard remains a valid credential")
	barrier.opened = false
	check(bool(barrier.present_anatomy({"subject_id": "guard_hollis", "zone": "right_hand"}).accepted),
		"removed guard anatomy carries the same identity")
	check(not bool(barrier.present_anatomy({"subject_id": "player", "zone": "right_hand"}).accepted),
		"unregistered tissue cannot open the door")
	check(not bool(barrier.present_implant_spoof("guard_hollis").accepted),
		"implant spoofing is rejected before that later capability is earned")
	barrier.implant_spoof_enabled = true
	check(bool(barrier.present_implant_spoof("guard_hollis").accepted),
		"the same reader has an explicit later implant-spoof path")
	check(WorldHistory.event_count("facility_biometric_access") == 5,
		"each successful physical or spoofed access records one shared facility fact")

	print("BIOMETRIC_BARRIER_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
