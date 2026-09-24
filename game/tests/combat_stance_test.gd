extends Node

## A fight you can read, checked as numbers.
##
## The reason these poses are a system rather than lines inside
## `HunterBodyMotion` is that the ways they fail are all readable off numbers
## and none of them are readable by watching: a guard that leaves the chest
## open, a parry that never crosses the centre line far enough to be told apart
## from the guard it started from, a stagger that does not say which side the
## blow came from, and a lock-on strafe that yaws away from the thing it is
## locked to.
##
## That last one is the one worth having a test for at all. Lock-on means you
## keep facing the target; a strafe that turns the torso with the movement
## takes away the exact read the player locked on to get, and it would look
## perfectly fine in isolation.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func angles_of(pose: Dictionary, zone_id: String) -> Vector3:
	var zone: Dictionary = pose.get(zone_id, {})
	return zone.get("angles", Vector3.ZERO)


func offset_of(pose: Dictionary, zone_id: String) -> Vector3:
	var zone: Dictionary = pose.get(zone_id, {})
	return zone.get("offset", Vector3.ZERO)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("-- a guard that actually covers you --")
	check(CombatStance.guard(0.0).is_empty(), "a dropped guard poses nothing at all")
	var held := CombatStance.guard(1.0)
	check(not held.is_empty(), "a raised one does")
	# Inward is negative roll on the left arm and positive on the right, which
	# is the convention the existing poses already use.
	check(angles_of(held, "right_arm").z > 0.0, "the weapon arm comes in across the chest")
	check(angles_of(held, "left_arm").z < 0.0, "and the off hand comes in to meet it")
	check(angles_of(held, "right_arm").x > 0.0 and angles_of(held, "left_arm").x > 0.0, "both arms are up, so it is a guard rather than a shrug")
	check(angles_of(held, "torso").y < 0.0, "and the body is bladed on, so there is less of you behind it")
	# Half a guard is half as far, so raising one can be driven by a blend.
	var half := CombatStance.guard(0.5)
	check(angles_of(half, "right_arm").z < angles_of(held, "right_arm").z, "a half-raised guard is genuinely half-raised")
	var shouldered := CombatStance.guard(1.0, "firearm")
	check(angles_of(shouldered, "right_arm").x > angles_of(held, "right_arm").x, "a firearm comes to the shoulder higher than a blade is held")

	print("-- a parry you can tell apart from a guard --")
	check(CombatStance.parry(0.0).is_empty(), "a parry that has not started poses nothing")
	check(CombatStance.parry(1.0).is_empty(), "and one that has finished leaves the body where it found it")
	var peak := CombatStance.parry(CombatStance.PARRY_PEAK)
	check(not peak.is_empty(), "the deflection itself is a pose")
	# The whole point: if it does not cross further than the guard it came out
	# of, the player has nothing to read in the frames they have to read it in.
	check(angles_of(peak, "right_arm").z > angles_of(held, "right_arm").z * 1.5, "it crosses the centre line well past the guard (%.2f against %.2f)" % [angles_of(peak, "right_arm").z, angles_of(held, "right_arm").z])
	# Out and back, not a ramp.
	var early := CombatStance.parry(CombatStance.PARRY_PEAK * 0.5)
	var late := CombatStance.parry(0.85)
	check(angles_of(early, "right_arm").z < angles_of(peak, "right_arm").z, "it is still going out before the peak")
	check(angles_of(late, "right_arm").z < angles_of(peak, "right_arm").z, "and coming back after it")

	print("-- a stagger that says where it came from --")
	# A blow arriving from the body's left, in the body's own space.
	var from_left := CombatStance.stagger(0.0, Vector3.LEFT, 1.0)
	var from_right := CombatStance.stagger(0.0, Vector3.RIGHT, 1.0)
	check(not from_left.is_empty(), "being hit folds the body")
	check(offset_of(from_left, "torso").x > 0.0, "a blow from the left carries the torso to the right")
	check(offset_of(from_right, "torso").x < 0.0, "and one from the right carries it to the left")
	check(signf(angles_of(from_left, "torso").z) != signf(angles_of(from_right, "torso").z), "the two roll opposite ways, so the side is readable")
	# Symmetry, so neither side is the cheap one to be hit from.
	check(absf(offset_of(from_left, "torso").x + offset_of(from_right, "torso").x) < 0.0001, "and mirror each other exactly")
	check(CombatStance.stagger(1.0, Vector3.LEFT, 1.0).is_empty(), "a recovered stagger is gone rather than snapped back")
	var light := CombatStance.stagger(0.0, Vector3.LEFT, 0.4)
	check(absf(offset_of(light, "torso").x) < absf(offset_of(from_left, "torso").x), "a lighter blow folds it less")

	print("-- a strafe that keeps facing what it is locked to --")
	check(CombatStance.strafe(0.0, 0.0).is_empty(), "standing still is not a strafe")
	var stepping_left := CombatStance.strafe(-1.0)
	var stepping_right := CombatStance.strafe(1.0)
	check(not stepping_left.is_empty(), "stepping sideways poses the legs")
	# The one that matters. Lock-on is a promise that you keep facing the thing.
	check(absf(angles_of(stepping_left, "torso").y) < 0.0001, "stepping left does not yaw the torso off the target")
	check(absf(angles_of(stepping_right, "torso").y) < 0.0001, "and neither does stepping right")
	check(signf(angles_of(stepping_left, "left_leg").x) != signf(angles_of(stepping_left, "right_leg").x), "the legs cross over rather than walking")
	var closing := CombatStance.strafe(0.0, 1.0)
	check(not closing.is_empty(), "closing the distance is a pose of its own")
	check(absf(angles_of(closing, "torso").y) < 0.0001, "and still does not turn away")

	print("-- a lean that is the same both ways --")
	check(CombatStance.lean(0.0).is_empty(), "standing straight is not a lean")
	var out_left := CombatStance.lean(-1.0)
	var out_right := CombatStance.lean(1.0)
	# A lean that is stronger one way is an advantage a player will find.
	check(absf(offset_of(out_left, "torso").x + offset_of(out_right, "torso").x) < 0.0001, "left and right lean exactly as far as each other")
	check(absf(angles_of(out_left, "torso").z + angles_of(out_right, "torso").z) < 0.0001, "and roll exactly as far")
	check(offset_of(out_right, "torso").x > 0.0, "leaning right actually goes right")

	print("-- prone is the rig, not six parts pretending --")
	check(CombatStance.prone(0.0).is_empty(), "standing up is not prone")
	var flat := CombatStance.prone(1.0)
	check(offset_of(flat, "torso").y < 0.0, "going prone drops the body")
	check(angles_of(flat, "head").x < 0.0, "with the head still up, because the eyeline is the reason to be there")
	check(CombatStance.prone_root_pitch(1.0) < -1.0, "and the rig itself pitches onto the floor (%.2f rad)" % CombatStance.prone_root_pitch(1.0))
	check(is_equal_approx(CombatStance.prone_root_pitch(0.0), 0.0), "while standing leaves the rig upright")
	# Nearly flat rather than flat, so a body does not clip a sloped floor.
	check(CombatStance.prone_root_pitch(1.0) > -PI * 0.5, "but not perfectly flat, which would clip any slope")

	print("-- poses layer instead of erasing each other --")
	var guarding := CombatStance.guard(1.0)
	var leaning := CombatStance.lean(1.0)
	var both := CombatStance.blend(guarding, leaning, 1.0)
	check(both.has("right_arm") and both.has("torso"), "a blend keeps the zones from both poses")
	# `guard` never touches the legs, so a leg pose underneath has to survive.
	var footwork := CombatStance.blend(CombatStance.strafe(1.0), guarding, 1.0)
	check(absf(angles_of(footwork, "left_leg").x) > 0.0, "guarding while strafing keeps the footwork")
	check(angles_of(footwork, "right_arm").z > 0.0, "and still puts the guard up")
	var none := CombatStance.blend(guarding, leaning, 0.0)
	check(is_equal_approx(angles_of(none, "torso").z, angles_of(guarding, "torso").z), "a blend at zero weight changes nothing")
	var untouched := CombatStance.blend(guarding, {}, 1.0)
	check(is_equal_approx(angles_of(untouched, "right_arm").z, angles_of(guarding, "right_arm").z), "and laying nothing over a pose leaves it alone")

	print("-- and it reaches an actual body --")
	# A solver nobody calls is the failure this repo has already had twice, so
	# the last thing checked is that `HunterBodyMotion` applies it.
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("stance_subject", {})
	var motion := HunterBodyMotion.new()
	add_child(motion)
	motion.configure(rig)
	motion.set_perspective(false)
	var arm := rig.parts.get("right_arm") as Node3D
	motion.update(0.016, Vector3.ZERO, true, false, false, false)
	var resting := arm.rotation.z
	motion.set_guard(1.0)
	motion.update(0.016, Vector3.ZERO, true, false, false, false)
	check(absf(arm.rotation.z - resting) > 0.1, "raising a guard actually moves the arm on the body")

	# The reason the layer is added rather than written over: a body that stops
	# walking the moment it raises a guard is what makes procedural look
	# procedural.
	var walking := Vector3(0.0, 0.0, 5.0)
	var leg := rig.parts.get("left_leg") as Node3D
	motion.update(0.1, walking, true, false, false, false)
	var stride_one := leg.rotation.x
	for _step in 6:
		motion.update(0.1, walking, true, false, false, false)
	check(absf(leg.rotation.x - stride_one) > 0.01, "and the legs keep walking underneath it")

	motion.set_guard(0.0)
	motion.set_prone(1.0)
	motion.update(0.016, Vector3.ZERO, true, false, false, false)
	check(rig.rotation.x < -1.0, "going prone pitches the rig itself onto the floor (%.2f rad)" % rig.rotation.x)

	motion.set_prone(0.0)
	motion.trigger_stagger(Vector3.LEFT, 1.0)
	motion.update(0.016, Vector3.ZERO, true, false, false, false)
	var torso := rig.parts.get("torso") as Node3D
	check(absf(torso.rotation.z) > 0.01, "and a stagger folds the torso on a live body")
	rig.queue_free()
	motion.queue_free()

	print("COMBAT_STANCE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
