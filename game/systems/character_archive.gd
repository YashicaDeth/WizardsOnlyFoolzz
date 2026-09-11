extends Control

## The Living Kinship Web is an original, data-driven rival/friend archive.
## It reads the same persistent subjects as combat, so wounds, rank and memory
## are not decorative menu copy: the dossier changes after encounters.

const BONE := Color("ead4ad")
const COPPER := Color("e85d2b")
const BLOOD := Color("a81716")
const TEAL := Color("35b7a7")
const SPORE := Color("b8d94a")
const VOID := Color("080408")
const INK := Color("180b0d")

var graph_positions := {
	"player": Vector2(0, 0),
	"nix_arden": Vector2(-260, -120),
	"mara_voss": Vector2(275, -95),
	"ashline_wreckers": Vector2(515, 75),
	"rook_sable": Vector2(690, -80),
	"iris_coil": Vector2(735, 130),
	"moth_jerrow": Vector2(-455, 95),
	"vale_nine": Vector2(-185, 205),
	"choir_of_marrow": Vector2(255, 240),
	"doctor_vanta": Vector2(495, 330),
}
var selected_id := "mara_voss"
var zoom := 0.82
var pan := Vector2(70, 255)
var dragging := false
var last_pointer := Vector2.ZERO
var elapsed := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(true)


func open_archive(focus_id: String = "mara_voss") -> void:
	selected_id = focus_id if graph_positions.has(focus_id) else "mara_voss"
	visible = true
	queue_redraw()


func close_archive() -> void:
	visible = false
	dragging = false


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.12)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 0.89)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var hit := _node_at(event.position)
				if not hit.is_empty():
					selected_id = hit
					WorldHistory.record_event("archive_subject_viewed", {"subject_id": hit})
					queue_redraw()
				else:
					dragging = event.position.x < size.x * 0.63
					last_pointer = event.position
			else:
				dragging = false
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			last_pointer = event.position
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		pan += event.position - last_pointer
		last_pointer = event.position
		queue_redraw()
		accept_event()


func _zoom_at(pointer: Vector2, factor: float) -> void:
	if pointer.x > size.x * 0.63:
		return
	var before := (pointer - pan) / zoom
	zoom = clampf(zoom * factor, 0.38, 1.75)
	pan = pointer - before * zoom
	queue_redraw()


func _node_at(pointer: Vector2) -> String:
	for subject_id in graph_positions:
		var graph_position: Vector2 = graph_positions[subject_id]
		var center: Vector2 = pan + graph_position * zoom
		if Rect2(center - Vector2(76, 27), Vector2(152, 54)).has_point(pointer):
			return subject_id
	return ""


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), VOID)
	_draw_scan_field()
	_draw_tree()
	_draw_dossier()
	_draw_header()


func _draw_scan_field() -> void:
	var graph_width := size.x * 0.63
	for x in range(0, int(graph_width), 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), TEAL * Color(1, 1, 1, 0.045), 1)
	for y in range(0, int(size.y), 48):
		draw_line(Vector2(0, y), Vector2(graph_width, y), TEAL * Color(1, 1, 1, 0.045), 1)
	var sweep_y := fmod(elapsed * 38.0, maxf(1.0, size.y))
	draw_rect(Rect2(0, sweep_y, graph_width, 2), TEAL * Color(1, 1, 1, 0.12))
	draw_line(Vector2(graph_width, 0), Vector2(graph_width, size.y), COPPER, 2)


func _draw_tree() -> void:
	var subjects := WorldHistory.all_subjects()
	for from_id in graph_positions:
		var subject: Dictionary = subjects.get(from_id, {})
		var relations: Dictionary = subject.get("relations", {})
		for to_id in relations:
			if not graph_positions.has(to_id):
				continue
			var relation: Dictionary = relations[to_id]
			_draw_relation(from_id, to_id, relation)
	for subject_id in graph_positions:
		_draw_subject_node(subject_id, subjects.get(subject_id, {}))


func _draw_relation(from_id: String, to_id: String, relation: Dictionary) -> void:
	var a: Vector2 = pan + graph_positions[from_id] * zoom
	var b: Vector2 = pan + graph_positions[to_id] * zoom
	var kind := str(relation.get("kind", "known"))
	var strength := absf(float(relation.get("strength", 10)))
	var color := TEAL if kind in ["bond", "ally", "saved"] else BLOOD if kind in ["grudge", "hunts", "enemy"] else COPPER
	var midpoint := (a + b) * 0.5 + Vector2(0, -28)
	draw_polyline(PackedVector2Array([a, midpoint, b]), color * Color(1, 1, 1, 0.38), clampf(1.0 + strength / 35.0, 1.0, 4.0))
	var font := ThemeDB.fallback_font
	draw_string(font, midpoint + Vector2(-35, -5), kind.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 70, 9, color)


