extends Node

## Point at a part of a body, and that part leaves the diagram and turns.
##
## This is Tier 1c (B1 and B2 on `CHECKLIST.md`), and its one hard rule is the
## reason it is built this way: **the part must appear to leave the diagram, not
## to open a window.** So there is no modal, no separate screen and no hard cut.
## The viewport holding the 3D part is animated out of the exact spot on the
## schematic where the part lives, growing into the inspect slot, and it is the
## same live object the whole way.
##
## One verb for the whole body, per B2: flesh, bone, organs and installed
## hardware are all just parts, listed together, inspected identically. Adding a
## new category means adding a row, not a screen.
##
## Drawing is done *into* the caller's canvas rather than by a child `Control`,
## matching how `CellOutzType` already works here — it keeps the World Index's
## scanlines and plate chrome on top of the page instead of underneath it.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const PART_VIEWER := preload("res://systems/part_viewer.gd")
const Grunge := preload("res://systems/celloutz_grunge.gd")
const ImplantCatalog := preload("res://systems/implant_catalog.gd")
const WoundCatalog := preload("res://systems/wound_catalog.gd")

const INK := Color("e6d4ac")
const COPPER := Color("b0552a")
const HOT := Color("a8281a")
const MOSS := Color("8a9a4a")
const SPORE := Color("7f9440")
const BRUISE := Color("6b3f6e")

const ZONES := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]
const ZONE_LABELS := {
	"head": "HEAD", "torso": "TORSO", "left_arm": "LEFT ARM",
	"right_arm": "RIGHT ARM", "left_leg": "LEFT LEG", "right_leg": "RIGHT LEG",
}
const ORGANS_BY_ZONE := {
	"head": ["brain"],
	"torso": ["heart", "left_lung", "right_lung", "liver", "gut", "spine"],
}
const ZONE_HEALTH := {
	"head": 45.0, "torso": 120.0, "left_arm": 65.0,
	"right_arm": 65.0, "left_leg": 75.0, "right_leg": 75.0,
}

## Centres in normalised diagram space, and how wide each zone reads there.
const ZONE_SHAPE := {
	"head": {"at": Vector2(0.5, 0.10), "size": Vector2(0.17, 0.11)},
	"torso": {"at": Vector2(0.5, 0.36), "size": Vector2(0.30, 0.26)},
	"left_arm": {"at": Vector2(0.23, 0.37), "size": Vector2(0.11, 0.25)},
	"right_arm": {"at": Vector2(0.77, 0.37), "size": Vector2(0.11, 0.25)},
	"left_leg": {"at": Vector2(0.39, 0.73), "size": Vector2(0.13, 0.30)},
	"right_leg": {"at": Vector2(0.61, 0.73), "size": Vector2(0.13, 0.30)},
}

var subject: Dictionary = {}
var zone := "torso"
var part_index := 0
var hovered_part_index := -1
var xray := false
var lift := 0.0
var elapsed := 0.0
var viewer_dragging := false

var _parts: Array = []
var _viewer: SubViewport
var _compare_viewer: SubViewport
var _zone_rects: Dictionary = {}
var _part_rects: Array = []
var _lift_from := Rect2()
var _stage_rect := Rect2()
var _subject_id := ""


func _ready() -> void:
	_viewer = PART_VIEWER.new()
	_viewer.name = "PartViewer"
	add_child(_viewer)
	_compare_viewer = PART_VIEWER.new()
	_compare_viewer.name = "ComparisonViewer"
	add_child(_compare_viewer)
	set_process(true)


## Guarded on identity. This is called every frame by the page draw, and
## rebuilding the part list unconditionally would reset the selection to FLESH
## the instant anything else redrew.
func set_subject(value: Dictionary) -> void:
	var incoming := str(value.get("name", ""))
	subject = value
	if incoming == _subject_id:
		return
	_subject_id = incoming
	zone = "torso"
	part_index = 0
	hovered_part_index = -1
	_rebuild_parts()
	_begin_lift()


