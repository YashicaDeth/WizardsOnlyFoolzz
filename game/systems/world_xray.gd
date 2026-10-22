class_name WorldXray
extends RefCounted

## B3.3/B3.4. The X-ray stops being a page in the index and becomes something
## you do while standing in the world.
##
## `xray_cursor.gd` was written as one seat of a ring that would grow, and its
## own comment names the consequence: seeing inside a body should be *a constant
## available verb* rather than a mode you enter and leave. Until now it was only
## ever true inside the dossier, where the body in front of you is a diagram.
## This is the same verb pointed at the actual world.
##
## Two rules make it worth having rather than being a filter:
##
## - **Range is real.** You see into what is near you, not into the region. The
##   falloff is what makes walking toward something a way of learning about it.
## - **It sees through the wall.** A skeleton that loses the depth test to the
##   shed in front of it is not an X-ray, it is a highlight. While this is on,
##   revealed bone and organs draw over whatever is between you and them — which
##   is the gross, visceral thing that was asked for, and it is also the only
##   version that is tactically worth using.

## How far into the world it reaches. Generous enough to read a room through its
## wall, short enough that it is not a map.
const RANGE := 22.0
## Past this share of the range the reveal fades rather than stopping dead, so
## walking toward somebody brings them up instead of popping them in.
const FALLOFF_FROM := 0.65


## How strongly a body at this distance reads, 0 when out of reach entirely.
static func strength_at(distance: float, reach: float = RANGE) -> float:
	if distance > reach:
		return 0.0
	var ratio := clampf(distance / maxf(0.01, reach), 0.0, 1.0)
	if ratio <= FALLOFF_FROM:
		return 1.0
	return clampf(1.0 - (ratio - FALLOFF_FROM) / (1.0 - FALLOFF_FROM), 0.0, 1.0)


## How far short of a named structure a sightline is allowed to stop, in metres.
## The ray ends on the surface of whatever is in front, not at the point inside
## the body, so a few centimetres of skin must not read as a wall.
const SIGHT_MARGIN := 0.05


## Can the eye get to this point at all: nothing solid between it and the point.
## `ignore` is the RIDs of whatever the caller is already looking *at* — a rig's
## own hitboxes must not occlude the organs inside it. With no world (a diagram,
## a headless test with no geometry) there is nothing to be hidden behind.
static func in_sight(eye: Vector3, at: Vector3, world: World3D, ignore: Array = []) -> bool:
	if world == null:
		return true
	var span := eye.distance_to(at)
	if span <= 0.001:
		return true
	var query := PhysicsRayQueryParameters3D.create(eye, at)
	# Every X-ray body's hit geometry is an Area3D; a query that collides with
	# areas would have the body hide itself.
	query.collide_with_areas = false
	query.exclude = ignore
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return eye.distance_to(hit.get("position", at)) >= span - SIGHT_MARGIN


## The one answer to "does the sweep have hold of this thing from here", which
## naming and anything else that reports must ask rather than inventing its own.
##
## Range is `strength_at()`'s own rule, so a body the sweep has dropped is never
## named however clear its anatomy is on paper. The sightline is the same one
## `BlackMirrorCamera` tests its depth targets with: the sweep draws through the
## shed on purpose (B3.4), but identifying a lung through it would be the
## instrument asserting something the eye cannot check.
static func reads(eye: Vector3, at: Vector3, world: World3D = null, ignore: Array = []) -> bool:
	if strength_at(eye.distance_to(at)) <= 0.0:
		return false
	return in_sight(eye, at, world, ignore)


## Turns the sweep on or off across a set of rigs, and hands back what is
## currently lit so the caller can report it without asking a second time.
## Bodies that fall out of range are put back the way they were found — a rig
## left permanently see-through would leak the effect into the next fight.
static func sweep(origin: Vector3, rigs: Array, active: bool, reach: float = RANGE) -> Array:
	var lit: Array = []
	for entry in rigs:
		var rig := entry as BaselineHuman
		if rig == null or not is_instance_valid(rig) or not rig.is_inside_tree():
			continue
		var strength := 0.0
		if active:
			strength = strength_at(origin.distance_to(rig.global_position), reach)
		var on := strength > 0.0
		rig.reveal_organs(on)
		rig.see_through(on)
		if on:
			lit.append({"subject_id": rig.subject_id, "strength": snappedf(strength, 0.01)})
	return lit