func _draw_subject_node(subject_id: String, subject: Dictionary) -> void:
	var center: Vector2 = pan + graph_positions[subject_id] * zoom
	var node_rect := Rect2(center - Vector2(76, 27), Vector2(152, 54))
	var kind := str(subject.get("kind", "person"))
	var active := subject_id == selected_id
	var edge := SPORE if kind == "faction" else COPPER
	if active:
		draw_rect(node_rect.grow(5), edge * Color(1, 1, 1, 0.16))
	draw_rect(node_rect, INK * Color(1, 1, 1, 0.95))
	draw_rect(node_rect, edge if active else edge * Color(1, 1, 1, 0.58), false, 2)
	_draw_face(center + Vector2(-54, 0), subject_id, edge)
	var font := ThemeDB.fallback_font
	var display_name := str(subject.get("name", subject_id.replace("_", " "))).to_upper()
	draw_string(font, center + Vector2(-30, -6), display_name, HORIZONTAL_ALIGNMENT_LEFT, 100, 11, BONE)
	var subtitle := str(subject.get("role", subject.get("kind", "unknown"))).to_upper()
	draw_string(font, center + Vector2(-30, 12), subtitle, HORIZONTAL_ALIGNMENT_LEFT, 100, 8, edge)


func _draw_face(center: Vector2, seed_text: String, tint: Color) -> void:
	var variant: int = absi(seed_text.hash())
	draw_circle(center, 17, Color("211316"))
	draw_arc(center, 17, 0, TAU, 20, tint * Color(1, 1, 1, 0.8), 1.5)
	var eye_y := -3.0 + float(variant % 3)
	draw_line(center + Vector2(-8, eye_y), center + Vector2(-2, eye_y - 1), BONE, 2)
	draw_line(center + Vector2(3, eye_y - 1), center + Vector2(9, eye_y), tint, 2)
	draw_line(center + Vector2(0, 0), center + Vector2(-1, 7), BONE * Color(1, 1, 1, 0.5), 1)
	draw_arc(center + Vector2(0, 6), 7, 0.3, PI - 0.3, 8, BLOOD, 1)
	if variant % 2 == 0:
		draw_line(center + Vector2(-13, -11), center + Vector2(10, 13), tint, 1)


