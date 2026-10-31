class_name BloodSmear
extends RefCounted

## AN6.8. Blood that is carried rather than dropped.
##
## Every blood system in this game so far describes blood that *stopped*: a drop
## lands, a pool grows where it landed, a footprint spends a soaked foot,
## `Footprints` prints where the gait reports. None of them describes blood that
## is still on the body and goes wherever the body goes. Drag, throw or slide a
## corpse and the floor behind it stays clean — which is the one thing about
## gore that reads as fake, because a body heavy with blood is a brush.
##
## Reference: Project C.A.R.L. 0.8.71, whose physics gun drags a corpse across
## the lab floor and leaves long red streaks that follow the path, plus a short
## pink mist that hangs where the body was thrown. `DESIGN/CARL_COMPARISON.md`
## records that this is the one row where they are plainly ahead of us.
##
## Three rules keep this from being a second blood system:
##
## - **The pool stays the owner of blood on the floor.** Every segment feeds
##   `BloodPool.keep()` at the point it was laid, so a dragged body leaves a
##   streak *and* enriches the stains it drags through, and the existing merge
##   and drying rules apply unchanged.
## - **It costs the body what it lays.** Millilitres come off
##   `AnatomyComponent.blood_remaining`, so a body dragged across a room bleeds
##   out faster than one left lying, and `BloodLedger` sees the same event
##   stream it always did. Nothing here writes a save: a smear is a picture of a
##   wound that is already persisted.
## - **It needs a floor and it needs blood.** No wound, no trail; no ground under
##   the torso, no trail. A body in the air does not paint the air.

## How far the torso must travel between marks. Ten centimetres is under one
## torso-width, so consecutive quads overlap and the streak reads as continuous
## rather than as a dotted line.
const SEGMENT_SPACING := 0.10
## Below this the body is not being dragged, it is settling. Without a floor the
## corpse would leave a coin of blood whenever it twitched.
const MIN_SPEED := 0.35
## How high the torso can be while still touching the floor. A body thrown
## across the room is airborne and leaves nothing until it lands.
const GROUND_REACH := 2.4

## The streak's width at the body and where it has tapered to by the time the
## blood has run out. A person is about 0.35 m across the shoulders; the smear a
## torso drags is roughly half that, because only the wet side touches.
const WIDTH := 0.19
const END_TAPER := 0.22

## Above the pools, below the wound craters, for the same reason `BloodPool`
## lifts itself above the spatter it grew from.
const LIFT := 0.017

## Pool volume fed per segment. A segment covers ~0.019 m²; at
## `BloodPool.AREA_PER_VOLUME` that is 4.7 volume units, which would turn a drag
## into a lake in two metres. A third of a unit per segment grows the stain under
## a body at roughly a wound's own rate instead of in a single frame.
const POOL_FEED := 0.34

## Millilitres taken from the body per segment. A four-metre drag at this spacing
## costs about 160 mL of a 5 L body — enough to matter over a fight, not enough
## to empty one in a corridor.
const DRAIN_ML := 4.0

## However long the drag, the streak is bounded. Beyond this the oldest quads are
## recycled: the pool they fed stays on the floor, so what is lost is the crisp
## edge of a very old streak rather than the blood itself.
const MAX_SEGMENTS := 240

## A mist is a short puff, not a fog bank. Its volume is counted so a caller can
## budget it, and it carries the same colour as fresh blood.
const MIST_LIFETIME := 0.55
const MIST_SPEED := 2.4
const MIST_PER_VOLUME := 10
const MAX_MISTS := 8

## Streaks whose body has stopped bleeding or stopped moving. They stay on the
## floor, because blood does, but they are bounded: the pools they fed hold the
## stain even after the crisp streak has been recycled.
static var _retired: Array[MeshInstance3D] = []
const MAX_RETIRED := 24

static var _trails: Dictionary = {}
static var _clocks: Dictionary = {}
static var _mists: Array[CPUParticles3D] = []


