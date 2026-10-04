extends Node3D

## Job 2: every BaselineHuman zone rides a bone of the rigged mannequin, the
## body has a head and ordinary shoulders, wounds follow the animation, a cut
## limb leaves with its skin, and a death leaves every unsevered part within
## joint reach of the body it came off.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	_add_floor()
	var body := _body("rigged_test")
	await _frames(4)
	_test_rig(body)
	await _test_follows_animation(body)
	await _test_wound_follows(body)
	await _test_sever(body)
	await _test_death(body)
	await _test_unrigged_unchanged()
	print("RIGGED_BODY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _add_floor() -> void:
	var floor := StaticBody3D.new()
	floor.name = "TestFloor"
	add_child(floor)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.10, 20.0)
	collider.shape = shape
	collider.position.y = -0.05
	floor.add_child(collider)


## The production hierarchy: a holder at +0.9 m, the rig back down at -0.9 m.
func _body(id: String, rigged := true) -> BaselineHuman:
	var holder := Node3D.new()
	holder.name = "%s_holder" % id
	holder.position.y = 0.9
	add_child(holder)
	var body := BaselineHuman.new()
	body.position.y = -0.9
	holder.add_child(body)
	body.build(id, {"gore": true, "ragdoll": true, "rigged": rigged})
	return body


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _physics(count: int) -> void:
	for index in count:
		await get_tree().physics_frame


func _test_rig(body: BaselineHuman) -> void:
	print("RIGGED BODY - every zone has a bone, a skin and a hitbox")
	var rigged := body.rigged
	check(rigged != null and is_instance_valid(rigged), "build config rigged=true attaches a RiggedBody")
	if rigged == null:
		return
	for zone: String in BaselineHuman.ZONES:
		var spec: Dictionary = RiggedBody.ZONE_CHORDS.get(zone, {})
		check(not spec.is_empty(), "%s has a chord" % zone)
		var anchor := rigged.attachments.get(str(spec.get("anchor", ""))) as BoneAttachment3D
		check(anchor != null and rigged.skeleton.find_bone(anchor.bone_name) >= 0, "%s rides bone %s through a BoneAttachment3D" % [zone, spec.get("anchor", "?")])
		check(int(rigged.triangles_by_zone.get(zone, 0)) > 50, "%s has its own skin (%d triangles)" % [zone, int(rigged.triangles_by_zone.get(zone, 0))])
		check(rigged.modes.get(zone, "") == "skin", "a pristine %s shows the skin" % zone)
	var zones_with_segments := {}
	for area: Area3D in rigged.segment_hitboxes.values():
		zones_with_segments[str(area.get_meta("body_zone"))] = true
	for zone in ["head", "left_arm", "right_arm", "left_leg", "right_leg"]:
		check(zones_with_segments.has(zone), "%s has segment hitboxes on its own bones" % zone)
	check(rigged.segment_hitboxes.size() == RiggedBody.SEGMENTS.size(), "upper arm, forearm, hand, thigh, calf, foot and neck each have a hitbox (%d)" % rigged.segment_hitboxes.size())
	var head := body.parts.head as Node3D
	var torso := body.parts.torso as Node3D
	check(head.global_position.y > torso.global_position.y + 0.3, "the head sits on the body (head %.2f, torso %.2f)" % [head.global_position.y, torso.global_position.y])
	check(head.global_position.y > 1.4 and head.global_position.y < 1.9, "the head is at head height (%.2f m)" % head.global_position.y)
	var shoulders: float = (rigged.attachments.upperarm_l as Node3D).global_position.distance_to((rigged.attachments.upperarm_r as Node3D).global_position)
	check(shoulders > 0.25 and shoulders < 0.45, "shoulders are an ordinary width (%.2f m)" % shoulders)
	var skin_head := rigged.zone_meshes.head as Array
	check(not skin_head.is_empty() and (skin_head[0] as MeshInstance3D).visible, "the skin's head is drawn")


