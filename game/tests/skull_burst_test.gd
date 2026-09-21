extends Node

## A head that is actually opened, and only by the shot that deserves it.
##
## Two failures matter here and they pull in opposite directions. Taking a head
## apart over a graze, or over somebody still standing, is the loud one. The
## quiet one is the rifle round that kills, ruptures the brain, fires the X-ray
## finisher and then leaves an unmarked ovoid head on the corpse -- which is
## what this did before `SkullBurst` existed, because the head is not in
## `BaselineHuman.LIMBS` and nothing else ever cut it.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _snapshot(dead: bool, ruptured: Array) -> Dictionary:
	var organs := {}
	for organ_id in BaselineHuman.ORGAN_LAYOUT:
		organs[organ_id] = {"ruptured": ruptured.has(organ_id)}
	return {"dead": dead, "organs": organs}


func triangles_in(mesh: Mesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var arrays := mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		return int((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
	return int(indices.size() / 3)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	GoreChunks.clear()

	print("-- which shot takes a head apart --")
	check(SkullBurst.earned("head", 78.0, "ballistic", _snapshot(true, ["brain"])), "the rifle's round through the brain does")
	check(not SkullBurst.earned("head", 24.0, "ballistic", _snapshot(true, ["brain"])), "the sidearm's kills without doing it")
	# The line between a hole in a head and a head coming apart.
	check(not SkullBurst.earned("head", 35.9, "ballistic", _snapshot(true, ["brain"])), "just under the threshold is still a hole")
	check(SkullBurst.earned("head", 36.0, "ballistic", _snapshot(true, ["brain"])), "and the threshold itself counts")

	print("-- and which does not --")
	check(not SkullBurst.earned("head", 78.0, "blunt", _snapshot(true, ["brain"])), "a club caves a head in rather than taking a piece off")
	check(not SkullBurst.earned("head", 78.0, "ballistic", _snapshot(false, ["brain"])), "nobody standing loses the top of their head")
	check(not SkullBurst.earned("head", 78.0, "ballistic", _snapshot(true, ["heart"])), "a rifle through the chest is not a head shot")
	check(not SkullBurst.earned("head", 78.0, "ballistic", _snapshot(true, [])), "nor is a dead body with an intact brain")
	check(not SkullBurst.earned("head", 78.0, "ballistic", {}), "an empty snapshot is simply not one")
	# A ruptured brain is a lasting fact about a body, so the zone has to be
	# part of the rule or a later chest shot inherits it.
	check(not SkullBurst.earned("torso", 78.0, "ballistic", _snapshot(true, ["brain"])), "and a chest shot on a corpse with a ruptured brain does not take its head off")

	print("-- the head actually comes apart --")
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("skull_subject", {})
	await get_tree().process_frame
	var head := rig.parts.head as MeshInstance3D
	var before := triangles_in(head.mesh)
	check(not Cavity.is_open(rig, "head"), "a head starts shut")
	# The round is travelling away from the shooter, so the exit side is the
	# piece that leaves.
	var travel := -head.global_transform.basis.z
	var burst := SkullBurst.open(rig, travel)
	check(not burst.is_empty(), "the rifle round opens it")
	check(float(burst.get("area", 0.0)) > 0.0, "with a real opening (%.5f)" % float(burst.get("area", 0.0)))
	check(triangles_in(head.mesh) != before, "the head on the body is not the mesh it was")
	check(Cavity.is_open(rig, "head"), "and the body knows the head is open")
	var organs: Array = burst.get("organs", [])
	check(organs.has("brain"), "the brain is showing (%s)" % ", ".join(organs))
	check(not Cavity.is_open(rig, "torso"), "and the chest is untouched")

	print("-- the cranium is a piece of somebody, not a disappearing wall --")
	var cranium := burst.get("cranium") as RigidBody3D
	check(cranium != null and is_instance_valid(cranium), "the piece that came off exists")
	if cranium != null and is_instance_valid(cranium):
		check(cranium.is_inside_tree(), "and is in the world rather than leaked")
		var info: Dictionary = GoreChunks.identify(cranium)
		check(not info.is_empty(), "it is an identified chunk")
		check(str(info.get("zone", "")) == "head", "off the head")
		check(str(info.get("subject_id", "")) == "skull_subject", "off this person (%s)" % str(info.get("subject_id", "")))
		check(int(info.get("layer", -1)) == GoreChunks.Layer.BONE, "and reads as bone")
		check(bool(info.get("whole_wall", false)), "and as a wall rather than a gib or a limb")

	print("-- a corpse is not whittled down by the next round --")
	var opened := triangles_in(head.mesh)
	var again := SkullBurst.open(rig, travel)
	check(again.is_empty(), "a second round into the same head is refused")
	check(triangles_in(head.mesh) == opened, "so the head stops losing pieces")
	rig.queue_free()

	print("SKULL_BURST_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
