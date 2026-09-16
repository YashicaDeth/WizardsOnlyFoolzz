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
	var field_lens: Control = hunt.get("field_lens") as Control
	check(field_lens != null and float(field_lens.treatment().curvature) > 0.0,
		"ordinary first-person play passes through a slight permanent curved lens")
	hunt.call("_update_hud")
	var reliquary: Control = hunt.get("held_reliquary") as Control
	check(reliquary != null and int(reliquary.displayed_source_id) == held.get_instance_id() and int(reliquary.mesh_count) > 0,
		"the bottom-right reliquary presents the real held cigarette as rotating 3D geometry")
	var field_map: Control = hunt.get("living_map") as Control
	check(field_map != null and field_map.get("satellite") != null,
		"the lower-left field radar shares the real satellite camera with the opened map")
	check(held.get_parent() == rig.parts.right_arm, "the object belongs to the body's real right arm")
	check(held.get_node_or_null("anchor_grip") != null, "and it arrived through HeldGear's grip anchor")
	check(held.get_node_or_null("SmokingGripHand") != null,
		"an articulated pinching hand visibly holds the cigarette")
	check(held.get_node_or_null("SmokingGripHand/HumiliationCuff") != null,
		"the hand wears the elites' oversized jester restraint cuff")
	var smoking_hand := held.get_node("SmokingGripHand") as Node3D
	check(smoking_hand.scale.x < 1.0 and smoking_hand.position.y < -0.04,
		"the cigarette sits above a compact palm instead of being buried inside it")
	var smoking_index := smoking_hand.get_node("index/bone0") as Node3D
	var smoking_ring := smoking_hand.get_node("ring/bone0") as Node3D
	check(absf(smoking_index.rotation.x) < absf(smoking_ring.rotation.x) * 0.7,
		"the smoking fingers stay visibly splayed instead of closing into a fist")
	var cigarette_inspect: Dictionary = hunt.call("_smoke_inspection_pose", "cigarette", 1.0)
	var vape_inspect: Dictionary = hunt.call("_smoke_inspection_pose", "vape", 1.0)
	var bong_inspect: Dictionary = hunt.call("_smoke_inspection_pose", "bong", 1.0)
	check((cigarette_inspect.rotation as Vector3).distance_to(vape_inspect.rotation as Vector3) > 0.25 and
		(cigarette_inspect.position as Vector3).distance_to(bong_inspect.position as Vector3) > 0.15,
		"rolled paper, vape and bong have distinct inspection compositions")
	var camera := hunt.get("camera") as Camera3D
	var smoking_forearm := held.get_node_or_null("SmokingGripHand/FirstPersonForearm") as Node3D
	check(smoking_forearm != null and smoking_forearm.get_node_or_null("TaperedSleeve") != null,
		"a costumed forearm continues from the smoking hand toward the screen edge")
	hunt.call("_update_first_person_forearms")
	var smoking_sleeve := smoking_forearm.get_node_or_null("TaperedSleeve") as MeshInstance3D
	var arm_entry := camera.to_local(smoking_forearm.global_position)
	check(smoking_forearm.top_level and smoking_forearm.visible and smoking_sleeve != null and (smoking_sleeve.mesh as CylinderMesh).height > 0.08,
		"the first-person forearm is stretched from the frame to the live wrist")
	check(arm_entry.x > 0.30 and arm_entry.y < -0.35,
		"the smoking arm enters from below the right edge rather than floating at the hand")
	var arsenal = hunt.get("arsenal")
	check((arsenal.models.values() as Array).all(func(model): return not (model as Node3D).visible),
		"holding it puts the weapon away")

	# Y transfers a one-hand smokeable to an implied lip point. The hand carries
	# it there before leaving the frame; the same RMB draw then works hands-free.
	var lip_toggle := InputEventKey.new()
	lip_toggle.keycode = KEY_Y
	lip_toggle.pressed = true
	hunt.call("_unhandled_input", lip_toggle)
	for _transfer in 20:
		hunt.call("_update_smoking", 1.0 / 60.0)
	var lip_position := camera.to_local(held.global_position)
	check(bool(hunt.get("smoke_mouth_held")) and float(hunt.get("smoke_mouth_blend")) > 0.95,
		"Y transfers the cigarette into a persistent lip-hold state")
	check(not smoking_hand.visible and absf(lip_position.x) < 0.08 and lip_position.y < 0.0,
		"the cigarette stays beneath the reticle while the released hand leaves the frame")

	# Close prop lights follow the world's exposure rather than throwing the same
	# hard pool and shadows at noon that they do in darkness.
	var saved_minute := WorldHistory.world_minute
	WorldHistory.world_minute = 2.0 * 60.0
	var night_prop_light: float = hunt.call("_close_prop_light_scale")
	WorldHistory.world_minute = 12.0 * 60.0
	var day_prop_light: float = hunt.call("_close_prop_light_scale")
	WorldHistory.world_minute = saved_minute
	check(day_prop_light < night_prop_light * 0.5,
		"embers, Zippo and inspection glint cast substantially less light in daylight")

	# Hold rather than tap: the visible heat and the delivered grade are driven
	# by the same accumulated duration.
	hunt.call("_begin_smoking_draw")
	var lung_stain_before := float(rig.anatomy.lung_state().stain)
	var length_before_draw := Smokeables.spent_of(held)
	for _frame in 96:
		hunt.call("_update_smoking", 1.0 / 60.0)
	var held_seconds := float(hunt.get("smoke_held"))
	check(held_seconds > 1.5, "holding RMB accumulates a real draw duration")
	check(Smokeables.spent_of(held) > length_before_draw,
		"the cigarette burns shorter continuously while the button is held")
	var cigarette_in_view := camera.to_local(held.global_position)
	check(absf(cigarette_in_view.x) < 0.10 and cigarette_in_view.y < 0.0,
		"the lit cigarette rises beside the first-person reticle at the mouth")
	var result: Dictionary = hunt.call("_finish_smoking_draw")
	check(bool(result.get("ok", false)), "releasing RMB lands the draw")
	check(str(result.get("device", "")) == "cigarette", "the hit comes from the object actually held")
	check(bool(hunt.get("smoke_mouth_held")), "the same RMB draw works while the cigarette remains in the mouth")
	check(float((hunt.get("smoke_spent") as Dictionary).get("cigarette", 0.0)) > 0.0,
		"and the same act burns down that object")
	check(float(rig.anatomy.lung_state().stain) > lung_stain_before,
		"the draw visibly and persistently stains the body's real lung organs")
	check((WorldHistory.subject("player").get("anatomy_state", {}) as Dictionary).has("organs"),
		"the lung result is written through to the persistent body record")
	hunt.call("_update_hud")
	var field_hud: Control = hunt.get("field_interface") as Control
	check(float(field_hud.lung_stain) > lung_stain_before and field_hud.lung_linger > 0.0,
		"the contextual X-ray reads the same live lung state after the draw")
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
	hunt.call("_toggle_mouth_hold")
	for _take_back in 20:
		hunt.call("_update_smoking", 1.0 / 60.0)
	check(not bool(hunt.get("smoke_mouth_held")) and smoking_hand.visible,
		"toggling again returns the cigarette to the waiting hand")

	# Cycle to the fifth object. Its second hand and weapon cost must be visible,
	# not merely catalog metadata.
	for _next in 4:
		hunt.call("_cycle_smokeable")
	var bong := hunt.get("smoke_model") as Node3D
	check(str(bong.get_meta("device_id", "")) == "bong", "the held slot reaches the bong")
	check(bong.get_node_or_null("BongSupportHand") != null, "the bong physically takes the second hand")
	check((arsenal.models.values() as Array).all(func(model): return not (model as Node3D).visible),
		"and no weapon remains in either hand")
	var before_night_bong: float = WorldHistory.world_minute
	WorldHistory.world_minute = 22.0 * 60.0
	hunt.call("_begin_smoking_draw")
	for _bong_frame in 30:
		hunt.call("_update_smoking", 1.0 / 60.0)
	var lighter := hunt.get("smoke_lighter") as Node3D
	check(lighter != null and lighter.get_node_or_null("Flame") != null,
		"the other hand flips a physical Zippo onto the bong bowl")
	var lighter_light := lighter.get_node_or_null("FlameLight") as OmniLight3D
	check(lighter_light != null and lighter_light.visible and lighter_light.omni_range >= 7.0,
		"the open Zippo casts a warm navigable pool through the dark")
	check(lighter.get_node_or_null("LighterHand") != null,
		"the Zippo is itself held by an articulated lighter hand")
	check(lighter.get_node_or_null("LighterHand/HumiliationCuff") != null,
		"the lighter hand carries the same forced costume")
	check((lighter.get_node("LighterHand") as Node3D).scale.x < 1.0,
		"the Zippo hand is compact enough for the lighter and flame to remain readable")
	check(lighter.get_node_or_null("LighterHand/FirstPersonForearm") != null,
		"the lighter hand enters on its own continuous opposite forearm")
	check((hunt.get("smoke_lighter_lid") as Node3D).rotation.z < -1.5,
		"the Zippo lid visibly completes its flip")
	check((hunt.get("smoke_bong_audio") as AudioStreamPlayer).playing,
		"the held bong pull plays a looping water rip")
	check(float(hunt.get("body_motion").smoking_look_down) > 0.0,
		"the first-person body looks down the chamber while sinking the cone")
	hunt.call("_finish_smoking_draw")
	WorldHistory.world_minute = before_night_bong

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
	check(shotgun.get_node_or_null("RightGripHand/FirstPersonForearm") != null and shotgun.get_node_or_null("LeftGripHand/FirstPersonForearm") != null,
		"both weapon hands remain connected to lower-left and lower-right arms")
	hunt.call("_unhandled_input", inspect_press)
	var weapon_before := shotgun.rotation
	var shotgun_left := shotgun.get_node("LeftGripHand") as Node3D
	var shotgun_left_rest: Vector3 = shotgun_left.position
	for _weapon_inspect in 12:
		hunt.call("_advance_arm", 1.0 / 60.0)
		hunt.call("_update_held_inspection", 1.0 / 60.0)
	check(shotgun.rotation.distance_to(weapon_before) > 0.15,
		"holding I turns the equipped weapon through a readable inspection pose")
	check(shotgun_left.position.z > shotgun_left_rest.z + 0.035,
		"the shotgun support hand slides over the forend for a receiver check")
	hunt.call("_unhandled_input", inspect_release)

	# A sidearm is press-checked rather than copied from the long-gun turn.
	hunt.call("_equip_weapon", 2)
	hunt.set("inspect_blend", 1.0)
	hunt.set("inspect_held", true)
	hunt.call("_advance_arm", 1.0 / 60.0)
	var sidearm := arsenal.models.get("sidearm") as Node3D
	var pistol_left := sidearm.get_node("LeftGripHand") as Node3D
	var pistol_left_rest: Vector3 = pistol_left.position
	hunt.call("_update_held_inspection", 0.0)
	check(pistol_left.position.y > pistol_left_rest.y + 0.05,
		"the pistol support hand leaves its cup and pinches the slide for a press-check")

	# The sword presents its edge and opens the off hand toward the forte.
	hunt.call("_equip_weapon", 0)
	hunt.call("_advance_arm", 1.0 / 60.0)
	var sword := arsenal.models.get("sword") as Node3D
	var sword_left := sword.get_node("LeftGripHand") as Node3D
	var sword_left_rest: Vector3 = sword_left.position
	hunt.call("_update_held_inspection", 0.0)
	check(sword_left.position.z < sword_left_rest.z - 0.05,
		"the sword inspection releases the off hand to read the edge instead of mimicking a firearm")
	hunt.set("inspect_held", false)

	# The help card must teach every bind this added.
	var rows: Array = []
	for group: Dictionary in hunt.get("keys_card").groups:
		rows.append_array(group.get("rows", []) as Array)
	check(rows.any(func(row): return row[0] == "6"), "the keys card teaches the smokeable slot")
	check(rows.any(func(row): return row[0] == "Y"), "and teaches the reversible hand-to-mouth transfer")
	check(rows.any(func(row): return row[0] == "HOLD RMB"), "and teaches that drawing is a hold")
	check(rows.any(func(row): return row[0] == "LMB EXHALE"), "and teaches the optional smoke control")
	check(rows.any(func(row): return row[0] == "HOLD I"), "and teaches the universal held-object inspection")

	_report()


func _report() -> void:
	print("SMOKING_ACT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
