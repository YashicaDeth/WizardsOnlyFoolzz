extends Node

## AN1.2-AN1.6. `limb_momentum.gd` passed ten checks this morning and was
## attached to nothing, which is the exact failure this project keeps repeating.
## So this test does not re-check the physics — `limb_momentum_test.gd` owns
## that. It checks that the Hunt Grounds is actually driving it.

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

	var arm = hunt.get("arm")
	check(arm != null, "the hunt builds an arm")
	if arm == null:
		_report()
		return

	# ---- AN1.5: it is carrying whatever the player is holding.
	print("carrying %.2f kg at %.2f m reach" % [arm.mass, arm.reach])
	check(arm.mass > 0.0 and arm.reach > 0.0, "the arm is carrying a real weapon")

	# ---- AN1.2: turning throws it. Feed the hunt the same motion a mouse makes.
	# Through `apply_look`, not through a synthetic InputEventMouseMotion: the
	# hunt gates its mouse branch on MOUSE_MODE_CAPTURED, which a headless run
	# can never be, so feeding it events measured gravity sag and passed.
	var rest: Vector3 = arm.at
	for _frame in 8:
		hunt.call("apply_look", Vector2(90.0 * 0.0026, 0.0))
		await tree.physics_frame
	var thrown: float = (arm.at - arm.anchor).length()
	print("thrown %.4f m off the anchor" % thrown)
	check(thrown > 0.12, "turning the camera genuinely throws the weapon")
	check(arm.at != rest, "and the arm is genuinely being advanced")

	# ---- AN1.4: that swing is worth something, and it is recorded.
	var worth: float = arm.commitment()
	print("commitment after a hard turn: %.3f" % worth)
	check(worth > 0.15, "a hard turn is worth a real blow, not a rounding error")

	# ---- and a still hand is worth much less than a swung one.
	for _frame in 120:
		await tree.physics_frame
	var still: float = arm.commitment()
	print("commitment at rest: %.3f" % still)
	check(still < worth, "a still hand is worth less than a swung one")
	check((arm.at - arm.anchor).length() < 0.12, "and the weapon settles back to the hand")

	# ---- AN1.6: fatigue tracks stamina rather than being set by hand.
	hunt.set("stamina", 100.0)
	await tree.physics_frame
	var fresh: float = arm.fatigue
	hunt.set("stamina", 0.0)
	await tree.physics_frame
	var spent: float = arm.fatigue
	print("fatigue: fresh %.2f  spent %.2f" % [fresh, spent])
	check(fresh < 0.05, "a full player has a fresh arm")
	check(spent > 0.9, "an empty player has a spent one")

	# ---- AN1.3: the weapon model is posed off the arm, not off an animation.
	var arsenal = hunt.get("arsenal")
	if arsenal != null and arsenal.models.has(str(arsenal.current_id)):
		var model: Node3D = arsenal.models[str(arsenal.current_id)]
		check(model.has_meta("rest_position"), "the weapon model remembers where it rests")
		hunt.set("stamina", 100.0)
		var before: Vector3 = model.position
		for _frame in 6:
			hunt.call("apply_look", Vector2(-140.0 * 0.0026, 40.0 * 0.0024))
			await tree.physics_frame
		print("model moved %.4f m" % model.position.distance_to(before))
		check(model.position.distance_to(before) > 0.02, "the weapon is drawn where the arm put it")

	# ---- AN1.8/O5.1 v5. Greg, 2026-09-14: flipped on with a controller in
	# hand, which is what this line always said the decision needed. Checked
	# as a real damage difference on a real body rather than the flag alone,
	# since a flag that does nothing is exactly the failure this file exists
	# to catch (see its own header).
	check(hunt.get("momentum_damage") == true, "commitment now reaches the damage number")
	hunt.call("_equip_weapon", 0) # sword

	# A committed swing: the same hard turn AN1.2 measured above, landed
	# while the arm is still genuinely in motion. The probe is placed along
	# wherever that turn actually leaves the camera facing, read back from
	# the real state rather than assumed, since AN1.2's own turn has already
	# rotated yaw well off whatever it started at. Which single zone a level
	# swing opens depends on the target's exact height relative to the
	# player's own aim (AF1.7/zone_precision_test's own territory) — not
	# this test's concern, so the damage is read across every zone rather
	# than assuming "torso" is the one that answers.
	for _frame in 8:
		hunt.call("apply_look", Vector2(90.0 * 0.0026, 0.0))
		await tree.physics_frame
	var forward: Vector3 = hunt.get("HUNTER_MOTOR").wish_direction(Vector2(0, -1), hunt.get("yaw"))
	var probe_at: Vector3 = hunt.get("player") + forward * 1.6 + Vector3(0, -0.5, 0)
	hunt.set("attack_cooldown", 0.0)
	arsenal = hunt.get("arsenal")

	# AE1-AE5's own Bone Yard population means the nearest-actor swing this
	# section drives never has just one body to choose from — a fresh probe
	# per attempt, explicitly locked, so the swing lands on the one body
	# each half of this actually checks rather than whichever stranger
	# happened to spawn closer that time.
	hunt.call("_spawn_encounter_actor", {"instance_id": "commitment_probe_hard", "kind": "hostile"}, probe_at)
	var hard_probe: Dictionary = hunt.get("encounter_actors")[-1]
	(hard_probe.node as Node3D).position = probe_at
	hunt.set("lock_target", str(hard_probe.subject_id))
	arsenal.cooldown = 0.0
	var total_before_hard := 0.0
	for zone: Dictionary in hard_probe.anatomy.zones.values():
		total_before_hard += float(zone.get("health", 0.0))
	hunt.call("_attack")
	hunt.call("_resolve_strike")
	var total_after_hard := 0.0
	for zone: Dictionary in hard_probe.anatomy.zones.values():
		total_after_hard += float(zone.get("health", 0.0))
	var hard_damage: float = total_before_hard - total_after_hard
	print("committed swing took %.2f off a real body" % hard_damage)

	# Settle the arm to rest, then land the identical swing on a second,
	# untouched probe with nothing behind it.
	for _frame in 120:
		await tree.physics_frame
	hunt.call("_spawn_encounter_actor", {"instance_id": "commitment_probe_still", "kind": "hostile"}, probe_at)
	var still_probe: Dictionary = hunt.get("encounter_actors")[-1]
	(still_probe.node as Node3D).position = probe_at
	hunt.set("lock_target", str(still_probe.subject_id))
	hunt.set("attack_cooldown", 0.0)
	arsenal.cooldown = 0.0
	var total_before_still := 0.0
	for zone: Dictionary in still_probe.anatomy.zones.values():
		total_before_still += float(zone.get("health", 0.0))
	hunt.call("_attack")
	hunt.call("_resolve_strike")
	var total_after_still := 0.0
	for zone: Dictionary in still_probe.anatomy.zones.values():
		total_after_still += float(zone.get("health", 0.0))
	var still_damage: float = total_before_still - total_after_still
	print("flick took %.2f off a real body" % still_damage)
	check(hard_damage > 0.0, "the committed swing actually connected with something")
	check(hard_damage > still_damage * 1.5, "a committed sweep measurably outdamages a flick on a real body (%.2f vs %.2f)" % [hard_damage, still_damage])

	_report()


func _report() -> void:
	if failures.is_empty():
		print("arm wiring: connected")
		get_tree().quit(0)
	else:
		print("arm wiring FAILURES: ", failures)
		get_tree().quit(1)
