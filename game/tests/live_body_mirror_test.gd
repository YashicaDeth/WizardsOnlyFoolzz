extends Node

const LiveBodyMirror := preload("res://systems/live_body_mirror.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("live_mirror_test", {"gore": true})
	var mirror := LiveBodyMirror.new()
	add_child(mirror)
	mirror.set_target(rig)
	await get_tree().process_frame
	check(mirror.target == rig, "mirror targets the actual gameplay rig")
	check(bool(mirror.live_state.get("ok", false)), "mirror receives a live rig snapshot")
	rig.hit("right_arm", 60.0, 1.0, "cut")
	await get_tree().process_frame
	var arm: Dictionary = (mirror.live_state.get("zones", {}) as Dictionary).get("right_arm", {})
	check(int(arm.get("opened_layer", 0)) > 0, "mirror feed follows wounds on the source rig")
	mirror.queue_free()
	rig.queue_free()
	print("LIVE_BODY_MIRROR_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
