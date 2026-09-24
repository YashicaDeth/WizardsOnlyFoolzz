extends Node

## Detail that does not cost what detail usually costs.
##
## Two claims are worth holding this to, and neither is "something appeared".
##
## The first is the instancing rule. The districts already carry 2141 visible
## meshes and nothing anywhere uses a `MultiMesh`; dressing seventy metres of
## corridor with a thousand more loose `MeshInstance3D` nodes would be that
## same mistake at a larger size. So the test counts nodes, not appearances.
##
## The second is that this is scenery. `buried_city` has route tests driving
## real movement through it, and a dressing pass that quietly added colliders
## would change what those tests are testing without failing any of them.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func count_kind(root: Node, type_name: String) -> int:
	var found := 0
	for child in root.get_children():
		if child.is_class(type_name):
			found += 1
		found += count_kind(child, type_name)
	return found


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	BloodPool.clear()

	print("-- a dressed corridor --")
	var room := Node3D.new()
	add_child(room)
	var built: Dictionary = LabDressing.dress(room, -46.0, 15.0, 14.4, 11.6, 7314)
	check(not built.is_empty(), "dressing a corridor reports what it built")
	check(int(built.get("instances", 0)) > 600, "and it is genuinely dense (%d instances)" % int(built.get("instances", 0)))
	check(int(built.get("tanks", 0)) > 0, "with specimen tanks (%d)" % int(built.get("tanks", 0)))
	check(int(built.get("slabs", 0)) > 0, "and slabs to work on (%d)" % int(built.get("slabs", 0)))

	print("-- and it is instanced, not scattered --")
	var batches := count_kind(room, "MultiMeshInstance3D")
	var loose := count_kind(room, "MeshInstance3D") - batches
	check(batches >= 8, "the repeated detail is in %d instanced batches" % batches)
	# The whole point: a few hundred instances must not be a few hundred nodes.
	check(int(built.get("instances", 0)) > loose * 3, "far more instances than nodes (%d against %d)" % [int(built.get("instances", 0)), loose])
	check(loose < 120, "and the loose nodes are only what you walk up to and read (%d)" % loose)

	print("-- scenery never becomes architecture --")
	# `buried_city` has route tests driving movement through this district. A
	# dressing pass that added colliders would change what they are testing.
	check(count_kind(room, "StaticBody3D") == 0, "the dressing adds no static bodies")
	check(count_kind(room, "CollisionShape3D") == 0, "and nothing to collide with at all")

	print("-- reserved stretches stay clear --")
	var clear_room := Node3D.new()
	add_child(clear_room)
	# Everything floor-standing is refused when the whole run is spoken for.
	var reserved: Dictionary = LabDressing.dress(clear_room, -46.0, 15.0, 14.4, 11.6, 7314, [Vector2(-60.0, 30.0)])
	check(int(reserved.get("tanks", 0)) == 0, "no tank stands in a reserved stretch")
	check(int(reserved.get("slabs", 0)) == 0, "and no slab either")
	# The wall and ceiling work is not floor-standing and is unaffected, which
	# is what keeps a gallery bay dressed rather than bare.
	check(int(reserved.get("instances", 0)) > 600, "while the walls and ceiling are dressed regardless (%d)" % int(reserved.get("instances", 0)))

	print("-- a corridor nobody passed in --")
	var nothing: Dictionary = LabDressing.dress(null, -10.0, 10.0, 5.0, 6.0, 1)
	check(nothing.is_empty(), "dressing no host builds nothing rather than failing")
	check(LabDressing.scatter(null, BoxMesh.new(), [], "Empty") == null, "and an empty batch is simply not created")

	room.queue_free()
	clear_room.queue_free()
	print("LAB_DRESSING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