## Called once per physics tick with the body's moving part (normally the torso
## rigid body) and the rig it belongs to. Returns a receipt, as everything in
## this project does: `{"ok": false, "reason": "..."}` when nothing was laid.
static func follow(root: Node, mover: Node3D, delta: float, bleed_source: Object = null) -> Dictionary:
	if root == null or not root.is_inside_tree():
		return {"ok": false, "reason": "no_root"}
	if mover == null or not is_instance_valid(mover) or not mover.is_inside_tree():
		return {"ok": false, "reason": "no_mover"}
	if delta <= 0.0:
		return {"ok": false, "reason": "no_time"}
	var rate := _bleed_rate(bleed_source)
	if rate <= 0.0:
		_retire(root, mover)
		return {"ok": false, "reason": "dry"}
	var floor_hit: Variant = _floor_under(root, mover)
	if floor_hit == null:
		return {"ok": false, "reason": "airborne"}
	var floor_at: Vector3 = floor_hit

	var key := mover.get_instance_id()
	var trail: Dictionary = _trails.get(key, {})
	if trail.is_empty():
		trail = {
			"root": root, "mover": mover, "node": null,
			"points": PackedVector3Array(), "headings": [],
			"length": 0.0, "speed": 0.0, "last_sample": mover.global_position,
			"anchor": floor_at,
			"stains": 0,
		}
		_trails[key] = trail
		trail["last_sample"] = mover.global_position
		return {"ok": true, "reason": "started", "segments": 0, "length": 0.0}

	# Speed is measured on the torso against the floor, so being swung in the air
	# above the same tile is not a drag.
	var moved: Vector3 = mover.global_position - (trail["last_sample"] as Vector3)
	moved.y = 0.0
	trail["last_sample"] = mover.global_position
	trail["speed"] = moved.length() / delta
	if float(trail["speed"]) < MIN_SPEED:
		return {"ok": false, "reason": "slow", "speed": snappedf(float(trail["speed"]), 0.01)}

	var points: PackedVector3Array = trail["points"]
	var anchor: Vector3 = trail.get("anchor", floor_at)
	var tip: Vector3 = points[points.size() - 1] if points.size() > 0 else anchor
	var gap := floor_at.distance_to(tip)
	if gap < SEGMENT_SPACING:
		return {"ok": true, "reason": "waiting", "length": snappedf(float(trail["length"]), 0.01)}

	var heading := (floor_at - tip)
	heading.y = 0.0
	if heading.length_squared() < 0.000001:
		heading = moved
	heading = heading.normalized()
	var headings: Array = trail["headings"]
	# The first mark is where the drag began, so the streak starts under the body
	# rather than one spacing behind it.
	if points.is_empty():
		points.append(anchor)
		headings.append(heading)
	points.append(floor_at)
	headings.append(heading)
	trail["length"] = float(trail["length"]) + gap
	trail["points"] = points

	# The floor's existing owner gets the blood; this only decides where it is.
	var fed := BloodPool.keep(root, floor_at, POOL_FEED * (gap / SEGMENT_SPACING))
	if fed >= 0:
		trail["stains"] = int(trail["stains"]) + 1
	_drain(bleed_source, DRAIN_ML * (gap / SEGMENT_SPACING))

	# Bounded, and the oldest quads go first.
	if points.size() > MAX_SEGMENTS:
		points.remove_at(0)
		headings.remove_at(0)

	_rebuild(root, trail)
	return {
		"ok": true, "reason": "laid", "segments": points.size(),
		"length": snappedf(float(trail["length"]), 0.01), "heading": heading,
		"width": WIDTH, "pool_volume": POOL_FEED,
	}


## The same follower for callers that have no physics tick of their own: a
## tween, an input handler, a scene script. Delta is measured from the previous
## sample, so a shoved body is judged on how fast it actually moved rather than
## on a frame time the caller guessed.
static func follow_now(root: Node, mover: Node3D, bleed_source: Object = null) -> Dictionary:
	if mover == null or not is_instance_valid(mover):
		return {"ok": false, "reason": "no_mover"}
	var key := mover.get_instance_id()
	var now := Time.get_ticks_usec()
	var previous := int(_clocks.get(key, 0))
	_clocks[key] = now
	var delta := 1.0 / 60.0
	if previous > 0:
		delta = clampf(float(now - previous) / 1000000.0, 0.0005, 0.25)
	return follow(root, mover, delta, bleed_source)


## The tick itself, for a mover whose whole motion is a tween: a shove, a fall.
## One sampler lives here rather than a copy in every caller, so the clock, the
## spacing and the duration are read from the same place as the motion being
## watched. `seconds` is the caller's motion tween's own duration. Returns the
## sampler so a caller can kill it, or null when there is nothing to watch.
static func follow_while(root: Node, mover: Node3D, bleed_source: Object, seconds: float) -> Tween:
	if root == null or not root.is_inside_tree():
		return null
	if mover == null or not is_instance_valid(mover) or not mover.is_inside_tree():
		return null
	if seconds <= 0.0:
		return null
	# The motion has two ends that are sampled unconditionally. A tween's steps
	# are only as reliable as the frame rate: a stalled frame longer than the
	# motion delivers a single step, and then `follow()`'s first sample only
	# creates the trail — the whole fall leaves no mark. So the start is sampled
	# here, before anything moves, and the finish is sampled by the tween's own
	# `finished`, whatever the steps in between managed.
	follow_now(root, mover, bleed_source)
	var sampler := root.create_tween()
	sampler.set_ignore_time_scale(true)
	var sample := func(_progress: float) -> void: follow_now(root, mover, bleed_source)
	sampler.tween_method(sample, 0.0, 1.0, seconds)
	sampler.finished.connect(func() -> void: follow_now(root, mover, bleed_source))
	return sampler


