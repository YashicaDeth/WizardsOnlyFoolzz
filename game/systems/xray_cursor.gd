extends RefCounted

## The cursor is a tool, and one of its buttons sees through people.
##
## Greg: *"once you use the custom mouse it has a circular xray button you can
## click just for a gross factor and visceral elements"*, and separately that
## the radial replaces sliders for weapons, cybernetics, modes and seals. So
## this is deliberately built as **one segment of a ring that will hold more
## segments**, not as a bespoke X-ray widget — C2 extends it rather than
## replacing it.
##
## The important design consequence, and the reason it is a cursor rather than a
## mode: seeing inside a body becomes a *constant available verb* instead of
## something you enter and leave. That is what `DESIGN/INTERFACE_DIRECTION.md`
## means by everything being inspectable, and it is the difference between the
## anatomy system being a feature and being the texture of the game.
##
## Drawn into a caller's canvas like `CellOutzType` and `CellOutzGrunge`, so any
## screen can carry it without owning a node.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const OrganSystem := preload("res://systems/organ_system.gd")

const RING := 26.0
const BUTTON_ARC := 0.92
const BUTTON_CENTRE := -PI * 0.5

const BRASS := Color("b0552a")
const BONE := Color("e6d4ac")
const HOT := Color("a8281a")
const SOOT := Color(0.05, 0.036, 0.028, 0.88)

## How far the reticle reads into a body, in metres. The same short reach the
## lab's rip prompt uses: the X-ray reaches 22 m, but naming what is under the
## crosshair is about the body in front of you.
const READOUT_REACH := OrganSystem.RIP_REACH
## Bones the ray can name, for the zones whose skeleton is a single piece. The
## chest carries named ribs and numbered vertebrae of its own, so it is not in
## this table.
const BONE_LABELS := {
	"head": "SKULL", "left_arm": "LEFT ARM BONE", "right_arm": "RIGHT ARM BONE",
	"left_leg": "LEFT LEG BONE", "right_leg": "RIGHT LEG BONE",
}
## One tone per kind of line, so a tissue and a landmark are told apart at a
## glance rather than by reading three words at cursor speed.
const TONES := {"tissue": BONE, "hardware": HOT, "bone": BONE * Color(1, 1, 1, 0.78), "landmark": BRASS}


## Is this click on the X-ray segment? Callers ask before their own hit tests,
## because the cursor sits on top of everything.
static func on_button(cursor_at: Vector2, click_at: Vector2) -> bool:
	var offset := click_at - cursor_at
	var distance := offset.length()
	if distance < RING * 0.55 or distance > RING * 1.45:
		return false
	var angle := offset.angle()
	var delta := angle_difference(angle, BUTTON_CENTRE)
	return absf(delta) <= BUTTON_ARC * 0.5


