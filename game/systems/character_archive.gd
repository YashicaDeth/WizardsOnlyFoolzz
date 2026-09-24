extends Control

## The derby captain is generated per save (`cast_names.gd`), so this panel
## resolves who it is rather than defaulting to a name written in here.
const CAST := preload("res://systems/cast_names.gd")

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
	"ashline_wreckers": Vector2(515, 75),
	"rook_sable": Vector2(690, -80),
	"iris_coil": Vector2(735, 130),
	"moth_jerrow": Vector2(-455, 95),
	"vale_nine": Vector2(-185, 205),
	"choir_of_marrow": Vector2(255, 240),
	"doctor_vanta": Vector2(495, 330),
}
var selected_id := "derby_captain"
var zoom := 0.82
var pan := Vector2(70, 255)
var dragging := false
var last_pointer := Vector2.ZERO
var elapsed := 0.0


const ACID := Color("9bf01a")
const MAGENTA := Color("ff2fa0")
const BILE := Color("b8a12a")
const BRUISE := Color("6a2d6e")
const ARTERIAL := Color("c81f16")

var tissue_texture: ImageTexture
var interference_texture: ImageTexture
var divider_ratio := 0.46
var dragging_divider := false
var body_view_rect := Rect2()
var clip_active := false
var clip_min_x := 0.0
var clip_max_x := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# Polygon UVs above 1.0 only repeat when the canvas item allows it, and the
	# repetition is the whole point: tiled tissue reads as meat, a single
	# stretched gradient reads as a diagram.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tissue_texture = _build_tissue_texture()
	interference_texture = _build_interference_texture()
	set_process(true)


## Cellular noise at tile scale. Generated rather than authored so the dossier
## carries no external texture dependency and still reads as wet organic matter
## instead of flat vector shapes.
func _build_tissue_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	noise.cellular_jitter = 1.0
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	var vein := FastNoiseLite.new()
	vein.noise_type = FastNoiseLite.TYPE_SIMPLEX
	vein.frequency = 0.021
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var cell := absf(noise.get_noise_2d(float(x), float(y)))
			var streak := absf(vein.get_noise_2d(float(x) * 2.0, float(y)))
			var wet := clampf(cell * 1.35 + streak * 0.4, 0.0, 1.0)
			# Darker gaps between cells become the membrane lines.
			var membrane := smoothstep(0.72, 0.98, cell)
			var value := clampf(wet - membrane * 0.55, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.55 + value * 0.45, 0.2 + value * 0.35, 0.2 + value * 0.3, 1.0))
	return ImageTexture.create_from_image(image)


func _build_interference_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var scan := 0.5 + 0.5 * sin(float(y) * 1.6)
			var hashed := sin(float(x * 71 + y * 131)) * 43758.5453
			var speckle := hashed - floorf(hashed)
			var value := clampf(scan * 0.45 + speckle * 0.55, 0.0, 1.0)
			image.set_pixel(x, y, Color(value, value, value, 0.5 + value * 0.5))
	return ImageTexture.create_from_image(image)


func _tiled_polygon(points: PackedVector2Array, color: Color, texture: Texture2D, tile_px: float) -> void:
	for piece in _clip(points):
		var uvs := PackedVector2Array()
		for point in piece:
			uvs.append(point / tile_px)
		draw_colored_polygon(piece, color, uvs, texture)


## Half-plane clip used by the scan divider. Returns the polygon untouched when
## no clip is active, so the same drawing code serves both layers.
func _clip(points: PackedVector2Array) -> Array:
	if not clip_active:
		return [points]
	var bounds := PackedVector2Array([
		Vector2(clip_min_x, -4000.0), Vector2(clip_max_x, -4000.0),
		Vector2(clip_max_x, 4000.0), Vector2(clip_min_x, 4000.0),
	])
	return Geometry2D.intersect_polygons(points, bounds)


func _clipped_disc(center: Vector2, radius: float, color: Color) -> void:
	if not clip_active:
		draw_circle(center, radius, color)
		return
	for piece in _clip(_disc(center, radius, radius, 14)):
		draw_colored_polygon(piece, color)


