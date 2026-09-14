extends Node

const MirrorBodyState := preload("res://systems/mirror_body_state.gd")

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
	rig.build("mirror_test", {"gore": true})
	var intact := MirrorBodyState.snapshot(rig)
	check(bool(intact.get("ok", false)), "a living gameplay rig provides a mirror state")
	var intact_arm: Dictionary = (intact.get("zones", {}) as Dictionary).get("left_arm", {})
	check(bool(intact_arm.get("visible", false)) and not bool(intact_arm.get("severed", true)), "the mirror reads the actual intact limb")
	rig.hit("left_arm", 44.0, 1.0, "cut")
	var wounded := MirrorBodyState.snapshot(rig)
	var wounded_arm: Dictionary = (wounded.get("zones", {}) as Dictionary).get("left_arm", {})
	check(float(wounded_arm.get("health_ratio", 1.0)) < float(intact_arm.get("health_ratio", 0.0)), "mirror state follows real zone damage")
	check(int(wounded_arm.get("opened_layer", 0)) > 0, "mirror state includes wound depth, not only hit-point loss")
	rig.queue_free()
	print("MIRROR_BODY_STATE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
