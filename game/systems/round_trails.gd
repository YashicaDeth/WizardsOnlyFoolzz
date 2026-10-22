class_name RoundTrails
extends RefCounted

## What the X-ray was missing: not anatomy, but **what you have already done to
## it**.
##
## The reference is Project C.A.R.L. 0.8.71 (Unity, `ImpactLab.OrganXRay`), whose
## lab draws every round you have fired into a body as a path through the limb
## and states the rule on its own HUD: the newest round green, earlier rounds
## white, a white edge where a round reached bone, faint for a shallow round,
## pulsing where it is still bleeding. `DESIGN/CARL_COMPARISON.md` is the
## comparison; this is the half of it worth taking.
##
## The reason it is cheap here rather than a second gore system: **nothing new is
## recorded.** `BaselineHuman._record_wound()` has kept the entry point, the
## inward normal and `Penetration`'s depth fraction on every wound since AN6.5,
## and they are saved with the body. This reads them back and draws a shape. A
## body that has been shot six times already knows the six places; it has simply
## never shown them in the one view built for looking inside.
##
## Three rules keep it from becoming a HUD overlay:
##
## - **It only exists while the X-ray is up.** The caller hands an empty list
##   when the sweep lets go, and the meshes go with it. A trail left on a body
##   is a debug drawing, not a read.
## - **Depth is the length.** A round that stopped inside is a stub; one that
##   crossed the body reaches the far wall. The model already decided that in
##   `Penetration`, so this is not a second opinion about ballistics.
## - **Recency is the only colour.** Green for the round that landed last, white
##   for everything before it. Bone reached is a brighter edge, not a different
##   hue, so a corpse's history stays one instrument rather than a legend.

## The round that landed last. Green because nothing else in this game's palette
## is, so it cannot be confused with tissue, bone, brass or hazard lines.
const NEWEST := Color(0.22, 0.77, 0.42, 1.0)
## Every round before it. Bone white rather than pure white — it sits on a
## skeleton that is drawing in the same view.
const OLDER := Color(0.91, 0.90, 0.87, 1.0)
## The far end of a round that reached bone. Brighter than the shaft, and the
## only place this system draws more than a tube.
const BONE_EDGE := Color(1.0, 0.97, 0.86, 1.0)

## A shaft under five millimetres is invisible at the range the X-ray is used
## from; over about eight it reads as a pipe through the body rather than a path.
const SHAFT_RADIUS := 0.0055
const SHAFT_SIDES := 6
## The far end is narrower than the entry, because a round that has crossed
## tissue has given some of itself up on the way through.
const FAR_TAPER := 0.55

## How far into a limb a round has to get before it counts as having reached the
## skeleton. Written as a fraction of the limb's own thickness, so it stays true
## when a limb is reshaped: the bone of the torso sits deeper than the bone of a
## forearm only because the torso is thicker.
const BONE_AT := 0.62

## Per zone, matching `WoundMarks.MAX_PER_ZONE`'s reasoning: past a handful the
## display stops being history and becomes a thicket. Oldest goes first.
const MAX_TRAILS := 8

## Only rounds leave a path. A blade opens a wound with no trajectory worth
## drawing, and `WoundMarks` already gives it a crater and a layer.
const ROUND_TYPES := ["ballistic", "puncture"]

## Lifted off the surface by a hair so the trail does not z-fight the crater it
## starts in. `BloodPool.LIFT` uses the same trick for the same reason.
const ENTRY_LIFT := 0.0015

const HOLDER := "RoundTrails"


## The wound table, read as trajectories. One entry per round that went in,
## oldest first, capped. Exits are skipped: an exit is the other end of a path
## already drawn, and drawing it as a second round would double every through
## shot.
static func trails_from(marks: Array) -> Array:
	var out: Array = []
	for raw in marks:
		if not raw is Dictionary:
			continue
		var wound: Dictionary = raw
		if bool(wound.get("exit", false)):
			continue
		if not ROUND_TYPES.has(str(wound.get("type", ""))):
			continue
		var depth := clampf(float(wound.get("depth", 1.0)), 0.0, 1.0)
		var thickness := float(wound.get("thickness", 0.0))
		# A caller with no penetration model — a claw, a fall, an old save — still
		# gets a stub rather than a round that never happened.
		if thickness <= 0.0:
			thickness = 0.08
		out.append({
			"at": wound.get("at", Vector3.ZERO),
			"normal": wound.get("normal", Vector3.UP),
			"type": str(wound.get("type", "ballistic")),
			"length": maxf(depth * thickness, 0.004),
			"depth": depth,
			"through": bool(wound.get("through", false)),
			# A round that left the body reached whatever was in the middle of it.
			"bone": bool(wound.get("through", false)) or depth >= BONE_AT,
		})
	while out.size() > MAX_TRAILS:
		out.remove_at(0)
	return out