func _limb(from: Vector2, to: Vector2, width: float) -> PackedVector2Array:
	var direction := (to - from).normalized()
	var side := Vector2(-direction.y, direction.x) * width * 0.5
	return PackedVector2Array([from + side, to + side * 0.72, to - side * 0.72, from - side])


func _disc(center: Vector2, radius_x: float, radius_y: float, segments: int = 18) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


## Defaults to whoever the derby captain is this save rather than to a name
## written in here. Empty means "the captain", resolved at the call.
func open_archive(focus_id: String = "") -> void:
	var fallback := CAST.id_for("derby_captain")
	selected_id = focus_id if graph_positions.has(focus_id) else fallback
	visible = true
	modulate.a = 0.0
	queue_redraw()


func close_archive() -> void:
	visible = false
	dragging = false


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	# Fade in rather than snap. The archive is meant to resolve like a scan
	# acquiring signal, not appear like a dialog box.
	modulate.a = move_toward(modulate.a, 1.0, delta * 3.2)
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
			if event.pressed and body_view_rect.has_point(event.position):
				dragging_divider = true
				_move_divider(event.position)
				accept_event()
				return
			if not event.pressed and dragging_divider:
				dragging_divider = false
				accept_event()
				return
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
	elif event is InputEventMouseMotion and dragging_divider:
		_move_divider(event.position)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		pan += event.position - last_pointer
		last_pointer = event.position
		queue_redraw()
		accept_event()


