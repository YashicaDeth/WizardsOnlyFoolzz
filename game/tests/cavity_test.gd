extends Node

## A chest that is actually open.
##
## `Extraction` has always modelled the dig -- the zone, the tool, the nine
## seconds bare hands cost, the implant that comes out. The body never changed
## while it happened: the organ was pulled from a torso as sealed at the end as
## it was at the start.
##
## The check that matters here is that the cut is left *open*. A capped cut
## returns a mesh that looks perfectly reasonable and seals the chest with a
## flat lid, so the test compares the two directly rather than trusting that the
## flag was passed.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


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

	print("-- an uncapped cut leaves a hole a capped one seals --")
	var torso := BodyMesh.torso(0.72)
	var plane := Plane(Vector3.FORWARD, Vector3(0.0, 0.0, -0.05))
	var sealed := BodySlice.split(torso, plane, 0, true)
	var opened := BodySlice.split(torso, plane, 0, false)
	check(sealed.below != null and opened.below != null, "both cuts return a body")
	var sealed_faces := triangles_in(sealed.below)
	var opened_faces := triangles_in(opened.below)
	check(opened_faces < sealed_faces, "the open one has no lid on it (%d faces against %d)" % [opened_faces, sealed_faces])
	# The caller sizes the wound by this, so it has to survive not filling it in.
	check(float(opened.area) > 0.0, "and still reports how wide the opening is (%.5f)" % float(opened.area))
	check(absf(float(opened.area) - float(sealed.area)) < 0.00001, "the same width either way")

	print("-- opening a body --")
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("cavity_subject", {})
	var chest := rig.parts.torso as MeshInstance3D
	var before := triangles_in(chest.mesh)
	check(not Cavity.is_open(rig, "torso"), "a body starts closed")

	# From in front, which is where somebody standing over them would go in.
	var cut := Cavity.open_zone(rig, "torso", -chest.global_transform.basis.z)
	check(not cut.is_empty(), "the chest opens")
	check(float(cut.get("area", 0.0)) > 0.0, "with a real opening (%.5f)" % float(cut.get("area", 0.0)))
	check(cut.get("wall") != null, "and a wall that came away")
	check(triangles_in(chest.mesh) != before, "the torso on the body is not the mesh it was")
	check(Cavity.is_open(rig, "torso"), "and the body knows it is open")

	print("-- and what is inside it can be seen --")
	var organs: Array = cut.get("organs", [])
	check(organs.size() >= 4, "the chest organs are revealed (%d: %s)" % [organs.size(), ", ".join(organs)])
	check(organs.has("heart") and organs.has("gut"), "including the ones you would reach for")
	# Read from ORGAN_LAYOUT rather than a list, so opening a chest cannot
	# reveal something that lives in the head.
	check(not organs.has("brain"), "opening a chest does not expose a brain")
	check(not Cavity.is_open(rig, "head"), "and the head is still shut")

	print("-- a cut that finds nothing changes nothing --")
	var arm := rig.parts.right_arm as MeshInstance3D
	var arm_before := triangles_in(arm.mesh)
	var missed := Cavity.open(arm, Vector3.ZERO)
	check(missed.opened == null, "a cut with no direction is refused")
	check(triangles_in(arm.mesh) == arm_before, "and the arm is untouched")
	rig.queue_free()

	print("CAVITY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
