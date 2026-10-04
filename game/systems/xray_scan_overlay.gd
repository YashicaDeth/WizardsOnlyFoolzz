class_name XrayScanOverlay
extends Control

## The X-ray's pre-fight read of one body (lab-48). Greg: *"X-ray is how you
## PEEP someone's cybernetics before deciding to fight them. It shows: where
## implants and armour plates are; what each implant does (short tags); how
## healthy their organs are and what is already damaged; their loot value."*
##
## Everything drawn comes from `OrganSystem.scan()`, so the screen and the
## test read the same numbers. Tags hang off the hardware where it actually
## sits in the body (projected through the camera each frame); organ health
## and the estimate are a column at the side. Same palette and type as
## `VatsOverlay`, so the aimed X-ray and the scan read as one instrument.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const BONE := Color("e6d4ac")
const HOT := Color("a8281a")
const BRASS := Color("b0552a")
const SCAN := Color("35b7a7")
const SPARK := Color("ffcf6a")
const SOOT := Color(0.05, 0.036, 0.028, 0.82)
const STATE_TONES := {"OK": SCAN, "BRUISED": BRASS, "DAMAGED": Color("d06a2a"), "RUPTURED": HOT, "TAKEN": Color(0.5, 0.45, 0.4)}

## Stroked type is not cheap: redrawn every frame the panel cost the lab ~60
## fps. The tags follow the body at `TAG_HZ`; the column redraws only when
## what it says changes.
const TAG_HZ := 20.0
const SCAN_EVERY := 0.2

var rig: BaselineHuman
var camera: Camera3D
var report: Dictionary = {}
var _clock := 0.0
var _tag_clock := 0.0
var _scan_clock := 0.0
var _column: Control
var _column_hash := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column = Control.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column.draw.connect(_draw_column)


## Point the scan at `target` (null clears it).
func show_scan(target: BaselineHuman, eye: Camera3D) -> void:
	rig = target
	camera = eye
	report = OrganSystem.scan(target) if target != null else {}
	visible = target != null
	_column_hash = 0
	_refresh_column()
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if rig == null:
		return
	if not is_instance_valid(rig):
		show_scan(null, camera)
		return
	_scan_clock -= delta
	if _scan_clock <= 0.0:
		_scan_clock = SCAN_EVERY
		report = OrganSystem.scan(rig)
		_refresh_column()
	_tag_clock -= delta
	if _tag_clock <= 0.0:
		_tag_clock = 1.0 / TAG_HZ
		queue_redraw()


func _refresh_column() -> void:
	if _column == null:
		return
	var key := hash([report.get("organs", []), report.get("implants", []).size(), (report.get("plates", []) as Array).size(), report.get("value", 0)])
	if key != _column_hash:
		_column_hash = key
		_column.queue_redraw()


