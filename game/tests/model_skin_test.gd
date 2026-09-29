extends Node
## Greg's generated examiner (Higgsfield / Meshy, 29 September) as a SKIN on a
## BaselineHuman: it shows only on pristine zones, and the moment anything gory
## happens to a zone that zone is the rig's own body again. Gore, wounds,
## dismemberment and the X-ray cannot be hidden by it.

const SKIN := preload("res://systems/model_skin.gd")
var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _rig() -> BaselineHuman:
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("skin_test", BaselineHuman.config_from_subject({"race": "decanted"}).merged({"gore": true}, true))
	ExaminerLook.dress(rig, false)
	return rig


func _tool(arm: Node3D) -> MeshInstance3D:
	var tool := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.012, 0.012, 0.16)
	tool.mesh = box
	tool.position = Vector3(0.0, -0.36, -0.08)
	arm.add_child(tool)
	return tool


func _ready() -> void:
	var rig := _rig()
	await get_tree().process_frame
	var skin: Node3D = SKIN.attach(rig)
	check(skin != null, "the skin attaches when the media is there")
	if skin == null:
		print("MODEL_SKIN_TEST_RESULT failures=%d" % failures)
		get_tree().quit(1)
		return

	# --- The model: split into the rig's zones, on one skeleton, clips in place. ---
	var total := 0
	var every_zone := true
	for zone: String in SKIN.ZONES:
		total += int(skin.triangles_by_zone[zone])
		every_zone = every_zone and int(skin.triangles_by_zone[zone]) > 200
	check(every_zone, "every zone has a real share of the model (%s)" % str(skin.triangles_by_zone))
	check(total > 20000 and total < 21500, "every one of the model's triangles is in exactly one zone (%d)" % total)
	check(skin.player.has_animation("idle") and skin.player.has_animation("walk"), "the generated idle and walk clips are on his rig")
	check(skin.player.get_animation("walk").loop_mode == Animation.LOOP_LINEAR, "and they loop")
	var head_end: int = skin.skeleton.find_bone("head_end")
	var top: Vector3 = skin.skeleton.global_transform * skin.skeleton.get_bone_global_pose(head_end).origin
	var head := rig.parts["head"] as MeshInstance3D
	var rig_top := head.global_position.y + head.mesh.get_aabb().size.y * 0.5 * rig.scale.y
	check(absf(top.y - rig_top) < 0.12, "he stands as tall as the rig does (%.2f m against %.2f m)" % [top.y, rig_top])
	check(absf(skin.skeleton.global_transform.origin.y) < 0.05, "and his feet are on the floor")

	# --- Pristine: the skin shows, and the rig's flesh, coat and gear step aside. ---
	var right_tool := _tool(rig.parts["right_arm"])
	var left_tool := _tool(rig.parts["left_arm"])
	skin.hold_tools(right_tool, left_tool)
	skin._process(0.016)
	var all_skin := true
	for zone: String in SKIN.ZONES:
		all_skin = all_skin and skin.modes[zone] == "skin" and (skin.zone_meshes[zone] as MeshInstance3D).visible and (rig.parts[zone] as MeshInstance3D).transparency == 1.0
	check(all_skin, "a pristine body shows the skin and hides its own flesh")
	var garment := rig.parts["torso"].get_node_or_null("Garment") as Node3D
	check(garment != null and not garment.visible, "his procedural coat is hidden under the model's")
	check(right_tool.get_parent().name == "Hold_right" and left_tool.get_parent().name == "Hold_left", "his scalpel and syringe ride his hands")
	check(right_tool.visible and left_tool.visible, "and they are visible there (hiding the rig's pieces must not hide them)")

	# --- A bruise tints the skin; it is still the skin. ---
	var before: Color = (skin.zone_materials["torso"] as BaseMaterial3D).albedo_color
	rig.hit("torso", 9.0, 1.0, "blunt")
	skin._process(0.016)
	var after: Color = (skin.zone_materials["torso"] as BaseMaterial3D).albedo_color
	check(skin.modes["torso"] == "skin" and after.g < before.g, "a blow that only bruises tints the skin, as it tinted the flesh")

	# --- Anything gory hands the zone back to the rig. ---
	rig.hit("right_arm", 30.0, 2.0, "cut")
	skin._process(0.016)
	check(skin.modes["right_arm"] == "body" and not (skin.zone_meshes["right_arm"] as MeshInstance3D).visible, "a cut takes the arm out of skin mode")
	var arm := rig.parts["right_arm"] as MeshInstance3D
	check(arm.transparency < 1.0 and arm.get_node_or_null("Garment") != null and arm.get_node("Garment").visible, "and his own arm and sleeve are back, as they were")
	check(right_tool.get_parent() == arm and right_tool.visible, "the scalpel goes back to the arm that is showing")
	check(skin.modes["torso"] == "skin" and skin.modes["left_arm"] == "skin", "while the untouched zones keep the skin")
	rig.severed.append("left_leg")
	skin._process(0.016)
	check(skin.modes["left_leg"] == "body", "a severed limb is never the skin")

	# --- The X-ray sees through the body, not through a model. ---
	var xray := _rig()
	await get_tree().process_frame
	var xray_skin: Node3D = SKIN.attach(xray)
	xray_skin._process(0.016)
	xray.reveal_organs(true)
	xray_skin._process(0.016)
	var see_through := true
	for zone: String in SKIN.ZONES:
		see_through = see_through and xray_skin.modes[zone] == "body" and not (xray_skin.zone_meshes[zone] as MeshInstance3D).visible and is_equal_approx((xray.parts[zone] as MeshInstance3D).transparency, 0.62)
	check(see_through, "in the X-ray every zone is the rig's, at the rig's own see-through")
	xray.reveal_organs(false)
	xray_skin._process(0.016)
	check(xray_skin.modes["torso"] == "skin" and (xray.parts["torso"] as MeshInstance3D).transparency == 1.0, "and when it ends the skin comes back")

	# --- Beaten: the coat is the player's, the rig's coatless body shows. ---
	var beaten := _rig()
	await get_tree().process_frame
	var beaten_skin: Node3D = SKIN.attach(beaten)
	beaten_skin._process(0.016)
	beaten_skin.retire()
	var retired := true
	for zone: String in SKIN.ZONES:
		retired = retired and beaten_skin.modes[zone] == "body" and not (beaten_skin.zone_meshes[zone] as MeshInstance3D).visible
	check(retired, "retire() shows the rig's own body everywhere")

	# --- Motion: walk when he moves, idle when he stands, arms back for a wind-up. ---
	var mover := _rig()
	await get_tree().process_frame
	var mover_skin: Node3D = SKIN.attach(mover)
	for _step in 12:
		mover.position.x += 0.05
		mover_skin._process(0.03)
	check(mover_skin._clip == "walk", "moving, he walks")
	for _step in 30:
		mover_skin._process(0.03)
	check(mover_skin._clip == "idle", "standing, he idles")
	mover_skin.set_windup(1.0, false)
	check(is_equal_approx(mover_skin.raise_modifier.raise["RightArm"], 1.9) and mover_skin.raise_modifier.raise["LeftArm"] == 0.0, "a wind-up cocks the scalpel arm back")

	# --- Leaving costs nothing: the rig is exactly itself again. ---
	var leaver := _rig()
	await get_tree().process_frame
	var leaver_skin: Node3D = SKIN.attach(leaver)
	leaver_skin._process(0.016)
	leaver.remove_child(leaver_skin)
	leaver_skin.free()
	var restored_garment := leaver.parts["torso"].get_node_or_null("Garment") as Node3D
	check((leaver.parts["torso"] as MeshInstance3D).transparency == 0.0 and restored_garment != null and restored_garment.visible, "removing the skin gives the rig its own body back")

	print("MODEL_SKIN_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
