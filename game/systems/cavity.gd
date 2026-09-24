class_name Cavity
extends RefCounted

## Opening a body, rather than running a timer over a closed one.
##
## `Extraction` already models the dig properly -- which zones are worth
## opening, what tool you have, that bare hands take about nine seconds and ruin
## what they pull, which implant is in there. What it never had was a body that
## changed while you did it. The torso stayed exactly as intact at the end of a
## nine-second dig as it was at the start, and the organ came out of a sealed
## chest.
##
## So this is the geometry half. A cut is taken parallel to the surface the
## hands went in at, the wall in front of it comes away, and what is left is an
## open shell with the organs already inside it visible through the hole.
##
## The two things that make it work are both recent:
##
##   - `BodySlice` can cut an arbitrary plane through a limb at all, because
##     `BodyMesh` has no skeleton and no skin weights to rebuild.
##   - `BodySlice.split()` can now be asked *not* to cap the cut. Capping is
##     right for a severed arm and exactly wrong here: it would seal the chest
##     you just opened with a flat lid and leave the organs behind it.

## How far under the skin the cut is taken. Deep enough that the wall which
## comes away is a wall rather than a film, shallow enough that it does not take
## the organs with it.
const WALL_DEPTH := 0.055

## Below this the hole is not worth calling one -- a nick in the surface rather
## than a body that has been opened.
const MIN_OPENING_AREA := 0.0015

## Openness is recorded on the part, not inferred from a visible organ.
##
## Inference only ever answered correctly for the two zones that have organs in
## them. `implant_catalog.gd` puts hardware in arms and legs, `ORGAN_LAYOUT`
## puts nothing there, so a limb reported shut however far it had been opened --
## and `_finish_extraction` cut a fresh wall off it for every implant robbed out
## of it. Two implants out of one arm and the arm was visibly shorter.
##
## Metadata rather than a marker child, because sibling nodes that share a name
## are not the same node and a name lookup finds only the first.
const OPEN_MARK := &"cavity_open"


## Cut the wall off a part, leaving it open.
##
## `facing` is the direction the hands came from, in world space: the wall that
## comes away is the one between them and the inside. Returns empty when the cut
## found nothing worth opening, and the caller should leave the body alone
## rather than swapping in a mesh that is the same shape with more triangles.
static func open(part: MeshInstance3D, facing: Vector3, depth := WALL_DEPTH) -> Dictionary:
	var nothing := {"opened": null, "wall": null, "area": 0.0, "centre": Vector3.ZERO}
	if part == null or not is_instance_valid(part) or part.mesh == null:
		return nothing
	var outward := facing.normalized()
	if outward.length_squared() < 0.5:
		return nothing
	# The plane is parallel to the surface being cut into, which means its normal
	# is the direction the hands came from, carried into the part's own space.
	var local_normal := (part.global_transform.basis.inverse() * outward).normalized()
	if local_normal.length_squared() < 0.5:
		return nothing
	var bounds := part.mesh.get_aabb()
	var centre := bounds.get_center()
	# How far the body reaches along the cut direction, so the plane sits under
	# the near surface rather than at some fixed distance from the middle -- a
	# chest and a forearm are opened by the same call.
	var reach := _support(part.mesh, centre, local_normal)
	if reach <= depth:
		return nothing
	var plane := Plane(local_normal, centre + local_normal * (reach - depth))
	# Not capped. This is the whole point: a capped cut would close the chest
	# again with a flat lid the moment it was opened.
	var halves := BodySlice.split(part.mesh, plane, 0, false)
	if halves.above == null or halves.below == null:
		return nothing
	if float(halves.area) < MIN_OPENING_AREA:
		return nothing
	return {
		"opened": halves.below,
		"wall": halves.above,
		"area": float(halves.area),
		"centre": halves.centre,
	}


## How far the part actually reaches along the cut direction.
##
## This was taken from the bounding box -- `size.dot(normal.abs()) * 0.5` --
## which is the support of the *box*, and exact only when the direction is
## axis-aligned. A body standing at any other angle makes it an overestimate,
## because the mesh is inscribed in its box rather than filling it. A head at
## sixty-four degrees measured 0.143 where the skull actually ends at 0.106, so
## the plane was placed five millimetres outside the mesh, `BodySlice` found
## nothing on one side of it, and `open()` returned "no opening worth making".
##
## It failed silently and it failed for nearly everybody: bodies stand at
## whatever angle they died at, and only one square to the cut measured right.
## Reading the vertices is exact for any mesh and any direction, and it happens
## once per dig rather than per frame.
static func _support(mesh: Mesh, centre: Vector3, direction: Vector3) -> float:
	var reach := 0.0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			reach = maxf(reach, (vertex - centre).dot(direction))
	return reach


