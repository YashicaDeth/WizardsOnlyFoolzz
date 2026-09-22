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
	# The ramps have to start on the floor and end on the deck, or the route
	# has a lip at one end that a player with no jump cannot cross.
	var up_high: float = up.position.y + sin(absf(up.rotation.x)) * 3.65
	check(absf(up_high - city.GANTRY_DECK) < 0.35, "the ramp up arrives at deck height (%.2f against %.2f)" % [up_high, city.GANTRY_DECK])

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
