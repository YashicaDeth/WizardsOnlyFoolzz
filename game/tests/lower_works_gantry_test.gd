extends Node

## The third way past the sentinel.
##
## There were two, and both cost something you carried in: spend the fuse on
## the shortcut, or spend the arcade breach tool on the sentinel. A player who
## arrived with neither had no route at all except walking into it.
##
## The gantry costs time and nerve instead, and it is built out of geometry the
## district already had -- the west galleries were dressed, railed and doing
## nothing, twelve metres of walkway at head height that could be looked at and
## never stood on. The constraint was another way through, not another map.
##
## Two things are worth pinning and neither is "the slabs exist". The ramps
## have to be walkable by a player with no jump, and the sentinel has to stop
## being able to hit somebody standing over its head -- which it could, because
## `_patrol_step` flattened the height out before measuring anything.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	await get_tree().process_frame
	var city: Node = (load("res://buried_city.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(city)
	if not city.has_method("_build_gantry"):
		print("FAIL buried_city.gd did not load -- it has no script attached")
		print("LOWER_WORKS_GANTRY_TEST_RESULT failures=1")
		get_tree().quit(1)
		return
	for frame in 10:
		await get_tree().physics_frame

	print("-- the galleries became a route --")
	var up := city.get_node_or_null("GantryRampUp") as StaticBody3D
	var span := city.get_node_or_null("GantryCatwalk") as StaticBody3D
	var down := city.get_node_or_null("GantryRampDown") as StaticBody3D
	check(up != null and span != null and down != null, "there is a ramp up, a catwalk and a ramp down")
	if up == null or span == null or down == null:
		print("LOWER_WORKS_GANTRY_TEST_RESULT failures=", failures.size() + 1)
		get_tree().quit(1)
		return

	print("-- and a player with no jump can walk it --")
	# `move_and_slide` walks anything under `floor_max_angle`, which defaults to
	# forty-five degrees. Steps would have been a wall with a pattern on it,
	# because the Lower Works controller has no jump and CharacterBody3D does
	# not climb stairs by itself.
	var limit := deg_to_rad(45.0)
	check(absf(up.rotation.x) < limit, "the ramp up is shallow enough to walk (%.1f degrees)" % rad_to_deg(absf(up.rotation.x)))
	check(absf(down.rotation.x) < limit, "and so is the ramp down (%.1f degrees)" % rad_to_deg(absf(down.rotation.x)))
	# Opposite signs, or both ends rise and the far one is a wall.
	check(signf(up.rotation.x) != signf(down.rotation.x), "and they slope opposite ways, so one goes up and one comes down")
	check(is_equal_approx(span.rotation.x, 0.0), "the catwalk between them is flat")

	print("-- it meets the deck it is supposed to meet --")
	# The galleries are authored at y=1.9 with a 0.35 slab, so their walking
	# surface is 2.075. A catwalk at any other height is a step, and a step is
	# a wall here.
	check(is_equal_approx(span.position.y + 0.15, city.GANTRY_DECK), "the catwalk surface is the gallery deck (%.3f)" % (span.position.y + 0.15))
	check(is_equal_approx(up.position.x, city.GANTRY_RUN) and is_equal_approx(span.position.x, city.GANTRY_RUN), "and all of it runs down the west galleries")
	# Both ends of both ramps, measured off the actual collision box rather
	# than from a remembered length.
	#
	# The first version of this check hard-coded half the ramp length and
	# allowed 35cm of slop, so when the ramp was rebuilt longer the formula
	# went stale and the check passed anyway -- it reported 1.83 against 2.08
	# and called it arrival. That tolerance is exactly why a ramp with a step
	# at the bottom and a gap at the top shipped as "12 checks, failures=0".
	# A lip of 15cm stops a player with no jump, so the tolerance is 5cm.
	for ramp: StaticBody3D in [up, down]:
		var box := (ramp.get_child(1) as CollisionShape3D).shape as BoxShape3D
		var pitch := absf(ramp.rotation.x)
		var half_along: float = box.size.z * 0.5 * sin(pitch)
		# The top face sits this far above the centre line, measured up the
		# vertical rather than along the slab, which is the term the broken
		# version left out entirely.
		var face: float = (box.size.y * 0.5) / cos(pitch)
		var high: float = ramp.position.y + half_along + face
		var low: float = ramp.position.y - half_along + face
		check(absf(high - city.GANTRY_DECK) < 0.05, "%s reaches the deck (%.3f against %.3f)" % [ramp.name, high, city.GANTRY_DECK])
		check(absf(low - city.GANTRY_FLOOR) < 0.05, "%s meets the floor without a step (%.3f)" % [ramp.name, low])

	print("-- and you can run and jump now --")
	check(city.SPRINT_SCALE > 1.0, "sprinting is faster than walking (x%.2f)" % city.SPRINT_SCALE)
	check(city.JUMP_SPEED > 0.0, "and there is a jump at all")
	# The apex, against the gravity this scene actually applies. A jump that
	# reached the deck would make the ramps decorative the day they were built,
	# and the whole route is that the height has to be earned by walking to it.
	var apex: float = (city.JUMP_SPEED * city.JUMP_SPEED) / (2.0 * 18.0)
	check(apex < city.GANTRY_DECK, "but it cannot reach the gantry deck (%.2f against %.2f)" % [apex, city.GANTRY_DECK])
	# It does have to clear the kerbs and pipe runs, or it is a jump that does
	# nothing and may as well not be bound.
	check(apex > 0.45, "while still clearing the kerbs (%.2f)" % apex)

	print("-- and the route is lit --")
	# Every lamp in the district hangs on the centre line with a ten metre
	# range, so the west galleries were the darkest ground in the Lower Works
	# and the ramps were unlit objects standing in it.
	var lamps := 0
	for child in city.get_children():
		if child is OmniLight3D and str(child.name).begins_with("GantryLamp"):
			lamps += 1
			check(absf((child as OmniLight3D).position.x - city.GANTRY_RUN) < 3.0, "a gantry lamp is over the route rather than the centre line")
	check(lamps >= 3, "the route is lit along its length (%d lamps)" % lamps)

	print("-- and the sentinel cannot reach up there --")
	var patrol := city.get("patrol") as Node3D
	var player := city.get("player") as CharacterBody3D
	check(patrol != null and player != null, "the sentinel is on its feet")
	city.set("patrol_disabled", false)
	city.set("patrol_attack_cooldown", 0.0)
	# Standing on the floor, right on top of it: this is the existing threat
	# and it has to keep working, or the gantry has quietly disarmed the
	# district instead of routing around it.
	patrol.global_position = Vector3(0.0, 0.0, 0.0)
	player.global_position = Vector3(0.5, 0.0, 0.0)
	city.set("blood", 100.0)
	city.call("_patrol_step", 0.1)
	check(float(city.get("blood")) < 100.0, "it still hits somebody standing in front of it")

	# The same place, two metres up. `_patrol_step` flattened the height out
	# before measuring, so to it these two positions were identical.
	city.set("patrol_attack_cooldown", 0.0)
	city.set("blood", 100.0)
	player.global_position = Vector3(0.5, city.GANTRY_DECK, 0.0)
	city.call("_patrol_step", 0.1)
	check(is_equal_approx(float(city.get("blood")), 100.0), "and cannot touch somebody on the gantry above it")

	# It still follows, which is what makes coming down the far ramp a
	# decision rather than a formality.
	var chased_from: Vector3 = patrol.global_position
	city.set("patrol_attack_cooldown", 0.0)
	player.global_position = Vector3(6.0, city.GANTRY_DECK, 0.0)
	for step in 6:
		city.call("_patrol_step", 0.1)
	check(patrol.global_position.distance_to(chased_from) > 0.05, "but it follows underneath you and is waiting at the bottom")

	city.queue_free()
	print("LOWER_WORKS_GANTRY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
