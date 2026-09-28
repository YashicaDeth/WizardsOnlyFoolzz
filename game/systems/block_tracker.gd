class_name BlockTracker
extends Control

## Blob tracking over the fight, in the TouchDesigner register (Greg,
## 2026-09-24): thin boxes that lock onto things, a tag, a number, lines
## between centroids. Presentation only -- nothing here decides a hit or
## blocks a view; boxes are hairlines and the tags sit outside what they mark.
##
##   hits       a box snaps onto the body part you struck: zone, damage, type
##   awareness  faint amber boxes on every enemy that has seen you, linked
##
## The player's own wounds and mind state are tracked on the Nerve Rig.

const HIT_LIFE := 0.9
const SNAP := 0.12
const MAX_HITS := 8
const MAX_WATCHERS := 6
const HIT_INK := Color("f2ece4")
const HIT_HOT := Color("ff4a3a")
const WATCH_INK := Color(1.0, 0.72, 0.28, 0.55)

var camera: Camera3D
var hits: Array = []
var watchers: Array = []
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


func _corners(rect: Rect2, ink: Color, width: float, arm: float) -> void:
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1.0 if corner.x <= rect.get_center().x else -1.0
		var sy := 1.0 if corner.y <= rect.get_center().y else -1.0
		draw_line(corner, corner + Vector2(arm * sx, 0), ink, width)
		draw_line(corner, corner + Vector2(0, arm * sy), ink, width)
