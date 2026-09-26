class_name MeshBudget
extends RefCounted

## Greg, 26 September: *"fix performance, 60 fps to 160 fps"*. Measured first:
## the vat chamber drew 608 thousand triangles, the drains 53 thousand, and most
## of the chamber's came from Godot's default primitive meshes. A SphereMesh left
## at its defaults is 64 x 32, four thousand triangles, whether it is a vat the
## size of a room or a knuckle. The specimen curled in every lab vat alone was
## 255 thousand.
##
## Every scene builds its meshes in code, in a hundred places, so this caps the
## segment counts once, as each mesh enters the tree, scaled by the mesh's size:
## a big tank keeps its curve, a fingertip stops paying for one. It only ever
## lowers a count, so a mesh someone tuned low stays as they tuned it.

## Segments around a circle per metre of radius, and the floor and ceiling.
const RADIAL_PER_METRE := 28.0
const RADIAL_MIN := 10
const RADIAL_MAX := 32

static var trimmed := 0
static var _seen := {}


static func radial_for(radius: float) -> int:
	return clampi(int(ceil(RADIAL_MIN + radius * RADIAL_PER_METRE)), RADIAL_MIN, RADIAL_MAX)


## Trims one mesh resource in place. Shared resources are trimmed once.
static func trim(mesh: Mesh) -> void:
	if mesh == null or not (mesh is PrimitiveMesh):
		return
	var id := mesh.get_instance_id()
	if _seen.has(id):
		return
	_seen[id] = true
	if mesh is SphereMesh:
		var sphere := mesh as SphereMesh
		var radial := radial_for(sphere.radius)
		if sphere.radial_segments > radial:
			sphere.radial_segments = radial
			trimmed += 1
		var rings := maxi(6, radial / 2)
		if sphere.rings > rings:
			sphere.rings = rings
	elif mesh is CapsuleMesh:
		var capsule := mesh as CapsuleMesh
		var radial := radial_for(capsule.radius)
		if capsule.radial_segments > radial:
			capsule.radial_segments = radial
			trimmed += 1
		if capsule.rings > 4:
			capsule.rings = 4
	elif mesh is CylinderMesh:
		var cylinder := mesh as CylinderMesh
		var radial := radial_for(maxf(cylinder.top_radius, cylinder.bottom_radius))
		if cylinder.radial_segments > radial:
			cylinder.radial_segments = radial
			trimmed += 1
		# Height rings only add vertices for vertex lighting; nothing here uses it.
		if cylinder.rings > 1:
			cylinder.rings = 1
	elif mesh is TorusMesh:
		var torus := mesh as TorusMesh
		var around := radial_for(torus.outer_radius)
		if torus.rings > around:
			torus.rings = around
			trimmed += 1
		var tube := radial_for((torus.outer_radius - torus.inner_radius) * 0.5)
		if torus.ring_segments > tube:
			torus.ring_segments = tube


## Hooked to SceneTree.node_added. Deferred so a mesh assigned after add_child
## is still caught.
static func on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		_trim_instance.call_deferred(weakref(node))
	elif node is MultiMeshInstance3D:
		_trim_multi.call_deferred(weakref(node))
	elif node is CSGSphere3D or node is CSGCylinder3D:
		_trim_csg.call_deferred(weakref(node))


static func _trim_instance(ref: WeakRef) -> void:
	var node := ref.get_ref() as MeshInstance3D
	if node != null:
		trim(node.mesh)


static func _trim_multi(ref: WeakRef) -> void:
	var node := ref.get_ref() as MultiMeshInstance3D
	if node != null and node.multimesh != null:
		trim(node.multimesh.mesh)


static func _trim_csg(ref: WeakRef) -> void:
	var node = ref.get_ref()
	if node is CSGSphere3D:
		var sphere := node as CSGSphere3D
		sphere.radial_segments = mini(sphere.radial_segments, radial_for(sphere.radius))
		sphere.rings = mini(sphere.rings, maxi(6, sphere.radial_segments / 2))
	elif node is CSGCylinder3D:
		var cylinder := node as CSGCylinder3D
		cylinder.sides = mini(cylinder.sides, radial_for(cylinder.radius))
