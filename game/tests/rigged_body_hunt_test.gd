extends Node

## Job 2 in the real route: the Hunt's player body and its encounter bodies
## are RiggedBodies. In third person the player shows a skinned head and
## shoulders riding the animation; in first person the skin's head is hidden
## and the arms go back to the first-person rig, exactly as before.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _skin_shown(rigged: RiggedBody, zone: String) -> bool:
	for instance: MeshInstance3D in rigged.zone_meshes.get(zone, []):
		if instance.visible:
			return true
	return false


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0

	var rig: BaselineHuman = hunt.player_rig
	var rigged: RiggedBody = rig.rigged
	check(rigged != null and is_instance_valid(rigged), "the Hunt's player body is rigged")
	if rigged == null:
		_finish()
		return

	print("third person: a whole body, head and shoulders")
	hunt.third_person = true
	for _tick in 90:
		hunt._update_camera()
		await get_tree().process_frame
	check(rigged.motion_source == hunt.body_motion, "the rig follows the player's HunterBodyMotion")
	check(_skin_shown(rigged, "head"), "third person draws the skin's head")
	check(_skin_shown(rigged, "torso") and _skin_shown(rigged, "right_arm"), "and its torso and arms")
	var band := (rig.parts.head as Node3D).get_node_or_null("head_ServoBand_0") as Node3D
	check(band == null or band.is_visible_in_tree(), "the factory hardware's servo bands still show on the skinned head")
	var cap := (rig.parts.head as Node3D).get_node_or_null("GarmentExtra_bell_cap") as Node3D
	check(cap == null or cap.is_visible_in_tree(), "the jester's bell cap is still worn")
	check(rigged.arms_driven, "the arms ride the skeleton")
	var shoulders: float = (rigged.attachments.upperarm_l as Node3D).global_position.distance_to((rigged.attachments.upperarm_r as Node3D).global_position)
	check(shoulders < 0.45, "the shoulders are an ordinary width (%.2f m)" % shoulders)
	var sleeve := (rig.parts.left_arm as Node3D).get_node_or_null("ForcedJesterSleeve") as Node3D
	check(sleeve == null or not sleeve.visible, "the puffed jester sleeves that made the shoulders massive are not drawn over the skin")
	var head_part := rig.parts.head as Node3D
	var head_bone := rigged.attachments.Head as Node3D
	check(head_part.global_position.distance_to(head_bone.global_position) < 0.25, "the head zone (hits, wounds, X-ray) sits on the skeleton's head")
	var hand := (rig.parts.right_arm as Node3D)
	check(hand.global_position.distance_to((rigged.attachments.hand_r as Node3D).global_position) < 0.45, "the weapon arm zone reaches the skeleton's hand")

	print("first person: no skull in the lens, first-person arms as before")
	hunt.third_person = false
	for _tick in 60:
		hunt._update_camera()
		await get_tree().process_frame
	check(not _skin_shown(rigged, "head"), "first person hides the skin's head")
	check(not rigged.arms_driven, "first person hands the arms back to the first-person rig")
	check(not _skin_shown(rigged, "left_arm") and not _skin_shown(rigged, "right_arm"), "and draws the rig's own arms there")

	print("encounter bodies are rigged too")
	var rigged_actors := 0
	for actor: Dictionary in hunt.encounter_actors:
		var actor_rig := actor.get("rig") as BaselineHuman
		if actor_rig != null and is_instance_valid(actor_rig) and actor_rig.rigged != null:
			rigged_actors += 1
	check(hunt.encounter_actors.is_empty() or rigged_actors == hunt.encounter_actors.size(), "every encounter body in the Hunt is rigged (%d of %d)" % [rigged_actors, hunt.encounter_actors.size()])
	_finish()


func _finish() -> void:
	print("RIGGED_BODY_HUNT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