func _process(delta: float) -> void:
	elapsed += delta
	lift = minf(1.0, lift + delta * 3.6)


# --- the parts of a body ---------------------------------------------------

func _rebuild_parts() -> void:
	_parts.clear()
	_parts.append({"kind": "limb", "id": zone, "zone": zone, "label": "FLESH", "note": "soft tissue"})
	_parts.append({"kind": "bone", "id": zone, "zone": zone, "label": "BONE", "note": "structure"})
	for organ_id in ORGANS_BY_ZONE.get(zone, []):
		var organ_state: Dictionary = (_anatomy().get("organs", {}) as Dictionary).get(str(organ_id), {})
		_parts.append({"kind": "organ", "id": organ_id, "zone": zone, "label": str(organ_id).replace("_", " ").to_upper(), "note": "organ", "ruptured": bool(organ_state.get("ruptured", false)), "compressed": bool(organ_state.get("compressed", false))})
	for implant in _implants_in(zone):
		var part: Dictionary = implant.duplicate(true)
		part["kind"] = "implant"
		part["label"] = str(implant.name).to_upper()
		part["note"] = "installed"
		_parts.append(part)
	part_index = clampi(part_index, 0, maxi(0, _parts.size() - 1))
	hovered_part_index = -1


func _anatomy() -> Dictionary:
	return subject.get("anatomy_state", subject.get("anatomy", {}))


## B6.8v2. A rupture does not advertise itself through the ordinary specimen
## view. The same saved anatomy state gains a diagnostic sentence only while
## the dossier is deliberately in X-ray mode.
func xray_findings() -> Array[String]:
	var findings: Array[String] = []
	if not xray:
		return findings
	var organs: Dictionary = _anatomy().get("organs", {})
	for organ_id in organs:
		var organ: Dictionary = organs[organ_id]
		if bool(organ.get("ruptured", false)):
			findings.append("INTERNAL BLEED · " + str(organ_id).replace("_", " ").to_upper())
	var spine: Dictionary = organs.get("spine", {})
	var damaged: Array = spine.get("vertebrae_damaged", [])
	if not damaged.is_empty():
		findings.append("SPINE · %d / %d VERTEBRAE DAMAGED" % [damaged.size(), AnatomyComponent.SPINE_VERTEBRAE])
	return findings


func _implants_in(zone_id: String) -> Array:
	var out: Array = []
	for implant in ImplantCatalog.list(_anatomy().get("cybernetics", [])):
		if str(implant.zone) == zone_id:
			out.append(implant)
	return out


## Real condition, from the real snapshot when there is one. The seeded cast
## carries described wounds rather than simulated zones, so those are read too -
## a file that says "missing left eye" should inspect as a damaged head.
func _condition_of(part: Dictionary) -> float:
	var anatomy: Dictionary = _anatomy()
	var kind := str(part.get("kind", ""))
	var part_zone := str(part.get("zone", "torso"))
	if kind == "organ":
		var organs: Dictionary = anatomy.get("organs", {})
		var organ: Dictionary = organs.get(str(part.id), {})
		if not organ.is_empty():
			if bool(organ.get("ruptured", false)):
				return 0.0
			return clampf(float(organ.get("health", 30.0)) / maxf(1.0, float(organ.get("max_health", organ.get("health", 30.0)))), 0.0, 1.0)
		return _wound_penalty(part_zone)
	if kind == "implant":
		return clampf(float(part.get("condition", 0.0)) / maxf(1.0, float(part.get("max_condition", 100.0))), 0.0, 1.0)
	var zones: Dictionary = anatomy.get("zones", {})
	var zone_state: Dictionary = zones.get(part_zone, {})
	if not zone_state.is_empty():
		return clampf(float(zone_state.get("health", 100.0)) / maxf(1.0, float(ZONE_HEALTH.get(part_zone, 100.0))), 0.0, 1.0)
	return _wound_penalty(part_zone)