func _draw() -> void:
	if report.is_empty() or rig == null or not is_instance_valid(rig) or camera == null:
		return
	var implants: Array = report.get("implants", [])
	var side := 0
	for entry: Dictionary in implants:
		var at3 := _where(entry)
		if camera.is_position_behind(at3):
			continue
		var at := camera.unproject_position(at3)
		var shorted := bool(entry.get("shorted", false))
		var burnt := bool(entry.get("burnt", false))
		var tone: Color = SPARK if shorted else (HOT if burnt else (BRASS if str(entry.role) == "plate" else SCAN))
		if shorted and fmod(_clock * 9.0, 1.0) < 0.35:
			tone = BONE
		var plated := str(entry.role) == "plate"
		if plated:
			draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), tone)
		else:
			draw_arc(at, 6.0, 0.0, TAU, 14, tone, 2.0)
		# Alternate the tags left and right of the body so they do not stack.
		var dir := -1.0 if side % 2 == 0 else 1.0
		side += 1
		var elbow := at + Vector2(dir * 46.0, -18.0 - float(side / 2) * 22.0)
		var tag := str(entry.tag)
		var detail := "%d%%" % roundi(float(entry.condition) * 100.0)
		if shorted:
			detail += " SHORTED"
		elif burnt:
			detail = "BURNT OUT"
		if plated:
			detail += " PLATE"
		var tag_w := CellOutzType.width(tag, 11.0, 1.0)
		var det_w := CellOutzType.width(detail, 8.0, 1.0)
		var box_w := maxf(tag_w, det_w) + 12.0
		var box_at := elbow + Vector2(0.0 if dir > 0.0 else -box_w, -14.0)
		draw_line(at, elbow, tone * Color(1, 1, 1, 0.8), 1.4)
		draw_rect(Rect2(box_at, Vector2(box_w, 30.0)), SOOT)
		draw_rect(Rect2(box_at, Vector2(box_w, 30.0)), tone * Color(1, 1, 1, 0.7), false, 1.0)
		CellOutzType.draw_text(self, box_at + Vector2(6, 4), tag, 11.0, tone, 1.0)
		CellOutzType.draw_text(self, box_at + Vector2(6, 19), detail, 8.0, BONE * Color(1, 1, 1, 0.85), 1.0)
	# Damaged organs get a mark where they are, so "what is already damaged"
	# is on the body as well as in the column.
	for organ: Dictionary in report.get("organs", []):
		if str(organ.state) in ["OK", "TAKEN"]:
			continue
		var node := rig.organ_parts.get(str(organ.id)) as Node3D
		if node == null or not node.is_inside_tree() or camera.is_position_behind(node.global_position):
			continue
		var at := camera.unproject_position(node.global_position)
		var tone: Color = STATE_TONES.get(str(organ.state), HOT)
		draw_arc(at, 9.0 + sin(_clock * 5.0) * 1.5, 0.0, TAU, 16, tone, 1.6)


func _draw_column() -> void:
	if report.is_empty():
		return
	var organs: Array = report.get("organs", [])
	var at := Vector2(_column.size.x - 250.0, 110.0)
	var height := 64.0 + organs.size() * 17.0 + 22.0
	_column.draw_rect(Rect2(at - Vector2(12, 12), Vector2(236, height)), SOOT)
	_column.draw_rect(Rect2(at - Vector2(12, 12), Vector2(236, height)), SCAN * Color(1, 1, 1, 0.5), false, 1.0)
	CellOutzType.draw_text(_column, at, "XRAY // SCAN", 13.0, HOT, 2.0)
	var implants: Array = report.get("implants", [])
	CellOutzType.draw_text(_column, at + Vector2(0, 22), "%d IMPLANTS  %d PLATES" % [implants.size(), (report.get("plates", []) as Array).size()], 9.0, BONE, 1.0)
	var y := 46.0
	for organ: Dictionary in organs:
		var tone: Color = STATE_TONES.get(str(organ.state), BONE)
		CellOutzType.draw_text(_column, at + Vector2(0, y), str(organ.label), 9.0, BONE * Color(1, 1, 1, 0.85), 0.8)
		var bar := Rect2(at + Vector2(104, y + 1), Vector2(60, 7))
		_column.draw_rect(bar, Color(0, 0, 0, 0.6))
		_column.draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(organ.health), bar.size.y)), tone)
		CellOutzType.draw_text(_column, at + Vector2(170, y), str(organ.state), 8.0, tone, 0.8)
		y += 17.0
	CellOutzType.draw_text(_column, at + Vector2(0, y + 6), "LOOT EST %d SCRIP" % int(report.get("value", 0)), 11.0, SPARK, 1.0)


func _where(entry: Dictionary) -> Vector3:
	var zone_node := rig.parts.get(str(entry.zone)) as Node3D
	if zone_node == null or not zone_node.is_inside_tree():
		return rig.global_position + Vector3.UP
	var visual := zone_node.get_node_or_null("Implant_%s" % str(entry.site)) as Node3D
	if visual == null:
		visual = zone_node.get_node_or_null("InstalledHardware") as Node3D
	return visual.global_position if visual != null and visual.is_inside_tree() else zone_node.global_position
