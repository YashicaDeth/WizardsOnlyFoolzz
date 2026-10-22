extends Node

## AN6.7. The X-ray shows what has already been done to a body: each round's
## path through the limb, the newest one green, earlier ones white, a stub where
## the round stopped inside and a brighter end where it reached bone.
##
## Also guards the wiring, for the reason `wof-wire-before-polish` exists: a
## display nobody calls is the most common bug in this project, and this one is
## only ever visible while the sweep is holding a body.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- a wound table, read as trajectories --------------------------------
	var shallow := _wound(Vector3(0, 0.2, 0), Vector3(0, 0, -1), 0.25, 0.12, false, "ballistic", 11)
	var deep := _wound(Vector3(0.04, 0.2, 0), Vector3(0, 0, -1), 0.95, 0.12, true, "ballistic", 12)
	var cut := _wound(Vector3(0, 0.1, 0), Vector3(-1, 0, 0), 1.0, 0.12, false, "cut", 13)
	var exit := _wound(Vector3(0.04, 0.2, -0.12), Vector3(0, 0, 1), 1.0, 0.0, true, "ballistic", 14)
	exit["exit"] = true

	var trails: Array = RoundTrails.trails_from([shallow, deep, cut, exit])
	check(trails.size() == 2, "only rounds that went in are drawn (%d of 4)" % trails.size())
	check(not _any_type(trails, "cut"), "a blade leaves no path")

	# --- depth is the length ------------------------------------------------
	var stub := RoundTrails.trails_from([shallow])[0] as Dictionary
	check(is_equal_approx(float(stub["length"]), 0.25 * 0.12), "a shallow round is a stub (%.3f m)" % float(stub["length"]))
	check(not bool(stub["bone"]), "and it never reached bone")
	check(not bool(stub["through"]) and float(stub["depth"]) < RoundTrails.BONE_AT, "a round that stopped inside is still inside")

	var crossed := RoundTrails.trails_from([deep])[0] as Dictionary
	check(is_equal_approx(float(crossed["length"]), 0.95 * 0.12), "a round that crossed is the length of what it crossed")
	check(bool(crossed["bone"]), "and it reached whatever was in the middle")

	# --- recency is the colour, depth is the weight -------------------------
	var newest: Color = RoundTrails.tone_for(1, 2, 0.95)
	var older: Color = RoundTrails.tone_for(0, 2, 0.95)
	check(is_equal_approx(newest.g, RoundTrails.NEWEST.g) and is_equal_approx(newest.r, RoundTrails.NEWEST.r), "the last round in is green")
	check(is_equal_approx(older.r, RoundTrails.OLDER.r), "every round before it is white")
	var faint: Color = RoundTrails.tone_for(1, 2, 0.2)
	check(faint.a < newest.a, "a shallow round reads fainter than a deep one (%.2f < %.2f)" % [faint.a, newest.a])

	# --- the cap ------------------------------------------------------------
	var many: Array = []
	for index in 20:
		many.append(_wound(Vector3(0, 0.1, 0), Vector3(0, 0, -1), 0.8, 0.1, false, "ballistic", index))
	var capped: Array = RoundTrails.trails_from(many)
	check(capped.size() == RoundTrails.MAX_TRAILS, "a body emptied into keeps %d trails, not twenty" % RoundTrails.MAX_TRAILS)
	check(is_equal_approx(float((capped[capped.size() - 1] as Dictionary)["at"].y), 0.1), "and the newest one is kept")

	# --- geometry -----------------------------------------------------------
	var piece := RoundTrails.build(crossed, 1, 2)
	check(piece.mesh != null, "a trail builds a mesh")
	var arrays: Array = piece.mesh.surface_get_arrays(0)
	check((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() >= RoundTrails.SHAFT_SIDES * 6, "the shaft has sides")
	var material := piece.material_override as StandardMaterial3D
	check(material != null and material.no_depth_test, "and it draws through the body it is inside")
	check(material != null and material.render_priority > 4, "after the organs it is drawn through")
	var bare := RoundTrails.build(stub, 0, 1)
	var bare_arrays: Array = bare.mesh.surface_get_arrays(0)
	check((bare_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() < (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
		"a round that never reached bone has no bone edge")
	piece.free()
	bare.free()

	# --- it goes on and off with the sweep ----------------------------------
	var part := Node3D.new()
	add_child(part)
	RoundTrails.refresh(part, [shallow, deep])
	var holder := part.get_node_or_null(RoundTrails.HOLDER) as Node3D
	check(holder != null, "a limb with rounds in it carries their trails")
	check(holder != null and holder.get_child_count() == 2, "one mesh per round")
	var first: Node = holder.get_child(0) if holder != null else null
	RoundTrails.refresh(part, [shallow, deep])
	var second := part.get_node_or_null(RoundTrails.HOLDER) as Node3D
	check(second != null and second.get_child(0) == first, "an unchanged body is not rebuilt every frame")

	RoundTrails.refresh(part, [])
	check(part.get_node_or_null(RoundTrails.HOLDER) == null, "letting go of the X-ray takes the drawing with it")
	part.queue_free()

	# --- and it is actually wired into the body -----------------------------
	var source := FileAccess.get_file_as_string("res://systems/baseline_human.gd")
	var reveal_at := source.find("func reveal_organs(")
	var next_at := source.find("func see_through(")
	var wired := reveal_at >= 0 and next_at > reveal_at and source.substr(reveal_at, next_at - reveal_at).contains("RoundTrails.refresh(")
	check(wired, "reveal_organs() is what puts the trails on a body")
	check(source.contains("wound[\"thickness\"]"), "_record_wound() keeps the depth the trail is measured from")

	print("ROUND_TRAILS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _wound(at: Vector3, normal: Vector3, depth: float, thickness: float, through: bool, type: String, seed: int) -> Dictionary:
	return {
		"at": at, "normal": normal, "depth": depth, "thickness": thickness,
		"through": through, "type": type, "seed": seed, "radius": 0.03,
	}


func _any_type(trails: Array, type: String) -> bool:
	for trail in trails:
		if str((trail as Dictionary).get("type", "")) == type:
			return true
	return false
