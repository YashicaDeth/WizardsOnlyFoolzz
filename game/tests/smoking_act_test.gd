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
	check(held.get_node_or_null("SmokingGripHand") != null,
		"an articulated pinching hand visibly holds the cigarette")
	check(held.get_node_or_null("SmokingGripHand/HumiliationCuff") != null,
		"the hand wears the elites' oversized jester restraint cuff")
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
	var camera := hunt.get("camera") as Camera3D
	var cigarette_in_view := camera.to_local(held.global_position)
	check(absf(cigarette_in_view.x) < 0.10 and cigarette_in_view.y < 0.0,
		"the lit cigarette rises beside the first-person reticle at the mouth")
	var result: Dictionary = hunt.call("_finish_smoking_draw")
	check(bool(result.get("ok", false)), "releasing RMB lands the draw")
	check(str(result.get("device", "")) == "cigarette", "the hit comes from the object actually held")
	check(float((hunt.get("smoke_spent") as Dictionary).get("cigarette", 0.0)) > 0.0,
		"and the same act burns down that object")
	for _breath in 20:
		hunt.call("_update_smoking", 1.0 / 60.0)
	var air = hunt.get("air")
	var cigarette_plume := air.get_parent().get_node_or_null("SmokeExhale") as GPUParticles3D
	check(cigarette_plume != null,
		"release automatically breathes a drifting plume into the world")
	if cigarette_plume != null:
		var tobacco_tint: Color = cigarette_plume.get_meta("smoke_tint", Color.BLACK)
		check(tobacco_tint.g - tobacco_tint.r < 0.04, "cigarette smoke stays neutral grey")
	var herb_tint: Color = hunt.call("_smoke_tint", "joint")
	check(herb_tint.g > herb_tint.r + 0.04 and herb_tint.g > herb_tint.b,
		"joint, spliff and bong smoke receive only a subtle green bias")
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
	hunt.call("_begin_smoking_draw")
	for _bong_frame in 30:
		hunt.call("_update_smoking", 1.0 / 60.0)
	var lighter := hunt.get("smoke_lighter") as Node3D
	check(lighter != null and lighter.get_node_or_null("Flame") != null,
		"the other hand flips a physical Zippo onto the bong bowl")
	check(lighter.get_node_or_null("LighterHand") != null,
		"the Zippo is itself held by an articulated lighter hand")
	check(lighter.get_node_or_null("LighterHand/HumiliationCuff") != null,
		"the lighter hand carries the same forced costume")
	check((hunt.get("smoke_lighter_lid") as Node3D).rotation.z < -1.5,
		"the Zippo lid visibly completes its flip")
	check((hunt.get("smoke_bong_audio") as AudioStreamPlayer).playing,
		"the held bong pull plays a looping water rip")
	check(float(hunt.get("body_motion").smoking_look_down) > 0.0,
		"the first-person body looks down the chamber while sinking the cone")
	hunt.call("_finish_smoking_draw")

	# Inspection is the same live hand-and-object assembly, not a separate icon.
	var inspect_press := InputEventKey.new()
	inspect_press.keycode = KEY_I
	inspect_press.pressed = true
	hunt.call("_unhandled_input", inspect_press)
	for _inspect_frame in 18:
		hunt.call("_update_smoking", 1.0 / 60.0)
		hunt.call("_update_held_inspection", 1.0 / 60.0)
	check(float(hunt.get("inspect_blend")) > 0.9, "holding I raises the equipped bong into inspection")
	var inspect_release := InputEventKey.new()
	inspect_release.keycode = KEY_I
	inspect_release.pressed = false
	hunt.call("_unhandled_input", inspect_release)

	# Weapon mounts use the same real hands and the same universal inspect verb.
	hunt.call("_equip_weapon", 1)
	var shotgun := arsenal.models.get("shotgun") as Node3D
	check(shotgun.get_node_or_null("RightGripHand") != null and shotgun.get_node_or_null("LeftGripHand") != null,
		"weapons render both hands on their authored grip anchors")
	hunt.call("_unhandled_input", inspect_press)
	var weapon_before := shotgun.rotation
	for _weapon_inspect in 12:
		hunt.call("_advance_arm", 1.0 / 60.0)
		hunt.call("_update_held_inspection", 1.0 / 60.0)
	check(shotgun.rotation.distance_to(weapon_before) > 0.15,
		"holding I turns the equipped weapon through a readable inspection pose")
	hunt.call("_unhandled_input", inspect_release)

	# The help card must teach every bind this added.
	var rows: Array = []
	for group: Dictionary in hunt.get("keys_card").groups:
		rows.append_array(group.get("rows", []) as Array)
	check(rows.any(func(row): return row[0] == "6"), "the keys card teaches the smokeable slot")
	check(rows.any(func(row): return row[0] == "HOLD RMB"), "and teaches that drawing is a hold")
	check(rows.any(func(row): return row[0] == "LMB EXHALE"), "and teaches the optional smoke control")
	check(rows.any(func(row): return row[0] == "HOLD I"), "and teaches the universal held-object inspection")

	_report()


func _report() -> void:
	print("SMOKING_ACT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
