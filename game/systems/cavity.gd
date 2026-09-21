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
	var reach := absf(bounds.size.dot(local_normal.abs())) * 0.5
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


## The same cut, applied to a rig's zone, with whatever is inside that zone
## revealed because there is now a hole to see it through.
##
## Organs are built `visible = false` and stay that way until something opens
## the body -- which until now nothing actually did, so the organ meshes were
## only ever seen through the layer-exposure path. This is the other way in.
static func open_zone(rig: Node, zone_id: String, facing: Vector3) -> Dictionary:
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
	var cut := open(part, facing)
	if cut.is_empty() or cut.opened == null:
		return {}
	part.mesh = cut.opened
	part.set_meta(OPEN_MARK, true)
	var revealed := _reveal_organs(rig, zone_id)
	cut["organs"] = revealed
	cut["zone"] = zone_id
	return cut


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