static func draw(canvas: CanvasItem, at: Vector2, active: bool, elapsed: float) -> void:
	# A scratched brass ring, not a neon circle. The ring is drawn in broken
	# segments so it reads as a worn machined part.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4471
	var segments := 46
	for index in segments:
		if rng.randf() < 0.14:
			continue
		var from := TAU * float(index) / float(segments)
		var to := TAU * float(index + 1) / float(segments)
		canvas.draw_arc(at, RING, from, to, 3, BRASS * Color(1, 1, 1, 0.55 + rng.randf() * 0.35), 2.0)

	# The X-ray segment: a thicker arc with its own ground, so it reads as a
	# physical button on the ring rather than a highlight.
	var lit: Color = HOT if active else BONE * Color(1, 1, 1, 0.62)
	canvas.draw_arc(at, RING, BUTTON_CENTRE - BUTTON_ARC * 0.5, BUTTON_CENTRE + BUTTON_ARC * 0.5, 18, SOOT, 11.0)
	canvas.draw_arc(at, RING, BUTTON_CENTRE - BUTTON_ARC * 0.5, BUTTON_CENTRE + BUTTON_ARC * 0.5, 18, lit, 3.0)
	# A skull mark on the button, small enough to read as an icon at cursor size.
	var mark := at + Vector2(0, -RING)
	canvas.draw_circle(mark, 4.2, lit * Color(1, 1, 1, 0.9 if active else 0.55))
	canvas.draw_rect(Rect2(mark + Vector2(-2.6, 2.2), Vector2(5.2, 2.6)), lit * Color(1, 1, 1, 0.9 if active else 0.55))
	canvas.draw_rect(Rect2(mark + Vector2(-1.9, -1.4), Vector2(1.5, 1.8)), SOOT)
	canvas.draw_rect(Rect2(mark + Vector2(0.5, -1.4), Vector2(1.5, 1.8)), SOOT)

	# The remaining arc is left empty on purpose - it is where C2's weapon,
	# cybernetic and seal segments go, and showing the empty seats makes the
	# cursor read as an unfinished tool rather than as a decoration.
	for slot in 3:
		var angle := BUTTON_CENTRE + TAU * float(slot + 1) / 4.0
		var seat := at + Vector2(cos(angle), sin(angle)) * RING
		canvas.draw_circle(seat, 2.6, BRASS * Color(1, 1, 1, 0.30))

	# The pointer itself: a gap-centred cross, so the exact pixel stays visible.
	var pulse := 1.0 + sin(elapsed * 3.1) * 0.06
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		canvas.draw_line(at + axis * 5.0, at + axis * 12.0 * pulse, BONE * Color(1, 1, 1, 0.75), 1.4)
	canvas.draw_circle(at, 1.6, HOT if active else BONE)

	if active:
		# A dashed outer ring while it is on, so the state is unmistakable at a
		# glance without a label sitting next to the pointer.
		var ticks := 20
		for index in ticks:
			var from := TAU * float(index) / float(ticks) + elapsed * 0.6
			canvas.draw_arc(at, RING + 7.0, from, from + 0.1, 3, HOT * Color(1, 1, 1, 0.5), 1.6)
		CellOutzType.draw_text(canvas, at + Vector2(RING + 14.0, -6.0), "XRAY", 9.0, HOT, 1.0)


# --- three structures under the reticle --------------------------------------
#
# Carl 0.8.71 names three structures at once -- `RIGHT LUNG / RIGHT RIB 3 /
# T5 VERTEBRA` -- while ours named the one organ the aim was on. The readout is
# the same instrument, so it is built here rather than as a second widget.
#
# The tissue comes from `OrganSystem.aimed_part()`, the resolution the lab's rip
# prompt and the scan overlay already share, so there is no parallel anatomy
# table: a body that cannot answer yields fewer lines instead of a guessed name.
# The bone is the skeleton the X-ray itself draws, so the name is where the ray
# actually goes rather than a label attached to a zone.

## Up to three named structures along an aim ray, in the order it meets them:
## the tissue it lands in (an organ, or installed hardware), the bone behind
## that tissue, and the deepest distinct skeletal landmark it reaches. Each line
## is `{"kind", "label", "at", "depth"}`. An aim that reaches no body, or a body
## with nothing at that point, gives an empty list; a ray that crosses only bone
## gives bone lines with no tissue line.
static func structures(rig: Node, from: Vector3, along: Vector3, reach := READOUT_REACH) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if rig == null or not is_instance_valid(rig) or not rig.is_inside_tree():
		return out
	if along.length_squared() < 0.000001:
		return out
	var ray := along.normalized()
	var body := rig as BaselineHuman
	if body == null:
		return out
	var seen := {}
	var tissue_depth := 0.0
	var tissue := OrganSystem.aimed_part([body], from, ray, reach)
	if not tissue.is_empty():
		tissue_depth = float(tissue.get("distance", 0.0))
		var label := OrganSystem.label_of(body, str(tissue.get("id", "")))
		if not label.is_empty():
			seen[label] = true
			out.append({
				"kind": "hardware" if str(tissue.get("id", "")).begins_with("implant:") else "tissue",
				"label": label, "at": tissue.get("at", from), "depth": snappedf(tissue_depth, 0.001),
			})
	# Entry and exit of every bone the ray crosses, so the far wall of the skull
	# counts as the bone behind the brain rather than being missed as "in front".
	var slots := 0
	for cross: Dictionary in _bone_crossings(body, from, ray, reach):
		if slots >= 2:
			break
		var label := str(cross.get("label", ""))
		if label.is_empty() or seen.has(label):
			continue
		# "Behind it" is a position, not a guess: a bone the ray meets before the
		# tissue is in front of it and does not answer this line.
		if tissue_depth > 0.0 and float(cross.get("depth", 0.0)) <= tissue_depth:
			continue
		seen[label] = true
		out.append({
			"kind": "bone" if slots == 0 else "landmark",
			"label": label, "at": cross.get("at", from), "depth": snappedf(float(cross.get("depth", 0.0)), 0.001),
		})
		slots += 1
	return out


