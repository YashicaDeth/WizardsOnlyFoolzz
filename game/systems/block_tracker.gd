class_name BlockTracker
extends Control

const CellOutzType := preload("res://systems/celloutz_type.gd")

## Blob tracking over the fight, in the TouchDesigner register (Greg,
## 2026-09-24): thin boxes that lock onto things, a tag, a number, lines
## between centroids. Presentation only -- nothing here decides a hit or
## blocks a view; boxes are hairlines and the tags sit outside what they mark.
##
##   hits       a box snaps onto the body part you struck: zone, damage, type
##   awareness  faint amber boxes on every enemy that has seen you, linked
##   targets    the Black Mirror depth camera (v02-51): a box with a tag and
##              a range on every body and object the sensor resolves, found
##              by distance, not by light, so they read through the dark
##
## The player's own wounds and mind state are tracked on the Nerve Rig.

const HIT_LIFE := 0.9
const SNAP := 0.12
const MAX_HITS := 8
const MAX_WATCHERS := 6
const HIT_INK := Color("f2ece4")
const HIT_HOT := Color("ff4a3a")
const WATCH_INK := Color(1.0, 0.72, 0.28, 0.55)
const MAX_TARGETS := 8
const TARGET_BODY := Color("ff4a3a")
const TARGET_OBJECT := Color("e8c9a0")
## Beyond this the depth camera's own ramp is black, so no box either.
const TARGET_RANGE := 30.0

var camera: Camera3D
var hits: Array = []
var watchers: Array = []
## Depth-camera targets: {at: Vector3 centre, half: Vector3, tag: String,
## kind: "body" | "object", occluded: bool}. Set every frame by the camera.
var targets: Array = []
var _target_rects: Array = []
var clock := 0.0
var _serial := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func report_hit(at: Vector3, zone: String, damage: float, kind: String) -> void:
	_serial += 1
	hits.append({"at": at, "zone": zone, "damage": damage, "kind": kind, "life": HIT_LIFE, "id": _serial % 100})
	while hits.size() > MAX_HITS:
		hits.pop_front()


## Every frame: where the enemies who have seen you are, and how sure they are.
func watch(entries: Array) -> void:
	watchers = entries.slice(0, MAX_WATCHERS)


## Every frame from the depth camera: what it resolves. Kept nearest first and
## capped, so the busiest room still shows a handful of readable tags.
func track(entries: Array) -> void:
	var kept: Array = []
	for entry: Dictionary in entries:
		if camera == null or not is_instance_valid(camera):
			break
		var at: Vector3 = entry.get("at", Vector3.ZERO)
		var distance := camera.global_position.distance_to(at)
		if distance > TARGET_RANGE or camera.is_position_behind(at):
			continue
		var copy := entry.duplicate()
		copy["distance"] = distance
		kept.append(copy)
	kept.sort_custom(func(a, b): return float(a.distance) < float(b.distance))
	targets = kept.slice(0, MAX_TARGETS)
	_target_rects = []
	for entry: Dictionary in targets:
		_target_rects.append(target_rect(entry))


## The screen box a target's bounds project to. Shared with the depth shader's
## track mask, so the hot points and the drawn box are one rectangle.
func target_rect(entry: Dictionary) -> Rect2:
	var at: Vector3 = entry.get("at", Vector3.ZERO)
	var half: Vector3 = entry.get("half", Vector3(0.3, 0.9, 0.3))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner in 8:
		var offset := Vector3(half.x if corner & 1 else -half.x, half.y if corner & 2 else -half.y, half.z if corner & 4 else -half.z)
		var point := at + offset
		# A box half behind the lens projects to nonsense: no box at all.
		if camera.is_position_behind(point):
			return Rect2()
		var screen := camera.unproject_position(point)
		lo = Vector2(minf(lo.x, screen.x), minf(lo.y, screen.y))
		hi = Vector2(maxf(hi.x, screen.x), maxf(hi.y, screen.y))
	if lo.x == INF:
		return Rect2()
	return Rect2(lo, hi - lo)


func target_rects() -> Array:
	return _target_rects


func _process(delta: float) -> void:
	clock += delta
	for hit in hits:
		hit.life -= delta
	hits = hits.filter(func(hit): return float(hit.life) > 0.0)
	queue_redraw()