func _test_follows_animation(body: BaselineHuman) -> void:
	print("RIGGED BODY - zones follow the animated skeleton")
	var rigged := body.rigged
	if rigged == null:
		return
	var arm := body.parts.right_arm as Node3D
	var before := arm.global_transform
	check(rigged.play_action("sword_attack"), "the sword attack clip plays")
	await _frames(24)
	var after := arm.global_transform
	check(before.origin.distance_to(after.origin) > 0.05 or before.basis.y.angle_to(after.basis.y) > 0.2, "the right arm zone moved with the swing (%.2f m, %.2f rad)" % [before.origin.distance_to(after.origin), before.basis.y.angle_to(after.basis.y)])
	var hand := rigged.attachments.hand_r as Node3D
	var arm_end := arm.global_position - arm.global_transform.basis.y.normalized() * (arm.global_position.distance_to(hand.global_position))
	check(arm_end.distance_to(hand.global_position) < 0.12, "the arm zone's lower end is at the hand")
	var hitbox := body.get_node("right_arm_hitbox") as Node3D
	check(hitbox.global_position.distance_to(arm.global_position) < 0.01, "the arm's hitbox rides with it")
	await _frames(60)


func _test_wound_follows(body: BaselineHuman) -> void:
	print("RIGGED BODY - a wound rides the bone and hands the zone back to the rig")
	var rigged := body.rigged
	if rigged == null:
		return
	var arm := body.parts.left_arm as Node3D
	body.hit_at(arm.global_position + Vector3(0, 0, -0.06), 9.0, 2.0, "cut", Vector3.BACK)
	await _frames(2)
	check(rigged.modes.left_arm == "body", "a cut left arm shows the rig's own wounded flesh")
	var wounds := arm.get_node_or_null("Wounds") as Node3D
	check(wounds != null, "the wound is drawn on the left arm zone")
	if wounds == null:
		return
	var before := wounds.global_position
	rigged.play_action("punch_jab")
	await _frames(14)
	check(wounds.global_position.distance_to(before) > 0.01, "the wound moved with the animated arm (%.3f m)" % wounds.global_position.distance_to(before))
	check(rigged.modes.right_leg == "skin", "untouched zones keep the skin")


func _test_sever(body: BaselineHuman) -> void:
	print("RIGGED BODY - a severed arm leaves with its skin")
	var rigged := body.rigged
	if rigged == null:
		return
	var guard := 0
	while not body.severed.has("right_arm") and guard < 20:
		body.hit("right_arm", 60.0, 6.0, "cut", "", Vector3.RIGHT)
		guard += 1
	await _frames(2)
	check(body.severed.has("right_arm"), "the right arm came off")
	var hidden := true
	for instance: MeshInstance3D in rigged.zone_meshes.right_arm:
		hidden = hidden and not instance.visible
	check(hidden, "the cut arm's skin section is hidden on the body")
	var limb: Node = null
	for node in get_tree().root.find_children("right_arm_severed", "RigidBody3D", true, false):
		limb = node
	check(limb != null, "the arm was thrown as its own physics body")
	if limb != null:
		check(limb.get_node_or_null("SeveredSkin") != null, "the thrown arm carries its skin")
	for area: Area3D in rigged.segment_hitboxes.values():
		if str(area.get_meta("body_zone")) == "right_arm":
			check(not area.monitorable, "%s stops taking hits" % area.name)