## The same cut, applied to a rig's zone, with whatever is inside that zone
## revealed because there is now a hole to see it through.
##
## Organs are built `visible = false` and stay that way until something opens
## the body -- which until now nothing actually did, so the organ meshes were
## only ever seen through the layer-exposure path. This is the other way in.
static func open_zone(rig: Node, zone_id: String, facing: Vector3, depth := WALL_DEPTH) -> Dictionary:
	if rig == null or not is_instance_valid(rig):
		return {}
	var parts: Dictionary = rig.get("parts") if "parts" in rig else {}
	var part := parts.get(zone_id) as MeshInstance3D
	if part == null or not is_instance_valid(part):
		return {}
	# A body is opened once. A second cut is taken from the middle of what the
	# first one left, so it does not re-open the same hole -- it takes another
	# slab off and hands back a smaller body than it was given.
	if is_open(rig, zone_id):
		return {}
	var cut := open(part, facing, depth)
	if cut.is_empty() or cut.opened == null:
		return {}
	part.mesh = cut.opened
	part.set_meta(OPEN_MARK, true)
	var revealed := _reveal_organs(rig, zone_id)
	cut["organs"] = revealed
	cut["zone"] = zone_id
	return cut


## Give the wall that came away a body of its own.
##
## `open()` has always returned the removed slab under `wall`, and every caller
## has always thrown it away -- the front of a chest was cut off and then
## silently ceased to exist, which is the one part of opening somebody that a
## player would expect to be able to pick up. It is a real `RigidBody3D` with a
## real identity, so it falls, rots, and sells like any other piece.
##
## `heading` is where it is pushed: the direction the round was travelling, or
## the way the hands went in. Returns null when there was nothing to shed,
## which includes the perfectly ordinary case of a cut that found nothing.
static func shed_wall(rig: Node3D, cut: Dictionary, heading := Vector3.ZERO, layer := GoreChunks.Layer.BONE) -> RigidBody3D:
	if rig == null or not is_instance_valid(rig) or not rig.is_inside_tree():
		return null
	var wall := cut.get("wall") as ArrayMesh
	if wall == null:
		return null
	var zone := str(cut.get("zone", ""))
	var parts: Dictionary = rig.get("parts") if "parts" in rig else {}
	var part := parts.get(zone) as MeshInstance3D
	if part == null or not is_instance_valid(part):
		return null
	var shape := wall.create_convex_shape()
	if shape == null:
		return null
	var body := RigidBody3D.new()
	body.name = "ShedWall"
	var view := MeshInstance3D.new()
	view.mesh = wall
	# The outside of a cranium is still a head: the slab keeps the surface it
	# had on the body rather than turning into untextured geometry in mid-air.
	view.material_override = part.material_override
	body.add_child(view)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var scene := rig.get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		body.queue_free()
		return null
	scene.add_child(body)
	# The wall's vertices are in the part's own space, so standing it in the
	# part's transform puts it exactly where it was before it came off.
	body.global_transform = part.global_transform
	var subject_id := str(rig.get("subject_id")) if "subject_id" in rig else ""
	GoreChunks.register_wall(body, zone, subject_id, layer)
	var push := heading.normalized() if heading.length_squared() > 0.001 else Vector3.UP
	body.apply_impulse((push * 2.2 + Vector3.UP * 1.1) * body.mass)
	body.angular_velocity = Vector3(randf_range(-7, 7), randf_range(-7, 7), randf_range(-7, 7))
	return body


## Which organs live in this zone, made visible. Read from `ORGAN_LAYOUT` rather
## than from a list here, so an organ moved between zones cannot end up revealed
## by opening the wrong part of somebody.
static func _reveal_organs(rig: Node, zone_id: String) -> Array:
	var shown: Array = []
	var organ_parts: Dictionary = rig.get("organ_parts") if "organ_parts" in rig else {}
	for organ_id in BaselineHuman.ORGAN_LAYOUT:
		var spec: Dictionary = BaselineHuman.ORGAN_LAYOUT[organ_id]
		if str(spec.get("zone", "")) != zone_id:
			continue
		var organ := organ_parts.get(organ_id) as Node3D
		if organ == null or not is_instance_valid(organ):
			continue
		organ.visible = true
		shown.append(str(organ_id))
	return shown


## Whether a zone has already been opened. Asked before starting a dig so a
## second one into the same chest does not cut a wall that is not there any
## more and quietly return a worse mesh than the one it replaced.
static func is_open(rig: Node, zone_id: String) -> bool:
	if rig == null or not is_instance_valid(rig):
		return false
	var parts: Dictionary = rig.get("parts") if "parts" in rig else {}
	var part := parts.get(zone_id) as Node3D
	if part != null and is_instance_valid(part) and bool(part.get_meta(OPEN_MARK, false)):
		return true
	# A visible organ still counts, because the layer-exposure path opens a
	# chest without ever coming through here. It is the fallback rather than the
	# answer: only two zones own an organ, so it cannot speak for a limb.
	var organ_parts: Dictionary = rig.get("organ_parts") if "organ_parts" in rig else {}
	for organ_id in BaselineHuman.ORGAN_LAYOUT:
		if str((BaselineHuman.ORGAN_LAYOUT[organ_id] as Dictionary).get("zone", "")) != zone_id:
			continue
		var organ := organ_parts.get(organ_id) as Node3D
		if organ != null and is_instance_valid(organ) and organ.visible:
			return true
	return false