## Heavy damage throws a short mist the same system accounts for. Called by the
## wound that caused it, not by a timer: uncaused mist would hang on every hit.
static func throw_mist(root: Node, at: Vector3, direction: Vector3, volume: float = 1.0) -> Dictionary:
	if root == null or not root.is_inside_tree():
		return {"ok": false, "reason": "no_root"}
	if volume <= 0.0:
		return {"ok": false, "reason": "no_volume"}
	var puff := CPUParticles3D.new()
	puff.name = "BloodMist"
	puff.one_shot = true
	puff.emitting = false
	puff.explosiveness = 0.92
	puff.amount = clampi(roundi(volume * MIST_PER_VOLUME), 6, 60)
	puff.lifetime = MIST_LIFETIME
	puff.lifetime_randomness = 0.4
	var spray := direction
	spray.y = 0.0
	if spray.length_squared() < 0.0001:
		spray = Vector3.FORWARD
	spray = spray.normalized()
	puff.direction = Vector3(spray.x, 0.55, spray.z).normalized()
	puff.spread = 38.0
	puff.initial_velocity_min = MIST_SPEED * 0.45
	puff.initial_velocity_max = MIST_SPEED
	puff.gravity = Vector3(0, -5.5, 0)
	puff.scale_amount_min = 0.012
	puff.scale_amount_max = 0.03
	var speck := SphereMesh.new()
	speck.radius = 1.0
	speck.height = 2.0
	speck.radial_segments = 4
	speck.rings = 2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(BloodPool.FRESH.r, BloodPool.FRESH.g, BloodPool.FRESH.b, 0.42)
	material.vertex_color_use_as_albedo = false
	speck.material = material
	puff.mesh = speck
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Into the tree before it is placed: a global position set on a node with no
	# parent is not global, it is a local transform against nothing, so the puff
	# used to land wherever the root's own origin was and log an engine error on
	# every heavy hit.
	root.add_child(puff)
	puff.global_position = at
	puff.emitting = true

	_mists.append(puff)
	while _mists.size() > MAX_MISTS:
		var oldest: CPUParticles3D = _mists.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	return {"ok": true, "reason": "thrown", "droplets": puff.amount, "volume": volume}


## What has been carried so far, for tests and for anything that wants to read
## the trail without owning its geometry.
static func trail_for(root: Node, mover: Node3D) -> Dictionary:
	if mover == null or not is_instance_valid(mover):
		return {}
	var trail: Dictionary = _trails.get(mover.get_instance_id(), {})
	if trail.is_empty() or trail.get("root") != root:
		return {}
	var points: PackedVector3Array = trail["points"]
	if points.is_empty():
		return {}
	var headings: Array = trail["headings"]
	var last: Vector3 = (headings[headings.size() - 1] as Vector3) if headings.size() > 0 else Vector3.ZERO
	return {
		"points": points,
		"headings": headings,
		"length": float(trail["length"]),
		"segments": points.size(),
		"heading": last,
		"width_start": WIDTH,
		"width_end": WIDTH * END_TAPER,
		"mesh": trail.get("node"),
	}


static func segment_count(root: Node, mover: Node3D) -> int:
	var trail := trail_for(root, mover)
	return int(trail.get("segments", 0))


static func total_length(root: Node, mover: Node3D) -> float:
	var trail := trail_for(root, mover)
	return float(trail.get("length", 0.0))


static func mist_count() -> int:
	var live := 0
	for puff in _mists:
		if is_instance_valid(puff):
			live += 1
	return live


static func clear() -> void:
	for trail in _trails.values():
		var node: MeshInstance3D = (trail as Dictionary).get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	_trails.clear()
	_clocks.clear()
	for node in _retired:
		if is_instance_valid(node):
			node.queue_free()
	_retired.clear()
	for puff in _mists:
		if is_instance_valid(puff):
			puff.queue_free()
	_mists.clear()


