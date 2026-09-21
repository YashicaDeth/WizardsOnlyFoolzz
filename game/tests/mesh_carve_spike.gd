extends Node

## Can the engine's own boolean cut a real hole in a body part?
##
## Godot has carried Emmett Lalish's `manifold` since 4.4 -- it is what CSG is
## implemented on -- so a robust mesh boolean is already in the build and needs
## no addon. The open question is whether it will accept what this project
## actually has. `BodyMesh` parts are revolved `ArrayMesh`, and a boolean wants
## a closed manifold surface; `BodySlice.split(..., cap=false)` deliberately
## returns an open one, which is the whole point of `Cavity`.
##
## So this asks three things and prints the answers rather than asserting a
## design: does an intact part carve, does an already-opened part carve, and is
## the result usable geometry. Whatever it says decides whether a ragged hole
## is worth building on top of the flat plane cut `Cavity` takes today.

func triangles_in(mesh: Mesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var arrays := mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		return int((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
	return int(indices.size() / 3)


## Subtract a sphere from `source` and hand back what the engine bakes.
func carve(source: ArrayMesh, at: Vector3, radius: float) -> ArrayMesh:
	var root := CSGMesh3D.new()
	root.mesh = source
	add_child(root)
	var bit := CSGSphere3D.new()
	bit.radius = radius
	bit.radial_segments = 10
	bit.rings = 6
	bit.operation = CSGShape3D.OPERATION_SUBTRACTION
	bit.position = at
	root.add_child(bit)
	# CSG updates are deferred by a frame, so baking immediately returns empty.
	await get_tree().process_frame
	await get_tree().process_frame
	var baked := root.bake_static_mesh()
	root.queue_free()
	return baked


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var intact := BodyMesh.torso(0.72)
	print("intact torso: ", triangles_in(intact), " triangles, aabb ", intact.get_aabb().size)

	var carved: ArrayMesh = await carve(intact, Vector3(0.0, 0.05, 0.10), 0.06)
	print("CARVE intact -> ", "null" if carved == null else str(triangles_in(carved)) + " triangles")
	if carved != null and triangles_in(carved) > 0:
		print("  aabb ", carved.get_aabb().size, " (was ", intact.get_aabb().size, ")")
		print("  VERDICT intact=WORKS")
	else:
		print("  VERDICT intact=REFUSED")

	# The case that actually matters: a chest Cavity has already opened is not
	# a closed surface any more.
	var opened := BodySlice.split(intact, Plane(Vector3.FORWARD, Vector3(0.0, 0.0, -0.05)), 0, false)
	var open_mesh := opened.below as ArrayMesh
	print("opened torso: ", triangles_in(open_mesh), " triangles")
	var carved_open: ArrayMesh = await carve(open_mesh, Vector3(0.0, 0.05, 0.02), 0.05)
	print("CARVE opened -> ", "null" if carved_open == null else str(triangles_in(carved_open)) + " triangles")
	if carved_open != null and triangles_in(carved_open) > 0:
		print("  VERDICT opened=WORKS")
	else:
		print("  VERDICT opened=REFUSED")

	print("MESH_CARVE_SPIKE_RESULT failures=0")
	get_tree().quit(0)