func _draw_dossier() -> void:
	var subjects := WorldHistory.all_subjects()
	var subject: Dictionary = subjects.get(selected_id, {})
	var left := size.x * 0.655
	var panel_rect := Rect2(left, 74, size.x - left - 24, size.y - 98)
	draw_rect(panel_rect, Color("10070b") * Color(1, 1, 1, 0.97))
	draw_rect(panel_rect, COPPER * Color(1, 1, 1, 0.75), false, 2)
	var font := ThemeDB.fallback_font
	var name := str(subject.get("name", selected_id.replace("_", " "))).to_upper()
	draw_string(font, Vector2(left + 22, 108), name, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44, 20, BONE)
	draw_string(font, Vector2(left + 22, 132), str(subject.get("role", "UNRESOLVED")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44, 11, COPPER)
	if str(subject.get("kind", "person")) == "faction":
		_draw_faction_dossier(subject, panel_rect)
	else:
		_draw_person_dossier(subject, panel_rect)


func _draw_person_dossier(subject: Dictionary, panel_rect: Rect2) -> void:
	var left := panel_rect.position.x
	var top := panel_rect.position.y
	var slice_width := (panel_rect.size.x - 58) * 0.5
	var body_rect := Rect2(left + 18, top + 82, slice_width, 285)
	var xray_rect := Rect2(body_rect.end.x + 22, top + 82, slice_width, 285)
	draw_rect(body_rect, Color("1b0c0d"))
	draw_rect(xray_rect, Color("071516"))
	draw_rect(body_rect, COPPER * Color(1, 1, 1, 0.35), false, 1)
	draw_rect(xray_rect, TEAL * Color(1, 1, 1, 0.45), false, 1)
	var font := ThemeDB.fallback_font
	draw_string(font, body_rect.position + Vector2(10, 19), "VESSEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COPPER)
	draw_string(font, xray_rect.position + Vector2(10, 19), "DEEP XRAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEAL)
	_draw_body_slice(body_rect, false, subject)
	_draw_body_slice(xray_rect, true, subject)
	var elo := int(subject.get("elo", 0))
	var grudge := int(subject.get("grudge", 0))
	var status := str(subject.get("status", "unknown")).to_upper()
	var faction := str(subject.get("faction", "Unaffiliated"))
	var info_y := body_rect.end.y + 30
	draw_string(font, Vector2(left + 22, info_y), "ELO %04d   %s   GRUDGE %03d" % [elo, _rank_title(elo), grudge], HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44, 12, BONE)
	draw_string(font, Vector2(left + 22, info_y + 22), "FACTION // %s" % faction.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44, 10, SPORE)
	draw_string(font, Vector2(left + 22, info_y + 43), "STATUS // %s   LASTING MEMORY" % status, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COPPER)
	_draw_wrapped(str(subject.get("memory", "No reliable memory recovered.")), Vector2(left + 22, info_y + 62), panel_rect.size.x - 44, 11, BONE * Color(1, 1, 1, 0.72), 3)


func _rank_title(elo: int) -> String:
	if elo >= 1450:
		return "RANK: BLACK CROWN"
	if elo >= 1300:
		return "RANK: DREAD"
	if elo >= 1150:
		return "RANK: HUNTER"
	if elo >= 1000:
		return "RANK: PROVEN"
	return "RANK: STRAY"


func _draw_body_slice(rect: Rect2, xray: bool, subject: Dictionary) -> void:
	var center := Vector2(rect.get_center().x, rect.position.y + 145)
	var tissue := TEAL * Color(1, 1, 1, 0.18) if xray else Color("6c2823")
	var bone := TEAL * Color(1, 1, 1, 0.75) if xray else Color("251315")
	draw_circle(center + Vector2(0, -84), 25, tissue)
	draw_rect(Rect2(center + Vector2(-27, -56), Vector2(54, 100)), tissue)
	draw_line(center + Vector2(-24, -45), center + Vector2(-47, 34), tissue, 17)
	draw_line(center + Vector2(24, -45), center + Vector2(47, 34), tissue, 17)
	draw_line(center + Vector2(-16, 40), center + Vector2(-23, 103), tissue, 19)
	draw_line(center + Vector2(16, 40), center + Vector2(23, 103), tissue, 19)
	if xray:
		draw_line(center + Vector2(0, -55), center + Vector2(0, 46), bone, 4)
		for rib in 5:
			var y := -38.0 + rib * 14.0
			draw_arc(center + Vector2(0, y), 23 - rib * 1.5, 0.25, PI - 0.25, 14, bone, 2)
		draw_circle(center + Vector2(-10, -22), 12, BLOOD * Color(1, 1, 1, 0.72))
		draw_circle(center + Vector2(12, -23), 16, SPORE * Color(1, 1, 1, 0.5))
		draw_colored_polygon(PackedVector2Array([center + Vector2(-16, 3), center + Vector2(12, 1), center + Vector2(17, 27), center + Vector2(-10, 33)]), Color("8a4428"))
		var anatomy: Dictionary = subject.get("anatomy", {})
		var cybernetics: Array = anatomy.get("cybernetics", [])
		for index in cybernetics.size():
			var module_pos := center + Vector2(30 if index % 2 == 0 else -30, -30 + index * 31)
			draw_rect(Rect2(module_pos - Vector2(8, 6), Vector2(16, 12)), TEAL)
			draw_line(module_pos, center, TEAL * Color(1, 1, 1, 0.45), 1)
		_draw_tree_alignment(rect, subject)
	else:
		var wounds: Array = subject.get("wounds", [])
		for index in wounds.size():
			var wound_pos := center + Vector2(-18 + index * 15, -20 + index * 26)
			draw_line(wound_pos - Vector2(7, 7), wound_pos + Vector2(7, 7), BLOOD, 3)
			draw_line(wound_pos + Vector2(7, -7), wound_pos - Vector2(7, 7), BLOOD, 2)


## The Deep X-ray doubles as an "as above, so below" reading: the same scan
## that shows organs and cybernetics also shows where the subject currently
## sits on the vertical Tree, so the body view and the metaphysical view are
## one instrument rather than two unrelated panels.
func _draw_tree_alignment(rect: Rect2, subject: Dictionary) -> void:
	var axis_x := rect.end.x - 15
	var top := rect.position.y + 16
	var bottom := rect.end.y - 12
	draw_line(Vector2(axis_x, top), Vector2(axis_x, bottom), TEAL * Color(1, 1, 1, 0.4), 2)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(axis_x - 58, top - 3), "ASCENT", HORIZONTAL_ALIGNMENT_RIGHT, 52, 7, SPORE * Color(1, 1, 1, 0.75))
	draw_string(font, Vector2(axis_x - 58, (top + bottom) * 0.5 + 3), "LIMBO", HORIZONTAL_ALIGNMENT_RIGHT, 52, 7, BONE * Color(1, 1, 1, 0.5))
	draw_string(font, Vector2(axis_x - 58, bottom + 10), "DESCENT", HORIZONTAL_ALIGNMENT_RIGHT, 52, 7, BLOOD * Color(1, 1, 1, 0.75))
	var alignment := WorldHistory.tree_alignment(subject)
	var marker_y := lerpf(top, bottom, (1.0 - alignment) * 0.5)
	var marker_color := SPORE if alignment > 0.2 else (BLOOD if alignment < -0.2 else BONE)
	draw_circle(Vector2(axis_x, marker_y), 7.0, marker_color * Color(1, 1, 1, 0.28))
	draw_circle(Vector2(axis_x, marker_y), 4.0, marker_color)
	var descriptor := WorldHistory.tree_descriptor(subject)
	if not descriptor.is_empty():
		draw_string(font, Vector2(axis_x - 58, marker_y - 11), descriptor.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, 52, 8, marker_color)


func _draw_faction_dossier(subject: Dictionary, panel_rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var center := panel_rect.get_center() + Vector2(0, -55)
	for ring in 6:
		draw_arc(center, 38.0 + ring * 20, elapsed * 0.08 * (1 if ring % 2 == 0 else -1), TAU, 48, SPORE * Color(1, 1, 1, 0.12 + ring * 0.03), 2)
	for spoke in 12:
		var angle := TAU * spoke / 12.0
		draw_line(center + Vector2.from_angle(angle) * 38, center + Vector2.from_angle(angle) * 132, TEAL * Color(1, 1, 1, 0.22), 1)
	draw_circle(center, 28 + sin(elapsed * 2.0) * 3, BLOOD * Color(1, 1, 1, 0.55))
	var info_y := panel_rect.position.y + 405
	draw_string(font, Vector2(panel_rect.position.x + 22, info_y), "DOCTRINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COPPER)
	_draw_wrapped(str(subject.get("doctrine", "No doctrine recovered.")), Vector2(panel_rect.position.x + 22, info_y + 23), panel_rect.size.x - 44, 12, BONE, 4)
	draw_string(font, Vector2(panel_rect.position.x + 22, info_y + 105), "THREAT %s   TERRITORY %s" % [str(subject.get("threat", "?")), str(subject.get("territory", "unknown")).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44, 11, SPORE)


func _draw_wrapped(value: String, at: Vector2, width: float, font_size: int, color: Color, max_lines: int) -> void:
	var font := ThemeDB.fallback_font
	var words := value.split(" ")
	var line := ""
	var line_index := 0
	for word in words:
		var candidate := word if line.is_empty() else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not line.is_empty():
			draw_string(font, at + Vector2(0, line_index * (font_size + 5)), line, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
			line_index += 1
			line = word
			if line_index >= max_lines:
				return
		else:
			line = candidate
	if line_index < max_lines and not line.is_empty():
		draw_string(font, at + Vector2(0, line_index * (font_size + 5)), line, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)


func _draw_header() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, size.x, 58), Color("13080a"))
	draw_line(Vector2(0, 58), Vector2(size.x, 58), COPPER, 2)
	draw_string(font, Vector2(28, 35), "THE LIVING KINSHIP WEB", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, BONE)
	draw_string(font, Vector2(345, 34), "ASHBLOOM EXPANSE // BLOOD · BOND · COMMAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEAL)
	draw_string(font, Vector2(size.x - 390, 34), "WHEEL ZOOM   DRAG PAN   CLICK OPEN   T CLOSE", HORIZONTAL_ALIGNMENT_LEFT, 360, 10, BONE * Color(1, 1, 1, 0.6))
