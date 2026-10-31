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
## A blade is still something the X-ray has to state, and the reference states it
## in magenta rather than as a path.
const CUT_TYPES := ["cut", "shear"]

## The rest of the reference's legend: red where a round went in, blue where it
## left, purple where it stopped, magenta where it was cut. Colours only, because
## each one is a fact the wound table already holds.
const ENTRY_TONE := Color("c2382a")
const EXIT_TONE := Color("3f7fd0")
const STOP_TONE := Color("8a4fb5")
const CUT_TONE := Color("c05aa8")
const DOT_RADIUS := 0.006
## How wide a cut stroke is against its length. A slash is a line, not a hole.
const CUT_STROKE := 0.16

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


## Where a round went in, and where it ended: out of the body or inside it. Pure,
## so a test can read the legend without a scene, and `build()` only draws what
## this says.
static func dots_for(trail: Dictionary) -> Array:
	var out: Array = []
	var entry: Vector3 = trail.get("at", Vector3.ZERO)
	var normal: Vector3 = (trail.get("normal", Vector3.UP) as Vector3).normalized()
	var start := entry + normal * ENTRY_LIFT
	var finish := start - normal * maxf(float(trail.get("length", 0.02)), 0.001)
	out.append({"kind": "entry", "tone": ENTRY_TONE, "at": start})
	if bool(trail.get("through", false)):
		out.append({"kind": "exit", "tone": EXIT_TONE, "at": finish})
	elif float(trail.get("depth", 1.0)) < 1.0:
		out.append({"kind": "stop", "tone": STOP_TONE, "at": finish})
	return out


## The blade wounds the X-ray has to state. Exits are skipped for the same reason
## they are skipped in `trails_from()`: they are the other end of a mark already
## drawn, and an exit is not a second cut.
static func cuts_from(marks: Array) -> Array:
	var out: Array = []
	for raw in marks:
		if not raw is Dictionary:
			continue
		var wound: Dictionary = raw
		if bool(wound.get("exit", false)):
			continue
		if not CUT_TYPES.has(str(wound.get("type", ""))):
			continue
		out.append({
			"at": wound.get("at", Vector3.ZERO),
			"normal": wound.get("normal", Vector3.UP),
			"radius": float(wound.get("radius", 0.02)),
			"aspect": float(wound.get("aspect", 1.0)),
			"rotation": float(wound.get("shape_rotation", 0.0)),
			"depth": float(wound.get("depth", 1.0)),
		})
	return out


## One trail as geometry, in the limb's own local space so it rides the limb
## through animation and leaves with it when it is cut off.
static func build(trail: Dictionary, index: int, count: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Round%d" % index
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.mesh = _shaft(trail, tone_for(index, count, float(trail.get("depth", 1.0))))
	node.material_override = _material()
	# The legend, drawn as the two ends of the path: a round's history is not only
	# the line through the body but where it entered and where it ended up.
	for dot: Dictionary in dots_for(trail):
		var dot_node := MeshInstance3D.new()
		dot_node.name = "%sDot" % str(dot.kind).capitalize()
		var sphere := SphereMesh.new()
		sphere.radius = DOT_RADIUS
		sphere.height = DOT_RADIUS * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		dot_node.mesh = sphere
		dot_node.position = dot.get("at", Vector3.ZERO)
		dot_node.material_override = _point_material(dot.get("tone", ENTRY_TONE), float(trail.get("depth", 1.0)))
		node.add_child(dot_node)
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
	var cuts := cuts_from(marks)
	for index in cuts.size():
		holder.add_child(build_cut(cuts[index] as Dictionary, index))


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


## One blade mark: a thin magenta stroke across the opening, in the plane of the
## skin, at the angle the blade came in at.
static func build_cut(cut: Dictionary, index: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Cut%d" % index
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.mesh = _stroke(cut)
	node.material_override = _material()
	return node


static func _material() -> StandardMaterial3D:
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
	return material


static func _point_material(colour: Color, depth: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour * Color(1, 1, 1, lerpf(0.45, 1.0, clampf(depth, 0.0, 1.0)))
	# A dot is a fact, not a surface: it is lit by nothing and hidden by nothing.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = 6
	return material


static func _stroke(cut: Dictionary) -> ArrayMesh:
	var at: Vector3 = (cut.get("at", Vector3.ZERO) as Vector3)
	var normal: Vector3 = (cut.get("normal", Vector3.UP) as Vector3).normalized()
	var reference := Vector3.FORWARD if absf(normal.dot(Vector3.FORWARD)) < 0.98 else Vector3.RIGHT
	var tangent := reference.cross(normal).normalized()
	var bitangent := normal.cross(tangent).normalized()
	var angle := float(cut.get("rotation", 0.0))
	var along := tangent * cos(angle) + bitangent * sin(angle)
	var across := normal.cross(along).normalized()
	var length := maxf(float(cut.get("radius", 0.02)) * maxf(float(cut.get("aspect", 1.0)), 1.0), 0.02)
	var width := maxf(length * CUT_STROKE, 0.003)
	var origin := at + normal * ENTRY_LIFT * 1.6
	var colour := CUT_TONE
	colour.a = lerpf(0.5, 1.0, clampf(float(cut.get("depth", 1.0)), 0.0, 1.0))
	var corners: Array[Vector3] = [
		origin - along * length * 0.5 - across * width * 0.5,
		origin + along * length * 0.5 - across * width * 0.5,
		origin + along * length * 0.5 + across * width * 0.5,
		origin - along * length * 0.5 + across * width * 0.5,
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0, 1, 2, 0, 2, 3]:
		_vertex(surface, corners[index], colour)
	surface.generate_normals()
	return surface.commit()


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