## The streak itself: one quad per pair of points, oriented along the travel and
## tapering from `WIDTH` to `WIDTH * END_TAPER`, so the mark narrows as the body
## runs out of blood rather than stopping dead.
static func _rebuild(root: Node, trail: Dictionary) -> void:
	var points: PackedVector3Array = trail["points"]
	if points.size() < 2:
		return
	var node := trail.get("node") as MeshInstance3D
	if node == null or not is_instance_valid(node):
		node = MeshInstance3D.new()
		node.name = "BloodSmear"
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		trail["node"] = node
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 2
	node.material_override = material
	node.mesh = _strip(points, trail["headings"] as Array)


static func _strip(points: PackedVector3Array, headings: Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := points.size()
	for index in count - 1:
		var from := points[index]
		var to := points[index + 1]
		var along: Vector3 = (headings[index] as Vector3) if index < headings.size() else (to - from).normalized()
		var across := Vector3(-along.z, 0.0, along.x).normalized()
		var t0 := float(index) / maxf(1.0, float(count - 1))
		var t1 := float(index + 1) / maxf(1.0, float(count - 1))
		var half0 := WIDTH * lerpf(1.0, END_TAPER, t0) * 0.5
		var half1 := WIDTH * lerpf(1.0, END_TAPER, t1) * 0.5
		# The fresh end is wet and opaque, the tail dried toward the pool's own
		# dried tone, so a long drag reads as one stain ageing along its length.
		var tone0: Color = BloodPool.DRIED.lerp(BloodPool.FRESH, t0)
		var tone1: Color = BloodPool.DRIED.lerp(BloodPool.FRESH, t1)
		tone0.a = lerpf(0.38, 0.92, t0)
		tone1.a = lerpf(0.38, 0.92, t1)
		var a := from - across * half0
		var b := from + across * half0
		var c := to + across * half1
		var d := to - across * half1
		_vertex(surface, a, tone0)
		_vertex(surface, b, tone0)
		_vertex(surface, c, tone1)
		_vertex(surface, a, tone0)
		_vertex(surface, c, tone1)
		_vertex(surface, d, tone1)
	surface.generate_normals()
	return surface.commit()


static func _vertex(surface: SurfaceTool, at: Vector3, colour: Color) -> void:
	surface.set_color(colour)
	surface.set_normal(Vector3.UP)
	surface.add_vertex(at + Vector3.UP * LIFT)


static func _floor_under(root: Node, mover: Node3D) -> Variant:
	var viewport := root.get_viewport()
	if viewport == null:
		return null
	var world := viewport.find_world_3d()
	if world == null:
		return null
	# Probed from a hand's width above the mover: a rig's own origin sits on
	# the floor, and a zero-length ray from exactly on a surface reports nothing.
	var from := mover.global_position + Vector3.UP * 0.05
	if from.y > GROUND_REACH + 1.0:
		return null
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * GROUND_REACH)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if mover is CollisionObject3D:
		query.exclude = [mover.get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return (hit["position"] as Vector3) + Vector3.UP * LIFT


static func _bleed_rate(source: Object) -> float:
	if source == null or not is_instance_valid(source):
		return 0.0
	var anatomy = source.get("anatomy")
	if anatomy == null:
		return 0.0
	var rate := 0.0
	if anatomy.get("bleed_rate") != null:
		rate = float(anatomy.get("bleed_rate"))
	var remaining := float(anatomy.get("blood_remaining"))
	var capacity := float(anatomy.get("blood_capacity"))
	# A body that is merely cut but not actively bleeding still wets the floor it
	# is dragged across, as long as it has blood left to lose.
	if rate <= 0.0 and remaining > 0.0 and remaining < capacity * 0.98:
		rate = 0.5
	return rate


static func _drain(source: Object, millilitres: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	var anatomy = source.get("anatomy")
	if anatomy == null:
		return
	var remaining := float(anatomy.get("blood_remaining"))
	anatomy.set("blood_remaining", maxf(0.0, remaining - millilitres))


static func _retire(root: Node, mover: Node3D) -> void:
	var key := mover.get_instance_id()
	var trail: Dictionary = _trails.get(key, {})
	if trail.is_empty():
		return
	if trail.get("root") != root:
		return
	# The streak stays where it was laid; only the bookkeeping is dropped, so a
	# body that stops bleeding does not erase the drag that got it there. The
	# clock goes with it, or a recycled instance id would inherit a stale sample.
	_clocks.erase(key)
	var node := trail.get("node") as MeshInstance3D
	if node != null and is_instance_valid(node):
		_retired.append(node)
		while _retired.size() > MAX_RETIRED:
			var oldest: MeshInstance3D = _retired.pop_front()
			if is_instance_valid(oldest):
				oldest.queue_free()
	_trails.erase(key)