func _wound_penalty(zone_id: String) -> float:
	var penalty := 0.0
	for wound in subject.get("wounds", []):
		var record := WoundCatalog.resolve(wound)
		if str(record.zone) == zone_id:
			penalty += float(record.severity) * 0.72
	var injury := str(subject.get("injury", ""))
	if injury != "" and injury != "none":
		var injury_record := WoundCatalog.resolve(injury)
		if str(injury_record.zone) == zone_id:
			penalty += float(injury_record.severity) * 0.72
	return clampf(1.0 - penalty, 0.05, 1.0)


## I5.2. Point the inspector at a zone from outside — used when a wound or an
## implant is clicked in the dossier, so following the link lands on the part it
## names rather than on whatever was last selected.
func focus_zone(zone_id: String) -> void:
	if zone_id.is_empty():
		return
	zone = zone_id
	_rebuild_parts()


func selected_part() -> Dictionary:
	if _parts.is_empty():
		return {}
	var selected := hovered_part_index if hovered_part_index >= 0 else part_index
	return _parts[clampi(selected, 0, _parts.size() - 1)]


## One decision record for the robbing loop: the selected body part against the
## player's equivalent. UI and extraction code can consume the same answer.
func comparison() -> Dictionary:
	var theirs := selected_part()
	var player := WorldHistory.subject("player")
	if theirs.is_empty() or player.is_empty() or str(player.get("name", "")) == _subject_id:
		return {}
	var ours := theirs.duplicate(true)
	if str(theirs.kind) == "implant":
		ours = {}
		var player_anatomy: Dictionary = player.get("anatomy_state", player.get("anatomy", {}))
		for implant in ImplantCatalog.list(player_anatomy.get("cybernetics", [])):
			if str(implant.zone) == str(theirs.zone):
				ours = implant.duplicate(true)
				ours["kind"] = "implant"
				break
	var their_condition := _condition_of(theirs)
	var our_condition := 0.0 if ours.is_empty() else _condition_for_subject(ours, player)
	return {
		"theirs": theirs, "ours": ours,
		"their_condition": their_condition, "our_condition": our_condition,
		"delta": their_condition - our_condition,
		"decision": "ROB" if their_condition > our_condition + 0.08 else "KEEP",
	}


func _condition_for_subject(part: Dictionary, target: Dictionary) -> float:
	var prior := subject
	subject = target
	var value := _condition_of(part)
	subject = prior
	return value


# --- input -----------------------------------------------------------------

func handle_key(keycode: int) -> bool:
	match keycode:
		KEY_UP:
			part_index = maxi(0, part_index - 1)
			_begin_lift()
		KEY_DOWN:
			part_index = mini(_parts.size() - 1, part_index + 1)
			_begin_lift()
		KEY_TAB:
			var here := ZONES.find(zone)
			zone = ZONES[(here + 1) % ZONES.size()]
			part_index = 0
			_rebuild_parts()
			_begin_lift()
		_:
			return false
	return true


func handle_click(at: Vector2) -> bool:
	for zone_id in _zone_rects:
		if (_zone_rects[zone_id] as Rect2).has_point(at):
			if zone_id != zone:
				zone = str(zone_id)
				part_index = 0
				_rebuild_parts()
				_begin_lift()
			return true
	for index in _part_rects.size():
		if (_part_rects[index] as Rect2).has_point(at):
			part_index = index
			_begin_lift()
			return true
	return false


## Hover is temporary inspection; click is commitment. Moving away restores the
## pinned part without mutating selection, which keeps mouse and controller use
## compatible rather than making hover secretly act like a click.
func handle_pointer_motion(at: Vector2, relative: Vector2) -> bool:
	if viewer_dragging:
		_viewer.rotate_by(relative)
		return true
	var previous := hovered_part_index
	hovered_part_index = -1
	for index in _part_rects.size():
		if (_part_rects[index] as Rect2).has_point(at):
			hovered_part_index = index
			break
	if hovered_part_index != previous:
		_begin_lift()
		return true
	return false


