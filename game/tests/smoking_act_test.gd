extends Node

## AU7.6/AU7.9. The object suite already proves the curve. This proves the
## Hunt actually gives a player the object, drives that curve from a held bind,
## and takes the weapon away when the two-hand object is raised.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	await tree.process_frame
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	tree.root.add_child(hunt)
	tree.current_scene = hunt
	for _settle in 60:
		await tree.process_frame

	# The actual key branch, not a private helper call.
	var six := InputEventKey.new()
	six.keycode = KEY_6
	six.pressed = true
	hunt.call("_unhandled_input", six)
	var held := hunt.get("smoke_model") as Node3D
	check(held != null, "6 puts a smokeable in the hand")
	if held == null:
		_report()
		return
	var rig = hunt.get("player_rig")
	check(held.get_parent() == rig.parts.right_arm, "the object belongs to the body's real right arm")
	check(held.get_node_or_null("anchor_grip") != null, "and it arrived through HeldGear's grip anchor")
	var arsenal = hunt.get("arsenal")
	check((arsenal.models.values() as Array).all(func(model): return not (model as Node3D).visible),
		"holding it puts the weapon away")

	# Hold rather than tap: the visible heat and the delivered grade are driven
	# by the same accumulated duration.
	hunt.call("_begin_smoking_draw")
	var length_before_draw := Smokeables.spent_of(held)
	for _frame in 96:
		hunt.call("_update_smoking", 1.0 / 60.0)
	var held_seconds := float(hunt.get("smoke_held"))
	check(held_seconds > 1.5, "holding RMB accumulates a real draw duration")
	check(Smokeables.spent_of(held) > length_before_draw,
		"the cigarette burns shorter continuously while the button is held")
	check(held.position.x < -0.15,
		"the lit cigarette rises beside the first-person reticle at the mouth")
	var result: Dictionary = hunt.call("_finish_smoking_draw")
	check(bool(result.get("ok", false)), "releasing RMB lands the draw")
	check(str(result.get("device", "")) == "cigarette", "the hit comes from the object actually held")
	check(float((hunt.get("smoke_spent") as Dictionary).get("cigarette", 0.0)) > 0.0,
		"and the same act burns down that object")
	for _breath in 20:
		hunt.call("_update_smoking", 1.0 / 60.0)
	var air = hunt.get("air")
	check(air.get_parent().get_node_or_null("SmokeExhale") != null,
		"release automatically breathes a drifting plume into the world")
	check(float(hunt.get("smoke_trick_window")) > 0.0, "the fresh breath briefly becomes playable")
	hunt.call("_shape_smoke_trick")
	check(air.get_parent().get_node_or_null("SmokeTrick_O") != null, "clicking shapes the breath into a physical smoke O")
	check(WorldHistory.event_count("smoke_trick") == 1, "and the world records the trick as an act")

	# Cycle to the fifth object. Its second hand and weapon cost must be visible,
	# not merely catalog metadata.
	for _next in 4:
		hunt.call("_cycle_smokeable")
	var bong := hunt.get("smoke_model") as Node3D
	check(str(bong.get_meta("device_id", "")) == "bong", "the held slot reaches the bong")
	check(bong.get_node_or_null("BongSupportHand") != null, "the bong physically takes the second hand")
	check((arsenal.models.values() as Array).all(func(model): return not (model as Node3D).visible),
		"and no weapon remains in either hand")

	# The help card must teach every bind this added.
	var rows: Array = []
	for group: Dictionary in hunt.get("keys_card").groups:
		rows.append_array(group.get("rows", []) as Array)
	check(rows.any(func(row): return row[0] == "6"), "the keys card teaches the smokeable slot")
	check(rows.any(func(row): return row[0] == "HOLD RMB"), "and teaches that drawing is a hold")
	check(rows.any(func(row): return row[0] == "LMB EXHALE"), "and teaches the optional smoke control")

	_report()


func _report() -> void:
	print("SMOKING_ACT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
