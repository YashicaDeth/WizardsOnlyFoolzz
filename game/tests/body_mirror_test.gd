extends Node3D

## B9.1 "the mirror renders this rig live, with everything done to it" and B9.2
## "including the things you cannot see on yourself in first person".
##
## The claim that matters is *live*. A portrait that is built once, or a second
## rig kept in step by hand, passes a screenshot and fails the moment somebody
## loses an arm. So the test does damage and then asks whether the reflection
## changed — which it can only answer because the mirror renders the real body.

const HUMAN := preload("res://systems/baseline_human.gd")
const MIRROR := preload("res://systems/body_mirror.gd")

var failures: Array[String] = []

func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	get_window().size = Vector2i(900, 600)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 40, 0)
	light.light_energy = 1.8
	add_child(light)

	var rig: BaselineHuman = HUMAN.new()
	add_child(rig)
	rig.build("mirrored", {"gore": true})
	await get_tree().process_frame

	var mirror: BodyMirror = MIRROR.new()
	add_child(mirror)
	mirror.watch(rig)
	mirror.position = Vector3(0, 1.1, 1.6)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- it is the real body, not a copy -----------------------------------
	check(mirror.viewport != null, "the mirror has a render surface")
	check(not mirror.viewport.own_world_3d, "and it shares the world rather than owning one — which is what makes it the real body and not a second one to keep in step")
	check(mirror.subject == rig, "it is pointed at the rig itself")

	# --- it frames a person, not their boots -------------------------------
	var eye: Vector3 = mirror.eye_position()
	check(eye.y > rig.global_position.y + 0.8, "the reflected eye is at chest height, not at the floor")
	check(eye.distance_to(rig.global_position + Vector3(0, 1.05, 0)) > 0.9, "and standing far enough back to see a whole body")

	# --- B9.2: it can show you what you cannot see on yourself -------------
	mirror.set_facing(MIRROR.Facing.FRONT)
	await get_tree().process_frame
	var front: Vector3 = mirror.eye_position()
	mirror.set_facing(MIRROR.Facing.BACK)
	await get_tree().process_frame
	var back: Vector3 = mirror.eye_position()
	check(front.distance_to(back) > 1.5, "front and back are genuinely different viewpoints (%.2f m apart)" % front.distance_to(back))
	# The one that matters: turning the body has to turn the reflection, or the
	# mirror is fixed to the world and stops being a mirror when anyone moves.
	mirror.set_facing(MIRROR.Facing.FRONT)
	await get_tree().process_frame
	var before_turn: Vector3 = mirror.eye_position()
	rig.rotation.y = PI * 0.5
	await get_tree().process_frame
	await get_tree().process_frame
	var after_turn: Vector3 = mirror.eye_position()
	check(before_turn.distance_to(after_turn) > 0.5, "turning the body turns the reflection — the eye is in the subject's frame, not the world's")
	rig.rotation.y = 0.0

	# --- B9.1: live. Damage the body, and the reflection is of a damaged body.
	# It renders the same MeshInstance3Ds, so "did the reflection update" is the
	# same question as "did the body change" — which is exactly the property a
	# maintained copy could not have.
	var torso := rig.parts.get("torso") as Node3D
	var wounds_before: int = (rig.wound_marks.get("torso", []) as Array).size()
	rig.hit_at(torso.global_position + Vector3(0, 0.10, 0.14), 22.0, 5.0, "ballistic", Vector3(0, 0, -1))
	await get_tree().process_frame
	var wounds_after: int = (rig.wound_marks.get("torso", []) as Array).size()
	check(wounds_after > wounds_before, "sanity: the body took a wound")
	var holder := torso.get_node_or_null("Wounds")
	check(holder != null and holder.get_child_count() > 0, "the wound exists as geometry on the rig the mirror is rendering — so it is in the reflection by construction")

	# Sever a limb and check the mirror is showing a body that is missing one.
	rig.severed.append("left_arm")
	rig.call("_refresh_zone", "left_arm")
	await get_tree().process_frame
	check(rig.severed.has("left_arm"), "sanity: an arm has come off")
	var arm := rig.parts.get("left_arm") as Node3D
	check(arm == null or not arm.visible or not is_instance_valid(arm), "and the arm is gone from the rig the mirror renders, so it is gone from the mirror")

	# --- it can be switched off ---------------------------------------------
	# A second full render of the scene is not free, and a mirror in a room the
	# player has left should not be costing frames.
	mirror.stop()
	check(mirror.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "a mirror nobody is looking at stops rendering")
	mirror.resume()
	check(mirror.viewport.render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE, "and starts again when it is")

	print("BODY_MIRROR_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