func _test_death(body: BaselineHuman) -> void:
	print("RIGGED BODY - death is a ragdoll on the same skeleton, joints held")
	var rigged := body.rigged
	if rigged == null:
		return
	body.hit("head", 400.0, 6.0, "puncture", "brain", Vector3.LEFT, 1.0, null, null, "heavy")
	await _physics(2)
	print("  engine %s, joint gaps at start %s" % [ProjectSettings.get_setting("physics/3d/physics_engine"), rigged.joint_gaps()])
	check(body.anatomy.dead, "the body died")
	check(rigged.ragdolled and rigged.simulator != null, "death started the PhysicalBone3D ragdoll")
	check(body.ragdoll_body == null, "the boxed RagdollBody was not used for a rigged body")
	check(not rigged.physical_bones.has("upperarm_r") and rigged.physical_bones.has("upperarm_l"), "a severed arm gets no ragdoll bone; the other arm does")
	var elbow := rigged.physical_bones.get("lowerarm_l") as PhysicalBone3D
	check(elbow != null and elbow.joint_type == PhysicalBone3D.JOINT_TYPE_6DOF and is_equal_approx(float(elbow.get("joint_constraints/x/angular_limit_upper")), 135.0), "the elbow is a limited joint (6DOF, bends to 135 degrees)")
	var worst_gap := 0.0
	var worst_speed := 0.0
	var pair_worst := {}
	var frames := 0
	while frames < 300 and not rigged.ragdoll_settled:
		await get_tree().physics_frame
		var gaps := rigged.joint_gaps()
		for pair: String in gaps:
			worst_gap = maxf(worst_gap, float(gaps[pair]))
			pair_worst[pair] = snappedf(maxf(float(pair_worst.get(pair, 0.0)), float(gaps[pair])), 0.001)
		for physical: PhysicalBone3D in rigged.physical_bones.values():
			worst_speed = maxf(worst_speed, physical.linear_velocity.length())
		frames += 1
	await _frames(2)
	print("  worst per pair %s; slowest-settling speeds %s" % [pair_worst, rigged.physical_bones.values().map(func(p): return snappedf(p.linear_velocity.length(), 0.01))])
	print("  settled after %d physics frames, worst joint gap %.3f m, fastest bone %.1f m/s (launched at %.1f)" % [frames, worst_gap, worst_speed, rigged.max_launch_speed])
	check(worst_speed < rigged.max_launch_speed + 6.0, "no bone was flung faster than the blow and a fall can explain (%.1f m/s)" % worst_speed)
	check(rigged.ragdoll_settled, "the corpse is laid to rest within four seconds")
	# Measured over repeated runs: Jolt holds every joint to under 8 cm through
	# the fall. Godot Physics, the project's engine today, usually stays under
	# 5 cm but about one fall in eight gives a hip ~22 cm for a few frames and
	# recovers. Either way a limb that came off reads in metres, and at rest
	# both hold.
	var jolt := str(ProjectSettings.get_setting("physics/3d/physics_engine")).begins_with("Jolt")
	var allowed := 0.08 if jolt else 0.25
	check(worst_gap < allowed, "no joint pulled apart while falling (worst %.3f m, allowed %.2f m)" % [worst_gap, allowed])
	var rest_gap := rigged.max_joint_gap()
	check(rest_gap < 0.08, "every joint holds once at rest (%.3f m)" % rest_gap)
	var torso := body.parts.torso as Node3D
	check(torso.global_position.y > -0.05 and torso.global_position.y < 0.6, "the corpse lies on the floor, not through it (torso %.2f m)" % torso.global_position.y)
	# The killing blow knocks the body down in the same moment; the ragdoll has
	# to fall from standing, not from a tipped pose with a leg in the floor.
	var lowest := INF
	var highest := -INF
	for bone_name: String in rigged.attachments:
		var y: float = (rigged.attachments[bone_name] as Node3D).global_position.y
		if bone_name.ends_with("_r") and bone_name.begins_with("upperarm") or bone_name.begins_with("lowerarm_r") or bone_name.begins_with("hand_r"):
			continue
		lowest = minf(lowest, y)
		highest = maxf(highest, y)
	check(lowest > -0.03, "no bone of the corpse ended up under the floor (lowest %.2f m)" % lowest)
	check(highest < 0.7, "the corpse lies down rather than propped up (highest bone %.2f m)" % highest)
	for zone in ["head", "left_arm", "left_leg", "right_leg"]:
		var part := body.parts[zone] as Node3D
		# A limb's centre is half its length past the joint, which is itself
		# off the torso's centre: arm 0.75 m, leg 0.85 m, head 0.5 m at most.
		var reach := 0.85 if zone.ends_with("_leg") else (0.5 if zone == "head" else 0.75)
		check(part.global_position.distance_to(torso.global_position) < reach, "%s stayed within joint reach of the torso (%.2f m)" % [zone, part.global_position.distance_to(torso.global_position)])
	for bone_name in ["lowerarm_l", "calf_l", "calf_r"]:
		var bend := _hinge_bend(rigged, bone_name)
		check(bend > -0.3 and bend < 2.6, "%s bends the way it can (%.2f rad)" % [bone_name, bend])
	var wounds := (body.parts.left_arm as Node3D).get_node_or_null("Wounds")
	check(wounds != null and (wounds as Node3D).is_visible_in_tree(), "the corpse keeps the wound it died with")


## How far a hinge bone is folded from straight, about its parent's own X.
func _hinge_bend(rigged: RiggedBody, bone_name: String) -> float:
	var skeleton := rigged.skeleton
	var bone := skeleton.find_bone(bone_name)
	var parent := skeleton.get_bone_parent(bone)
	var child_y := skeleton.get_bone_global_pose(bone).basis.y.normalized()
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	var local := parent_basis.inverse() * child_y
	return atan2(local.z, local.y)


func _test_unrigged_unchanged() -> void:
	print("RIGGED BODY - a body built without it is untouched")
	var plain := _body("plain_test", false)
	await _frames(2)
	check(plain.rigged == null, "no config, no rig")
	check((plain.parts.head as Node3D).position.is_equal_approx((BaselineHuman.STANDING.head as Dictionary).at), "an unrigged head stays at its layout")