func _move_divider(pointer: Vector2) -> void:
	if body_view_rect.size.x <= 1.0:
		return
	divider_ratio = clampf((pointer.x - body_view_rect.position.x) / body_view_rect.size.x, 0.0, 1.0)
	queue_redraw()


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
	CellOutzType.draw_string_compat(self, midpoint + Vector2(-35, -5), kind.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 70, 9, color)


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
	var display_name := str(subject.get("name", subject_id.replace("_", " "))).to_upper()
	CellOutzType.draw_string_compat(self, center + Vector2(-30, -6), display_name, HORIZONTAL_ALIGNMENT_LEFT, 100, 11, BONE)
	var subtitle := str(subject.get("role", subject.get("kind", "unknown"))).to_upper()
	CellOutzType.draw_string_compat(self, center + Vector2(-30, 12), subtitle, HORIZONTAL_ALIGNMENT_LEFT, 100, 8, edge)


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
	var name := str(subject.get("name", selected_id.replace("_", " "))).to_upper()
	CellOutzType.draw_string_compat(self, Vector2(left + 22, 108), name, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44, 20, BONE)
	CellOutzType.draw_string_compat(self, Vector2(left + 22, 132), str(subject.get("role", "UNRESOLVED")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44, 11, COPPER)
	if str(subject.get("kind", "person")) == "faction":
		_draw_faction_dossier(subject, panel_rect)
	else:
		_draw_person_dossier(subject, panel_rect)


func _draw_person_dossier(subject: Dictionary, panel_rect: Rect2) -> void:
	var left := panel_rect.position.x
	var top := panel_rect.position.y
	# One large body, not two small panes. The scan is the centrepiece of the
	# dossier, and the flesh reads through it rather than sitting beside it.
	var body_rect := Rect2(left + 18, top + 74, panel_rect.size.x - 36, panel_rect.size.y - 250)
	draw_rect(body_rect, Color("120709"))
	draw_texture_rect(interference_texture, body_rect, true, Color(1, 1, 1, 0.06))
	draw_rect(body_rect, COPPER * Color(1, 1, 1, 0.3), false, 1)

	body_view_rect = body_rect
	_draw_body_layers(body_rect, subject)
	_draw_tree_alignment(body_rect, subject)

	# The divider handle itself: a scan head parked on the body.
	var divider_x := body_rect.position.x + body_rect.size.x * divider_ratio
	draw_line(Vector2(divider_x, body_rect.position.y + 2), Vector2(divider_x, body_rect.end.y - 2), TEAL * Color(1, 1, 1, 0.85), 2)
	draw_line(Vector2(divider_x + 2, body_rect.position.y + 2), Vector2(divider_x + 2, body_rect.end.y - 2), MAGENTA * Color(1, 1, 1, 0.35), 1)
	var handle := Vector2(divider_x, body_rect.get_center().y)
	draw_circle(handle, 13.0, Color("07171a"))
	draw_arc(handle, 13.0, 0, TAU, 22, TEAL, 2)
	draw_line(handle - Vector2(5, 0), handle + Vector2(5, 0), TEAL, 2)
	draw_line(handle - Vector2(0, 5), handle + Vector2(0, 5), TEAL, 2)

	CellOutzType.draw_string_compat(self, body_rect.position + Vector2(12, 20), "VESSEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COPPER)
	CellOutzType.draw_string_compat(self, Vector2(body_rect.end.x - 82, body_rect.position.y + 20), "DEEP XRAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEAL)
	CellOutzType.draw_string_compat(self, Vector2(body_rect.position.x + 12, body_rect.end.y - 8), "DRAG THE SCAN HEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BONE * Color(1, 1, 1, 0.4))
	var elo := int(subject.get("elo", 0))
	var grudge := int(subject.get("grudge", 0))
	var status := str(subject.get("status", "unknown")).to_upper()
	var faction := str(subject.get("faction", "Unaffiliated"))
	var info_y := body_rect.end.y + 26
	CellOutzType.draw_string_compat(self, Vector2(left + 22, info_y), "ELO %04d   %s   GRUDGE %03d" % [elo, _rank_title(elo), grudge], HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44, 12, BONE)
	CellOutzType.draw_string_compat(self, Vector2(left + 22, info_y + 22), "FACTION // %s" % faction.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44, 10, SPORE)
	CellOutzType.draw_string_compat(self, Vector2(left + 22, info_y + 43), "STATUS // %s   LASTING MEMORY" % status, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COPPER)
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


## Draws the flesh pass and the scan pass into the same space, crossfading by
## opacity so the two readings occupy one body instead of two panels.
## The scan sits underneath and the flesh is clipped over it, so dragging the
## divider peels the body open rather than fading two panels against each other.
func _draw_body_layers(rect: Rect2, subject: Dictionary) -> void:
	var scale := clampf(minf(rect.size.x / 150.0, rect.size.y / 250.0), 0.6, 2.6)
	var center := rect.get_center()
	var local := Rect2(-rect.size * 0.5 / scale, rect.size / scale)
	draw_set_transform(center, 0.0, Vector2(scale, scale))

	clip_active = false
	_draw_body_slice(local, true, subject, 1.0)

	# Flesh covers everything left of the divider, in the body's local space.
	var divider_local := (rect.position.x + rect.size.x * divider_ratio - center.x) / scale
	clip_active = true
	clip_min_x = local.position.x - 10.0
	clip_max_x = divider_local
	_draw_body_slice(local, false, subject, 1.0)
	clip_active = false

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_body_slice(rect: Rect2, xray: bool, subject: Dictionary, opacity: float = 1.0) -> void:
	if opacity <= 0.01:
		return
	var center := Vector2.ZERO
	var pulse := 0.5 + 0.5 * sin(elapsed * 2.4)

	var skin_tint := TEAL * Color(1, 1, 1, 0.3 * opacity) if xray else Color("5e241c") * Color(1, 1, 1, opacity)
	# Shoulders wider than waist, tapered neck, ovoid skull: enough silhouette to
	# read as a person before any detail lands on it.
	var torso := PackedVector2Array([
		center + Vector2(-20, -62), center + Vector2(20, -62),
		center + Vector2(30, -48), center + Vector2(27, 2),
		center + Vector2(20, 44), center + Vector2(-20, 44),
		center + Vector2(-27, 2), center + Vector2(-30, -48),
	])
	_tiled_polygon(torso, skin_tint, tissue_texture, 46.0)
	_tiled_polygon(_limb(center + Vector2(-25, -48), center + Vector2(-47, 36), 15), skin_tint, tissue_texture, 38.0)
	_tiled_polygon(_limb(center + Vector2(25, -48), center + Vector2(47, 36), 15), skin_tint, tissue_texture, 38.0)
	_tiled_polygon(_limb(center + Vector2(-13, 40), center + Vector2(-20, 104), 18), skin_tint, tissue_texture, 40.0)
	_tiled_polygon(_limb(center + Vector2(13, 40), center + Vector2(20, 104), 18), skin_tint, tissue_texture, 40.0)
	_tiled_polygon(_limb(center + Vector2(-7, -66), center + Vector2(-7, -56), 14), skin_tint, tissue_texture, 20.0)
	_tiled_polygon(_disc(center + Vector2(0, -86), 21.0, 25.0), skin_tint, tissue_texture, 34.0)

	if xray:
		var bone := Color("d8e6c8")
		# Viscera first, skeleton over it, so organs read as sitting inside the cage.
		_draw_viscera(center, pulse, opacity)
		draw_line(center + Vector2(0, -55), center + Vector2(0, 46), bone * Color(1, 1, 1, 0.85 * opacity), 4)
		for rib in 5:
			var y := -40.0 + rib * 14.0
			draw_arc(center + Vector2(0, y), 25 - rib * 1.6, 0.22, PI - 0.22, 16, bone * Color(1, 1, 1, 0.78 * opacity), 2)
			draw_arc(center + Vector2(0, y), 25 - rib * 1.6, PI + 0.22, TAU - 0.22, 16, bone * Color(1, 1, 1, 0.35 * opacity), 1)
		# Skull plate and jaw.
		draw_arc(center + Vector2(0, -86), 22, PI, TAU, 20, bone * Color(1, 1, 1, 0.7 * opacity), 2)
		draw_line(center + Vector2(-13, -74), center + Vector2(13, -74), bone * Color(1, 1, 1, 0.5 * opacity), 2)
		_draw_capillaries(center, opacity)
		var anatomy: Dictionary = subject.get("anatomy", {})
		var cybernetics: Array = anatomy.get("cybernetics", [])
		for index in cybernetics.size():
			var module_pos := center + Vector2(32 if index % 2 == 0 else -32, -30 + index * 31)
			draw_rect(Rect2(module_pos - Vector2(9, 7), Vector2(18, 14)), MAGENTA * Color(1, 1, 1, 0.22 * opacity))
			draw_rect(Rect2(module_pos - Vector2(9, 7), Vector2(18, 14)), MAGENTA * Color(1, 1, 1, opacity), false, 1.5)
			draw_line(module_pos, center, MAGENTA * Color(1, 1, 1, 0.4 * opacity), 1)
	else:
		# Bruising and discoloration blotches before the wounds themselves.
		for index in 5:
			var blotch := center + Vector2(sin(index * 2.7) * 26.0, -40.0 + index * 27.0)
			_clipped_disc(blotch, 9.0 + float(index % 3) * 4.0, BRUISE * Color(1, 1, 1, 0.22 * opacity))
		var wounds: Array = subject.get("wounds", [])
		for index in wounds.size():
			var wound_pos := center + Vector2(-18 + index * 15, -20 + index * 26)
			if clip_active and wound_pos.x > clip_max_x:
				continue
			_clipped_disc(wound_pos, 8.0, Color("2b0806") * Color(1, 1, 1, 0.85 * opacity))
			_clipped_disc(wound_pos, 4.5, ARTERIAL * Color(1, 1, 1, opacity))
			# Ragged edge rather than a tidy cross.
			for spur in 6:
				var angle := TAU * spur / 6.0 + float(index)
				var reach := 7.0 + fmod(float(spur * 13 + index * 7), 5.0)
				draw_line(wound_pos, wound_pos + Vector2.from_angle(angle) * reach, ARTERIAL * Color(1, 1, 1, 0.75 * opacity), 2)
			# Run-off.
			draw_line(wound_pos, wound_pos + Vector2(2, 16 + float(index % 3) * 9.0), Color("5e0f0b") * Color(1, 1, 1, opacity), 3)

	# Colour clash overlay: an acid pass that fights the base palette instead of
	# harmonising with it. Skipped while clipping so it cannot tint the scan side.
	if not clip_active:
		draw_texture_rect(interference_texture, rect, true, (ACID if xray else MAGENTA) * Color(1, 1, 1, 0.05 * opacity))


func _draw_viscera(center: Vector2, pulse: float, opacity: float) -> void:
	# Lungs.
	_tiled_polygon(PackedVector2Array([
		center + Vector2(-24, -46), center + Vector2(-6, -42),
		center + Vector2(-8, -6), center + Vector2(-23, -10),
	]), BRUISE * Color(1, 1, 1, 0.72 * opacity), tissue_texture, 26.0)
	_tiled_polygon(PackedVector2Array([
		center + Vector2(24, -46), center + Vector2(6, -42),
		center + Vector2(8, -6), center + Vector2(23, -10),
	]), BRUISE * Color(1, 1, 1, 0.72 * opacity), tissue_texture, 26.0)
	# Heart, beating.
	var heart := center + Vector2(-3, -26)
	draw_circle(heart, 11.0 + pulse * 2.4, ARTERIAL * Color(1, 1, 1, 0.9 * opacity))
	draw_circle(heart + Vector2(5, -4), 7.0 + pulse * 1.6, ARTERIAL * Color(1, 1, 1, 0.75 * opacity))
	draw_circle(heart, 4.0, MAGENTA * Color(1, 1, 1, (0.5 + pulse * 0.4) * opacity))
	# Liver.
	_tiled_polygon(PackedVector2Array([
		center + Vector2(-18, 2), center + Vector2(14, 0),
		center + Vector2(19, 24), center + Vector2(-12, 30),
	]), BILE * Color(1, 1, 1, 0.6 * opacity), tissue_texture, 30.0)
	# Coiled intestine.
	for coil in 7:
		var t := float(coil) / 7.0
		var loop_centre := center + Vector2(-14.0 + fmod(float(coil) * 9.0, 28.0), 30.0 + t * 14.0)
		draw_arc(loop_centre, 7.0 + float(coil % 3) * 2.0, 0.0, TAU, 14, Color("9a5a3c") * Color(1, 1, 1, 0.8 * opacity), 3)
	draw_circle(center + Vector2(16, 12), 6.0, ACID * Color(1, 1, 1, 0.35 * opacity))


func _draw_capillaries(center: Vector2, opacity: float) -> void:
	for branch in 9:
		var angle := TAU * branch / 9.0 + 0.4
		var start := center + Vector2.from_angle(angle) * 12.0
		var mid := center + Vector2.from_angle(angle + 0.3) * 30.0
		var tip := center + Vector2.from_angle(angle + 0.1) * 46.0
		draw_polyline(PackedVector2Array([start, mid, tip]), ARTERIAL * Color(1, 1, 1, 0.3 * opacity), 1.4)
		draw_line(mid, mid + Vector2.from_angle(angle - 0.9) * 11.0, ARTERIAL * Color(1, 1, 1, 0.2 * opacity), 1.0)


## The Deep X-ray doubles as an "as above, so below" reading: the same scan
## that shows organs and cybernetics also shows where the subject currently
## sits on the vertical Tree, so the body view and the metaphysical view are
## one instrument rather than two unrelated panels.
func _draw_tree_alignment(rect: Rect2, subject: Dictionary) -> void:
	var axis_x := rect.end.x - 15
	var top := rect.position.y + 16
	var bottom := rect.end.y - 12
	draw_line(Vector2(axis_x, top), Vector2(axis_x, bottom), TEAL * Color(1, 1, 1, 0.4), 2)
	CellOutzType.draw_string_compat(self, Vector2(axis_x - 58, top - 3), "ASCENT", HORIZONTAL_ALIGNMENT_RIGHT, 52, 7, SPORE * Color(1, 1, 1, 0.75))
	CellOutzType.draw_string_compat(self, Vector2(axis_x - 58, (top + bottom) * 0.5 + 3), "LIMBO", HORIZONTAL_ALIGNMENT_RIGHT, 52, 7, BONE * Color(1, 1, 1, 0.5))
	CellOutzType.draw_string_compat(self, Vector2(axis_x - 58, bottom + 10), "DESCENT", HORIZONTAL_ALIGNMENT_RIGHT, 52, 7, BLOOD * Color(1, 1, 1, 0.75))
	var alignment := WorldHistory.tree_alignment(subject)
	var marker_y := lerpf(top, bottom, (1.0 - alignment) * 0.5)
	var marker_color := SPORE if alignment > 0.2 else (BLOOD if alignment < -0.2 else BONE)
	draw_circle(Vector2(axis_x, marker_y), 7.0, marker_color * Color(1, 1, 1, 0.28))
	draw_circle(Vector2(axis_x, marker_y), 4.0, marker_color)
	var descriptor := WorldHistory.tree_descriptor(subject)
	if not descriptor.is_empty():
		CellOutzType.draw_string_compat(self, Vector2(axis_x - 58, marker_y - 11), descriptor.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, 52, 8, marker_color)


func _draw_faction_dossier(subject: Dictionary, panel_rect: Rect2) -> void:
	var center := panel_rect.get_center() + Vector2(0, -55)
	for ring in 6:
		draw_arc(center, 38.0 + ring * 20, elapsed * 0.08 * (1 if ring % 2 == 0 else -1), TAU, 48, SPORE * Color(1, 1, 1, 0.12 + ring * 0.03), 2)
	for spoke in 12:
		var angle := TAU * spoke / 12.0
		draw_line(center + Vector2.from_angle(angle) * 38, center + Vector2.from_angle(angle) * 132, TEAL * Color(1, 1, 1, 0.22), 1)
	draw_circle(center, 28 + sin(elapsed * 2.0) * 3, BLOOD * Color(1, 1, 1, 0.55))
	var info_y := panel_rect.position.y + 405
	CellOutzType.draw_string_compat(self, Vector2(panel_rect.position.x + 22, info_y), "DOCTRINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COPPER)
	_draw_wrapped(str(subject.get("doctrine", "No doctrine recovered.")), Vector2(panel_rect.position.x + 22, info_y + 23), panel_rect.size.x - 44, 12, BONE, 4)
	CellOutzType.draw_string_compat(self, Vector2(panel_rect.position.x + 22, info_y + 105), "THREAT %s   TERRITORY %s" % [str(subject.get("threat", "?")), str(subject.get("territory", "unknown")).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 44, 11, SPORE)


## Body copy: wrapped prose stays in a real font. The stencil face is for
## stamps and labels, not paragraphs (the rule world_index.gd states).
func _draw_wrapped(value: String, at: Vector2, width: float, font_size: int, color: Color, max_lines: int) -> void:
	var words := value.split(" ")
	var line := ""
	var line_index := 0
	for word in words:
		var candidate := word if line.is_empty() else line + " " + word
		if ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not line.is_empty():
			draw_string(ThemeDB.fallback_font, at + Vector2(0, line_index * (font_size + 5)), line, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)
			line_index += 1
			line = word
			if line_index >= max_lines:
				return
		else:
			line = candidate
	if line_index < max_lines and not line.is_empty():
		draw_string(ThemeDB.fallback_font, at + Vector2(0, line_index * (font_size + 5)), line, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)


func _draw_header() -> void:
	draw_rect(Rect2(0, 0, size.x, 58), Color("13080a"))
	draw_line(Vector2(0, 58), Vector2(size.x, 58), COPPER, 2)
	CellOutzType.draw_string_compat(self, Vector2(28, 35), "THE LIVING KINSHIP WEB", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, BONE)
	# Set after the title rather than at a fixed x: in the house face the title
	# is wider than the engine font made it, and a fixed 345 ran into it.
	var title_end := 28.0 + CellOutzType.string_size_compat("THE LIVING KINSHIP WEB", HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	CellOutzType.draw_string_compat(self, Vector2(title_end + 24.0, 34), "ASHBLOOM EXPANSE // BLOOD · BOND · COMMAND", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEAL)
	CellOutzType.draw_string_compat(self, Vector2(size.x - 390, 34), "WHEEL ZOOM   DRAG PAN   CLICK OPEN   T CLOSE", HORIZONTAL_ALIGNMENT_LEFT, 360, 10, BONE * Color(1, 1, 1, 0.6))
