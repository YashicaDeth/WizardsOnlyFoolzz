extends Node

## A blade takes the limb where it landed, not the zone it landed in.
##
## `_sever_zone()` has always removed the whole zone and put a capsule of bone
## at the joint, so a sword through a mid-forearm took the arm off at the
## shoulder and left the same stub a shotgun would. `BodySlice` makes the cut
## real: the half nearer the torso stays on the body with its cut face showing,
## and only the rest is thrown.
##
## The control case matters as much as the cut. A blow that arrives without a
## point behind it -- an explosion, or any caller using `hit()` rather than
## `hit_at()` -- has nowhere to put a plane, and must still take the zone whole
## exactly as it did before.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func volume_of(mesh: Mesh) -> float:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0.0
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in vertices.size():
			indices.append(i)
	var total := 0.0
	var triangle := 0
	while triangle + 2 < indices.size():
		total += vertices[indices[triangle]].dot(vertices[indices[triangle + 1]].cross(vertices[indices[triangle + 2]]))
		triangle += 3
	return absf(total / 6.0)


func _rig() -> BaselineHuman:
	var body := BaselineHuman.new()
	add_child(body)
	body.build("cut_subject", {})
	return body


## The thrown half is parented to the current scene rather than to the rig, so
## it is found by name from the root.
func _search(node: Node) -> Node:
	if node.name.ends_with("_cut"):
		return node
	for child in node.get_children():
		var found := _search(child)
		if found != null:
			return found
	return null


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	print("-- a blade that lands partway down the arm --")
	var body := _rig()
	body.gore = true
	var arm := body.parts.right_arm as MeshInstance3D
	var whole := volume_of(arm.mesh)
	check(whole > 0.0, "the arm starts as a closed mesh (volume %.5f)" % whole)
	# Partway along the limb's own axis, which is where a sword would cross it
	# rather than where the zone table would prefer it came off.
	var landing := arm.to_global(Vector3(0.0, -0.14, 0.0))

	body.hit_at(landing, 44.0, 28.0, "cut", Vector3.RIGHT)
	var second := body.hit_at(landing, 44.0, 28.0, "cut", Vector3.RIGHT)
	check(bool(second.get("severed", false)), "the cross-cut still severs")
	check(body.cut_zones.has("right_arm"), "the rig recorded it as a cut rather than a zone taken whole")

	var remainder := volume_of((body.parts.right_arm as MeshInstance3D).mesh)
	check(remainder > 0.0, "part of the arm is still on the body (%.5f)" % remainder)
	check(remainder < whole, "but less of it than before (%.5f of %.5f)" % [remainder, whole])
	# The blade landed low on the arm, so most of it is still attached. This is
	# what catches the cut keeping the wrong half: the side the torso is on is
	# the side that stays, and the rig's own origin sits at the feet, below an
	# arm, so using it threw the shoulder and kept the hand.
	check(remainder > whole * 0.5, "and it is the shoulder end that stayed, not the hand (%.0f%% of the arm)" % (remainder / whole * 100.0))
	check((body.parts.right_arm as MeshInstance3D).visible, "the remainder keeps rendering, because there is something left to see")
	check(body.get_node_or_null("right_arm_stump") == null, "no capsule stub, because the cut face is the stump")
	check(_search(get_tree().root) != null, "the piece that came off is in the world as a body")
	body.queue_free()
	await get_tree().process_frame

	print("-- a blow with no point behind it still takes the zone whole --")
	var blast := _rig()
	blast.gore = true
	blast.hit("left_arm", 44.0, 28.0, "cut", "", Vector3.LEFT)
	var blown := blast.hit("left_arm", 44.0, 28.0, "cut", "", Vector3.LEFT)
	check(bool(blown.get("severed", false)), "it severs as it always did")
	check(not blast.cut_zones.has("left_arm"), "it is not recorded as a cut")
	check(not (blast.parts.left_arm as MeshInstance3D).visible, "the limb stops rendering, because none of it is left")
	check(blast.get_node_or_null("left_arm_stump") != null, "and the capsule stub stands in for the joint")
	blast.queue_free()

	print("BODY_CUT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