func handle_mouse_button(at: Vector2, button: int, pressed: bool) -> bool:
	if button == MOUSE_BUTTON_LEFT:
		if not pressed and viewer_dragging:
			viewer_dragging = false
			return true
		if pressed and _stage_rect.has_point(at):
			viewer_dragging = true
			return true
		if pressed:
			return handle_click(at)
	if pressed and _stage_rect.has_point(at):
		if button == MOUSE_BUTTON_WHEEL_UP:
			_viewer.zoom_by(1.12)
			return true
		if button == MOUSE_BUTTON_WHEEL_DOWN:
			_viewer.zoom_by(0.89)
			return true
	return false


## The animation starts from wherever the part actually sits on the diagram, so
## it reads as being drawn out of the body rather than appearing beside it.
func _begin_lift() -> void:
	if not _zone_rects.has(zone):
		# Nothing has been laid out yet, so there is no honest place to travel
		# from. Arrive already seated rather than flying out of the canvas origin.
		lift = 1.0
		return
	lift = 0.0
	_lift_from = _zone_rects[zone]


# --- drawing ---------------------------------------------------------------

func draw_into(canvas: CanvasItem, rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	if subject.is_empty():
		canvas.draw_string(font, rect.position + Vector2(0, 20), "NO BODY ON FILE.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK * Color(1, 1, 1, 0.5))
		return
	CellOutzType.draw_stamped(canvas, rect.position, str(subject.get("name", "")).to_upper(), 21.0, INK, COPPER * Color(1, 1, 1, 0.3), 1.4)
	canvas.draw_string(font, rect.position + Vector2(2, 44), "%s   ·   BLOOD %s" % [str(subject.get("role", "")).to_upper(), str((subject.get("anatomy", {}) as Dictionary).get("blood_type", "unresolved")).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COPPER)

	var diagram := Rect2(rect.position + Vector2(0, 70), Vector2(rect.size.x * 0.26, rect.size.y - 90))
	var list := Rect2(rect.position + Vector2(rect.size.x * 0.29, 70), Vector2(rect.size.x * 0.26, rect.size.y - 90))
	var stage := Rect2(rect.position + Vector2(rect.size.x * 0.58, 62), Vector2(rect.size.x * 0.42, rect.size.y - 80))
	_draw_diagram(canvas, diagram)
	_draw_list(canvas, list)
	_draw_stage(canvas, stage)
	_draw_xray_findings(canvas, Rect2(stage.position + Vector2(0, stage.size.y - 24), Vector2(stage.size.x, 24)))


func _draw_xray_findings(canvas: CanvasItem, rect: Rect2) -> void:
	var findings := xray_findings()
	if findings.is_empty():
		return
	var font := ThemeDB.fallback_font
	var line_y := rect.position.y
	for finding in findings:
		canvas.draw_string(font, Vector2(rect.position.x, line_y), finding, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 10, HOT)
		line_y -= 12.0


func _draw_diagram(canvas: CanvasItem, rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	CellOutzType.draw_text(canvas, rect.position, "THE BODY", 11.0, MOSS, 1.2)
	canvas.draw_line(rect.position + Vector2(0, 17), rect.position + Vector2(rect.size.x, 17), MOSS * Color(1, 1, 1, 0.3), 1.0)
	var field := Rect2(rect.position + Vector2(0, 30), rect.size - Vector2(0, 30))
	Grunge.stain(canvas, field.position + field.size * Vector2(0.74, 0.16), 52.0, 91, Grunge.BILE, 0.07)
	Grunge.stain(canvas, field.position + field.size * Vector2(0.22, 0.88), 44.0, 97, Grunge.RUST, 0.06)
	_silhouette(canvas, field)
	Grunge.scrawl(canvas, field.position + Vector2(field.size.x * 0.62, field.size.y * 0.12), field.size.x * 0.34, 2, hash(_subject_id))
	_zone_rects.clear()
	for zone_id: String in ZONES:
		var shape: Dictionary = ZONE_SHAPE[zone_id]
		var centre := field.position + Vector2(float((shape.at as Vector2).x) * field.size.x, float((shape.at as Vector2).y) * field.size.y)
		var half := Vector2(float((shape.size as Vector2).x) * field.size.x, float((shape.size as Vector2).y) * field.size.y) * 0.5
		_zone_rects[zone_id] = Rect2(centre - half, half * 2.0)
		var health := _wound_penalty(zone_id)
		var zones_state: Dictionary = (subject.get("anatomy", {}) as Dictionary).get("zones", {})
		if zones_state.has(zone_id):
			health = clampf(float((zones_state[zone_id] as Dictionary).get("health", 100.0)) / maxf(1.0, float(ZONE_HEALTH.get(zone_id, 100.0))), 0.0, 1.0)
		var active: bool = zone_id == zone
		var tone := SPORE.lerp(HOT, 1.0 - health)
		canvas.draw_colored_polygon(_zone_polygon(zone_id, centre, half), tone * Color(1, 1, 1, 0.30 if active else 0.16))
		var outline := _zone_polygon(zone_id, centre, half)
		outline.append(outline[0])
		canvas.draw_polyline(outline, tone * Color(1, 1, 1, 0.95 if active else 0.45), 2.0 if active else 1.2)
		if active:
			# A pulled tag rather than a highlight box, so the diagram never
			# becomes a grid of rectangles again.
			var tag := centre + Vector2(half.x + 10.0, 0)
			canvas.draw_line(centre, tag, COPPER, 1.0)
			canvas.draw_circle(tag, 2.5, COPPER)
		if health < 0.99:
			# Shaded in by hand, the way a medical form actually gets marked up,
			# and then it runs - this is a chart that has been handled wet.
			Grunge.hatch(canvas, Rect2(centre - half, half * 2.0), 5.0, Grunge.DRIED, 0.38 * (1.0 - health), hash(zone_id))
			Grunge.run_down(canvas, centre + Vector2(half.x * 0.2, half.y * 0.6), (1.0 - health) * 46.0, hash(zone_id) + 3)
			canvas.draw_string(font, centre + Vector2(-14, half.y + 11), "%d%%" % roundi(health * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 30, 9, tone)
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y + 4), ZONE_LABELS.get(zone, "") + "  ·  TAB CYCLES", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 10, COPPER)


## A single continuous outline under the zones. Without it the six shapes float
## and the diagram reads as a chart of parts instead of as somebody standing
## there - which matters because this whole page is an argument that the body is
## the centrepiece.
func _silhouette(canvas: CanvasItem, field: Rect2) -> void:
	var points := PackedVector2Array()
	var spine: Array = [
		Vector2(0.50, 0.02), Vector2(0.60, 0.09), Vector2(0.63, 0.19),
		Vector2(0.86, 0.28), Vector2(0.90, 0.52), Vector2(0.80, 0.54),
		Vector2(0.72, 0.33), Vector2(0.68, 0.50), Vector2(0.72, 0.98),
		Vector2(0.58, 0.99), Vector2(0.52, 0.62), Vector2(0.48, 0.62),
		Vector2(0.42, 0.99), Vector2(0.28, 0.98), Vector2(0.32, 0.50),
		Vector2(0.28, 0.33), Vector2(0.20, 0.54), Vector2(0.10, 0.52),
		Vector2(0.14, 0.28), Vector2(0.37, 0.19), Vector2(0.40, 0.09),
	]
	for point in spine:
		points.append(field.position + Vector2(float((point as Vector2).x) * field.size.x, float((point as Vector2).y) * field.size.y))
	canvas.draw_colored_polygon(points, INK * Color(1, 1, 1, 0.055))
	var edge := points.duplicate()
	edge.append(points[0])
	canvas.draw_polyline(edge, INK * Color(1, 1, 1, 0.16), 1.0)


## Zones are drawn as tapered organic shapes rather than boxes. `INTERFACE_
## DIRECTION.md` makes that a rule rather than a preference: a body rendered as
## six rectangles is the exact look this whole pass exists to leave behind.
func _zone_polygon(zone_id: String, centre: Vector2, half: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 18
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(zone_id)
	for index in steps:
		var angle := TAU * float(index) / float(steps)
		# Shoulders wider than the waist on the torso; limbs narrower at the far
		# end. A taper is what stops a capsule reading as a pill.
		var taper := 1.0
		var vertical := -cos(angle)
		match zone_id:
			"torso":
				taper = 1.0 + vertical * 0.16
			"left_arm", "right_arm", "left_leg", "right_leg":
				taper = 1.0 + vertical * 0.22
			"head":
				taper = 1.0 - vertical * 0.08
		var wobble := 1.0 + rng.randf_range(-0.045, 0.045)
		points.append(centre + Vector2(sin(angle) * half.x * taper * wobble, -cos(angle) * half.y))
	return points


func _draw_list(canvas: CanvasItem, rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	CellOutzType.draw_text(canvas, rect.position, "PARTS", 11.0, MOSS, 1.2)
	canvas.draw_line(rect.position + Vector2(0, 17), rect.position + Vector2(rect.size.x, 17), MOSS * Color(1, 1, 1, 0.3), 1.0)
	_part_rects.clear()
	var y := rect.position.y + 40.0
	for index in _parts.size():
		var part: Dictionary = _parts[index]
		var pinned := index == part_index
		var preview := index == hovered_part_index
		var active := pinned or preview
		var row := Rect2(Vector2(rect.position.x - 6, y - 14), Vector2(rect.size.x, 30))
		_part_rects.append(row)
		var condition := _condition_of(part)
		var tone := SPORE.lerp(HOT, 1.0 - condition)
		if active:
			canvas.draw_colored_polygon(PackedVector2Array([
				row.position, row.position + Vector2(row.size.x - 12, 0),
				row.position + row.size - Vector2(18, 0), row.position + Vector2(0, row.size.y),
			]), COPPER * Color(1, 1, 1, 0.17))
			canvas.draw_line(row.position, row.position + Vector2(0, row.size.y), HOT, 2.5)
		if pinned:
			canvas.draw_circle(Vector2(row.position.x + row.size.x - 30, y - 4), 2.5, COPPER)
		canvas.draw_string(font, Vector2(rect.position.x + 4, y), str(part.label), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 56, 12, INK if active else INK * Color(1, 1, 1, 0.72))
		canvas.draw_string(font, Vector2(rect.position.x + 4, y + 12), str(part.note).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 56, 9, INK * Color(1, 1, 1, 0.34))
		# A condition pip per row, so the list is scannable without reading it.
		canvas.draw_circle(Vector2(rect.position.x + rect.size.x - 14, y - 4), 4.0, tone * Color(1, 1, 1, 0.9 if active else 0.6))
		y += 32.0


func _draw_stage(canvas: CanvasItem, rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var part := selected_part()
	if part.is_empty():
		return
	var condition := _condition_of(part)
	_viewer.show_part(part, condition)
	var compare := comparison()

	# The frame travels from the zone on the diagram to the stage. At lift 0 it
	# is sitting on the body; at 1 it has arrived. Nothing cuts.
	var target := Rect2(rect.position + Vector2(rect.size.x - 220.0, 24), Vector2(210, 210))
	_stage_rect = target
	var compare_target := Rect2(rect.position + Vector2(2, 65), Vector2(118, 118))
	if not compare.is_empty() and not (compare.ours as Dictionary).is_empty():
		_compare_viewer.show_part(compare.ours, float(compare.our_condition))
		canvas.draw_rect(compare_target, Color(0, 0, 0, 0.30))
		canvas.draw_texture_rect(_compare_viewer.get_texture(), compare_target, false)
		CellOutzType.draw_text(canvas, compare_target.position + Vector2(0, -18), "YOU %03d" % roundi(float(compare.our_condition) * 100.0), 9.0, MOSS, 1.0)
	elif not compare.is_empty():
		CellOutzType.draw_text(canvas, compare_target.position + Vector2(0, 20), "YOU: EMPTY", 9.0, HOT, 1.0)
	if not compare.is_empty():
		CellOutzType.draw_text(canvas, compare_target.position + Vector2(0, compare_target.size.y + 12), "%s  Δ%+03d" % [str(compare.decision), roundi(float(compare.delta) * 100.0)], 10.0, HOT if str(compare.decision) == "ROB" else MOSS, 1.0)
	var eased := 1.0 - pow(1.0 - clampf(lift, 0.0, 1.0), 3.0)
	var frame := Rect2(
		_lift_from.position.lerp(target.position, eased),
		_lift_from.size.lerp(target.size, eased)
	)
	# A thread back to where it came from, which is what sells it as having been
	# pulled out of the body rather than having appeared.
	if eased < 0.999:
		var origin := _lift_from.position + _lift_from.size * 0.5
		canvas.draw_line(origin, frame.position + frame.size * 0.5, COPPER * Color(1, 1, 1, (1.0 - eased) * 0.7), 1.0)
	canvas.draw_rect(frame, Color(0, 0, 0, 0.30))
	canvas.draw_texture_rect(_viewer.get_texture(), frame, false)
	var corner := frame.size.x * 0.18
	var accent := HOT if xray else COPPER
	canvas.draw_polyline(PackedVector2Array([
		frame.position + Vector2(0, corner), frame.position, frame.position + Vector2(corner, 0),
	]), accent * Color(1, 1, 1, 0.8), 1.6)
	canvas.draw_polyline(PackedVector2Array([
		frame.position + frame.size - Vector2(0, corner), frame.position + frame.size, frame.position + frame.size - Vector2(corner, 0),
	]), accent * Color(1, 1, 1, 0.8), 1.6)

	var caption_y := target.position.y + target.size.y + 26.0
	CellOutzType.draw_stamped(canvas, Vector2(rect.position.x, caption_y), str(part.label), 17.0, INK, accent * Color(1, 1, 1, 0.3), 1.2)
	var tone := SPORE.lerp(HOT, 1.0 - condition)
	CellOutzType.draw_text(canvas, Vector2(rect.position.x, caption_y + 30), "CONDITION", 9.0, INK * Color(1, 1, 1, 0.45), 1.0)
	CellOutzType.draw_text(canvas, Vector2(rect.position.x, caption_y + 44), "%03d" % roundi(condition * 100.0), 19.0, tone, 1.0)
	var verdict := "SOUND"
	if condition < 0.15:
		verdict = "DESTROYED"
	elif condition < 0.4:
		verdict = "FAILING"
	elif condition < 0.75:
		verdict = "DAMAGED"
	canvas.draw_string(font, Vector2(rect.position.x + 96, caption_y + 60), verdict, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 110, 13, tone)
	canvas.draw_string(font, Vector2(rect.position.x, caption_y + 84), "IN %s" % str(ZONE_LABELS.get(str(part.zone), "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 10, INK * Color(1, 1, 1, 0.4))
	canvas.draw_string(font, Vector2(rect.position.x, caption_y + 101), "HOVER PREVIEWS  ·  CLICK PINS  ·  DRAG TURNS  ·  WHEEL ZOOMS", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 9, COPPER * Color(1, 1, 1, 0.68))