## Draws the lines beside the cursor, one per named structure. Nothing is drawn
## for an empty list, which is what keeps the reticle quiet over empty air.
static func draw_structures(canvas: CanvasItem, at: Vector2, lines: Array, alpha := 1.0) -> void:
	if lines.is_empty():
		return
	var width := 0.0
	for line: Dictionary in lines:
		width = maxf(width, CellOutzType.width(str(line.get("label", "")), 10.0, 1.0))
	var box := Rect2(at + Vector2(10.0, -8.0), Vector2(width + 16.0, 8.0 + lines.size() * 13.0))
	canvas.draw_rect(box, SOOT * Color(1, 1, 1, alpha))
	canvas.draw_rect(box, BRASS * Color(1, 1, 1, 0.65 * alpha), false, 1.0)
	var y := box.position.y + 4.0
	for line: Dictionary in lines:
		var tone: Color = TONES.get(str(line.get("kind", "")), BONE)
		canvas.draw_rect(Rect2(Vector2(box.position.x + 5.0, y + 3.0), Vector2(3.0, 3.0)), tone * Color(1, 1, 1, alpha))
		CellOutzType.draw_text(canvas, Vector2(box.position.x + 12.0, y), str(line.get("label", "")), 10.0, tone * Color(1, 1, 1, alpha), 1.0)
		y += 13.0



## Every bone the ray crosses, sorted by how far along the ray it is. Bones of a
## zone that has been taken off the body are not the body's any more.
static func _bone_crossings(body: BaselineHuman, from: Vector3, ray: Vector3, reach: float) -> Array:
	var hits: Array = []
	for zone_id in body.bones:
		var zone := str(zone_id)
		if body.severed.has(zone):
			continue
		var frame := body.bones[zone_id] as Node3D
		if frame == null or not is_instance_valid(frame) or not frame.is_inside_tree():
			continue
		for child in frame.get_children():
			var piece := child as MeshInstance3D
			if piece == null or piece.mesh == null or not piece.is_inside_tree():
				continue
			var span := _ray_box_span(piece.global_transform * piece.get_aabb(), from, ray)
			if span.x < 0.0:
				continue
			var label := _bone_label(piece, zone)
			for depth in [span.x, span.y]:
				var at_depth := float(depth)
				if at_depth < 0.0 or at_depth > reach:
					continue
				hits.append({"label": label, "at": from + ray * at_depth, "depth": at_depth})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) < float(b.depth))
	return hits


## The name the skeleton itself carries: the 33 vertebrae are numbered, the ribs
## are numbered, and the single-bone zones are named by the zone they belong to.
static func _bone_label(piece: MeshInstance3D, zone: String) -> String:
	if piece.has_meta("vertebra"):
		return "VERTEBRA %d" % int(piece.get_meta("vertebra"))
	if piece.has_meta("rib"):
		return "RIB %d" % int(piece.get_meta("rib"))
	return str(BONE_LABELS.get(zone, "BONE"))


## Entry and exit depths of a ray through an axis-aligned box, as `Vector2(entry,
## exit)`; `x < 0` when the ray misses entirely.
static func _ray_box_span(box: AABB, from: Vector3, ray: Vector3) -> Vector2:
	var enter := -INF
	var exit := INF
	for axis in 3:
		var origin := from[axis]
		var direction := ray[axis]
		if absf(direction) < 0.000001:
			if origin < box.position[axis] or origin > box.position[axis] + box.size[axis]:
				return Vector2(-1.0, -1.0)
			continue
		var near := (box.position[axis] - origin) / direction
		var far := (box.position[axis] + box.size[axis] - origin) / direction
		if near > far:
			var swap := near
			near = far
			far = swap
		enter = maxf(enter, near)
		exit = minf(exit, far)
	if enter > exit:
		return Vector2(-1.0, -1.0)
	return Vector2(enter, exit)