## The colour of one trail: recency decides the hue, depth decides how strongly
## it reads. A pistol round that barely entered is faint in exactly the way the
## reference's HUD calls out, and it stays faint because the body really is that
## shallow there.
static func tone_for(index: int, count: int, depth: float) -> Color:
	var base: Color = NEWEST if index >= count - 1 else OLDER
	var weight := lerpf(0.28, 1.0, clampf(depth, 0.0, 1.0))
	base.a = weight
	return base


## One trail as geometry, in the limb's own local space so it rides the limb
## through animation and leaves with it when it is cut off.
static func build(trail: Dictionary, index: int, count: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Round%d" % index
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.mesh = _shaft(trail, tone_for(index, count, float(trail.get("depth", 1.0))))

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Unshaded: this is a readout of where a round went, not a lit object, and a
	# shaded tube in a dark corridor disappears exactly when it is most wanted.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# The one thing the X-ray has to beat: the body it is drawn inside. Bone and
	# organs take priority 4 through `_set_depth_override`; the history of how
	# they were hit is drawn after them.
	material.no_depth_test = true
	material.render_priority = 5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	return node


## Rebuild a limb's trails against the current wound table, or take them away.
##
## `WorldXray.sweep()` calls `reveal_organs()` every frame, so this must be
## free when nothing has changed — the same trap Greg's 30 September playtest
## caught when wounds were rebuilt per frame and the frame rate fell to 7 fps.
## The signature covers count, the newest wound's identity and the depth table,
## which is everything a trail is built from.
static func refresh(part: Node3D, marks: Array) -> void:
	if part == null or not is_instance_valid(part):
		return
	var holder := part.get_node_or_null(HOLDER) as Node3D
	if marks.is_empty():
		if holder != null:
			part.remove_child(holder)
			holder.queue_free()
		return
	var signature := _signature(marks)
	if holder != null and is_instance_valid(holder) and str(holder.get_meta("signature", "")) == signature:
		return
	if holder != null:
		part.remove_child(holder)
		holder.queue_free()
	holder = Node3D.new()
	holder.name = HOLDER
	holder.set_meta("signature", signature)
	part.add_child(holder)
	var trails := trails_from(marks)
	for index in trails.size():
		holder.add_child(build(trails[index] as Dictionary, index, trails.size()))


static func _signature(marks: Array) -> String:
	var newest: Dictionary = {}
	for raw in marks:
		if raw is Dictionary and not bool((raw as Dictionary).get("exit", false)):
			newest = raw
	var depth_table := ""
	for raw in marks:
		if raw is Dictionary:
			depth_table += "%d." % roundi(float((raw as Dictionary).get("depth", 1.0)) * 100.0)
	return "%d|%d|%s" % [marks.size(), int(newest.get("seed", 0)), depth_table]


static func _shaft(trail: Dictionary, colour: Color) -> ArrayMesh:
	var entry: Vector3 = (trail.get("at", Vector3.ZERO) as Vector3)
	var normal: Vector3 = (trail.get("normal", Vector3.UP) as Vector3).normalized()
	var inward := -normal
	var length := maxf(float(trail.get("length", 0.02)), 0.001)
	var start := entry + normal * ENTRY_LIFT
	var finish := start + inward * length

	# Any perpendicular pair will do; pick the one that is not nearly parallel to
	# the round so the hexagon never collapses on a shot straight down.
	var guide := Vector3.UP if absf(inward.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var side_a := inward.cross(guide).normalized()
	var side_b := side_a.cross(inward).normalized()

	var ring_start: Array[Vector3] = []
	var ring_end: Array[Vector3] = []
	for side in SHAFT_SIDES:
		var angle := TAU * float(side) / float(SHAFT_SIDES)
		var offset := (side_a * cos(angle) + side_b * sin(angle))
		ring_start.append(start + offset * SHAFT_RADIUS)
		ring_end.append(finish + offset * SHAFT_RADIUS * FAR_TAPER)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in SHAFT_SIDES:
		var next := (side + 1) % SHAFT_SIDES
		_vertex(surface, ring_start[side], colour)
		_vertex(surface, ring_start[next], colour)
		_vertex(surface, ring_end[next], colour)
		_vertex(surface, ring_start[side], colour)
		_vertex(surface, ring_end[next], colour)
		_vertex(surface, ring_end[side], colour)

	# A round that reached bone ends on something brighter than a shaft fading
	# into flesh: the skeleton it stopped against.
	if bool(trail.get("bone", false)):
		var edge := BONE_EDGE
		edge.a = colour.a
		for side in SHAFT_SIDES:
			var next := (side + 1) % SHAFT_SIDES
			_vertex(surface, finish, edge)
			_vertex(surface, ring_end[side], edge)
			_vertex(surface, ring_end[next], edge)

	surface.generate_normals()
	return surface.commit()


static func _vertex(surface: SurfaceTool, at: Vector3, colour: Color) -> void:
	surface.set_color(colour)
	surface.add_vertex(at)