func _draw() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var font := ThemeDB.fallback_font
	_draw_targets()
	# Awareness first, faint, so a hit box always reads over it.
	var centres: Array[Vector2] = []
	for watcher in watchers:
		var at: Vector3 = watcher.at
		if camera.is_position_behind(at):
			continue
		var centre := camera.unproject_position(at)
		var half := Vector2(26, 52) * clampf(8.0 / maxf(camera.global_position.distance_to(at), 1.0), 0.35, 1.6)
		var rect := Rect2(centre - half, half * 2.0)
		_corners(rect, WATCH_INK, 1.0, 8.0)
		if not bool(watcher.get("hide_tag", false)):
			var tag := "SEEN %02d%%" % roundi(float(watcher.get("certainty", 1.0)) * 100.0)
			draw_string(font, rect.position + Vector2(0, -4), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, WATCH_INK)
		centres.append(centre)
	for index in range(1, centres.size()):
		draw_line(centres[index - 1], centres[index], WATCH_INK * Color(1, 1, 1, 0.45), 1.0)
	for hit in hits:
		var at: Vector3 = hit.at
		if camera.is_position_behind(at):
			continue
		var centre := camera.unproject_position(at)
		var age := HIT_LIFE - float(hit.life)
		# Snaps in from wide, like a tracker acquiring, then holds and fades.
		var snap := clampf(age / SNAP, 0.0, 1.0)
		var size := lerpf(120.0, 44.0, ease(snap, 0.4)) * clampf(6.0 / maxf(camera.global_position.distance_to(at), 1.0), 0.45, 1.5)
		var fade := clampf(float(hit.life) / 0.35, 0.0, 1.0)
		var rect := Rect2(centre - Vector2(size, size) * 0.5, Vector2(size, size))
		var ink := HIT_INK * Color(1, 1, 1, fade)
		draw_rect(rect, ink, false, 1.0)
		_corners(rect.grow(3.0), HIT_HOT * Color(1, 1, 1, fade), 2.0, 7.0)
		draw_line(centre - Vector2(5, 0), centre + Vector2(5, 0), ink, 1.0)
		draw_line(centre - Vector2(0, 5), centre + Vector2(0, 5), ink, 1.0)
		var label := "#%02d  %s  -%d  %s" % [int(hit.id), str(hit.zone).to_upper().replace("_", " "), roundi(float(hit.damage)), str(hit.kind).to_upper()]
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var tag_at := rect.position + Vector2(rect.size.x + 6, 2)
		draw_rect(Rect2(tag_at - Vector2(2, 11), label_size + Vector2(6, 4)), HIT_HOT * Color(1, 1, 1, 0.85 * fade))
		draw_string(font, tag_at + Vector2(1, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.02, 0.02, fade))


## TouchDesigner blob-track register: a hairline box, heavier corner ticks, a
## centroid cross, a numbered tag outside the box and a link line between body
## centroids. Occluded targets (the sensor saw the edge of them) draw dashed.
func _draw_targets() -> void:
	var body_centres: Array[Vector2] = []
	for index in targets.size():
		var entry: Dictionary = targets[index]
		var rect: Rect2 = _target_rects[index] if index < _target_rects.size() else Rect2()
		if rect.size.x < 2.0 or rect.size.y < 2.0:
			continue
		var body := str(entry.get("kind", "object")) == "body"
		var ink: Color = TARGET_BODY if body else TARGET_OBJECT
		var lock := clampf(fmod(clock * 1.7 + float(index) * 0.37, 1.0), 0.0, 1.0)
		var occluded := bool(entry.get("occluded", false))
		if occluded:
			_dashed_rect(rect, ink * Color(1, 1, 1, 0.55), 6.0)
		else:
			draw_rect(rect, ink * Color(1, 1, 1, 0.75), false, 1.0)
		_corners(rect.grow(3.0), ink, 2.0, minf(12.0, rect.size.x * 0.3))
		var centre := rect.get_center()
		draw_line(centre - Vector2(6, 0), centre + Vector2(6, 0), ink * Color(1, 1, 1, 0.7), 1.0)
		draw_line(centre - Vector2(0, 6), centre + Vector2(0, 6), ink * Color(1, 1, 1, 0.7), 1.0)
		# A tracking bar that sweeps across the top edge while locked.
		draw_line(rect.position + Vector2(rect.size.x * lock, -1), rect.position + Vector2(minf(rect.size.x, rect.size.x * lock + 14.0), -1), ink, 2.0)
		var tag := "%02d %s  %.1fM" % [index + 1, str(entry.get("tag", "OBJECT")).to_upper(), float(entry.get("distance", 0.0))]
		var tag_size := CellOutzType.string_size_compat(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var tag_at := Vector2(rect.position.x, rect.position.y - 7.0)
		if tag_at.y < 18.0:
			tag_at.y = rect.end.y + tag_size.y + 4.0
		draw_rect(Rect2(tag_at - Vector2(3, tag_size.y - 1), tag_size + Vector2(6, 4)), (ink * Color(1, 1, 1, 0.9)) if body else Color(0.02, 0.02, 0.025, 0.85))
		CellOutzType.draw_string_compat(self, tag_at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.02, 0.02) if body else ink)
		if body:
			body_centres.append(centre)
	for index in range(1, body_centres.size()):
		draw_line(body_centres[index - 1], body_centres[index], TARGET_BODY * Color(1, 1, 1, 0.35), 1.0)


func _dashed_rect(rect: Rect2, ink: Color, dash: float) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for side in 4:
		draw_dashed_line(corners[side], corners[(side + 1) % 4], ink, 1.0, dash)


func _corners(rect: Rect2, ink: Color, width: float, arm: float) -> void:
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1.0 if corner.x <= rect.get_center().x else -1.0
		var sy := 1.0 if corner.y <= rect.get_center().y else -1.0
		draw_line(corner, corner + Vector2(arm * sx, 0), ink, width)
		draw_line(corner, corner + Vector2(0, arm * sy), ink, width)
