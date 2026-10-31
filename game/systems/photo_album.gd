class_name PhotoAlbum
extends Control

## The photo album the Brain Index shows (item 6, Greg 2026-09-24: photos
## "stored in a remastered Y2K skeuomorphic brain index"). Brushed metal, aqua
## gel buttons, prints in inset wells and a green LCD strip for what the
## camera knew about the shot. PhotoMode writes the pictures; this owns where
## they live and how they are read back.
##
## Photos sit under user://photos as PNG plus a JSON sidecar, beside the save
## rather than in it, like a camera roll.

## Settable so tests never write into the player's real album.
static var dir := "user://photos/"
const CellOutzType := preload("res://systems/celloutz_type.gd")
const COLUMNS := 3
const ROWS := 3
const PER_PAGE := COLUMNS * ROWS

const METAL_TOP := Color("dcdee1")
const METAL_BOTTOM := Color("a4a9b0")
const AQUA_TOP := Color("7cc2f6")
const AQUA_BOTTOM := Color("1d64c9")
const LCD := Color("b4c79c")
const LCD_INK := Color("1f2b19")
const WELL := Color("3a3f46")

var photos: Array = []
var selected := 0
var page := 0

var _textures: Dictionary = {}
var _hits: Array = []


static func save(image: Image, meta: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := str(Time.get_unix_time_from_system()).replace(".", "_")
	var path := dir + "photo_%s.png" % stamp
	image.save_png(path)
	var record := meta.duplicate()
	record["taken"] = Time.get_unix_time_from_system()
	var file := FileAccess.open(path.get_basename() + ".json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(record))
	return path


## Every photo, newest first, as {path, meta}.
static func list() -> Array:
	var found: Array = []
	var folder := DirAccess.open(dir)
	if folder == null:
		return found
	for name in folder.get_files():
		if not name.ends_with(".png"):
			continue
		var path := dir + name
		var meta: Dictionary = {}
		var sidecar := path.get_basename() + ".json"
		if FileAccess.file_exists(sidecar):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(sidecar))
			if parsed is Dictionary:
				meta = parsed
		found.append({"path": path, "meta": meta})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.meta.get("taken", 0.0)) > float(b.meta.get("taken", 0.0)))
	return found


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	photos = list()
	selected = clampi(selected, 0, maxi(0, photos.size() - 1))
	page = selected / PER_PAGE
	queue_redraw()


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		var image := Image.load_from_file(path)
		_textures[path] = ImageTexture.create_from_image(image) if image != null else null
	return _textures[path]


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_LEFT:
				_select(selected - 1)
			KEY_RIGHT:
				_select(selected + 1)
			KEY_UP:
				_select(selected - COLUMNS)
			KEY_DOWN:
				_select(selected + COLUMNS)
			_:
				return false
		return true
	if event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_select(selected - PER_PAGE)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				_select(selected + PER_PAGE)
				return true
			MOUSE_BUTTON_LEFT:
				var local := get_global_transform_with_canvas().affine_inverse() * button.position
				for hit: Dictionary in _hits:
					if (hit.rect as Rect2).has_point(local):
						_select(int(hit.index))
						return true
	return false


func _select(index: int) -> void:
	if photos.is_empty():
		return
	selected = clampi(index, 0, photos.size() - 1)
	page = selected / PER_PAGE
	queue_redraw()


func _draw() -> void:
	_hits.clear()
	var frame := Rect2(Vector2.ZERO, size)
	_gel(frame.grow(-2), 16.0, METAL_TOP, METAL_BOTTOM, Color(0.2, 0.22, 0.25))
	# Brushed metal: fine horizontal streaks.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var y := frame.position.y + 8.0
	while y < frame.end.y - 8.0:
		draw_line(Vector2(frame.position.x + 10, y), Vector2(frame.end.x - 10, y), Color(1, 1, 1, rng.randf_range(0.0, 0.18)), 1.0)
		y += rng.randf_range(1.0, 3.0)
	var title := Rect2(frame.position + Vector2(14, 12), Vector2(frame.size.x - 28, 30))
	_gel(title, 15.0, AQUA_TOP, AQUA_BOTTOM, Color(0.05, 0.2, 0.45))
	_label(title.position + Vector2(18, 10), "BRAIN INDEX  //  PHOTOS", 11.0, Color.WHITE)
	_label(Vector2(title.end.x - 150, title.position.y + 10), "%d TAKEN" % photos.size(), 11.0, Color.WHITE)
	var body := Rect2(title.position + Vector2(0, 42), Vector2(title.size.x, frame.size.y - 70))
	var grid := Rect2(body.position, Vector2(body.size.x * 0.4, body.size.y))
	var view := Rect2(Vector2(grid.end.x + 14, body.position.y), Vector2(body.end.x - grid.end.x - 14, body.size.y))
	_draw_grid(grid)
	_draw_view(view)


func _draw_grid(rect: Rect2) -> void:
	var cell := Vector2(rect.size.x / COLUMNS, (rect.size.y - 34) / ROWS)
	for slot in PER_PAGE:
		var index := page * PER_PAGE + slot
		var at := rect.position + Vector2(slot % COLUMNS, slot / COLUMNS) * cell
		var well := Rect2(at + Vector2(4, 4), cell - Vector2(8, 8))
		_inset(well)
		if index >= photos.size():
			continue
		var print_rect := well.grow(-6)
		draw_rect(print_rect, Color(0.96, 0.96, 0.94))
		var texture := _texture(str(photos[index].path))
		if texture != null:
			draw_texture_rect(texture, _fit(texture, print_rect.grow(-4)), false)
		if index == selected:
			for ring in 3:
				draw_rect(well.grow(1 + ring * 2), Color(AQUA_TOP, 0.7 - ring * 0.2), false, 2.0)
		_hits.append({"rect": well, "index": index})
	# Page buttons: two gel pills.
	var pills := Rect2(Vector2(rect.position.x + 4, rect.end.y - 28), Vector2(rect.size.x - 8, 24))
	var half := pills.size.x * 0.5 - 4
	_gel(Rect2(pills.position, Vector2(half, 24)), 12.0, AQUA_TOP, AQUA_BOTTOM, Color(0.05, 0.2, 0.45))
	_gel(Rect2(pills.position + Vector2(half + 8, 0), Vector2(half, 24)), 12.0, AQUA_TOP, AQUA_BOTTOM, Color(0.05, 0.2, 0.45))
	_label(pills.position + Vector2(half * 0.5 - 18, 7), "< PREV", 9.0, Color.WHITE)
	_label(pills.position + Vector2(half * 1.5 - 12, 7), "NEXT >", 9.0, Color.WHITE)
	_hits.append({"rect": Rect2(pills.position, Vector2(half, 24)), "index": maxi(0, (page - 1) * PER_PAGE)})
	_hits.append({"rect": Rect2(pills.position + Vector2(half + 8, 0), Vector2(half, 24)), "index": mini(photos.size() - 1, (page + 1) * PER_PAGE)})


func _draw_view(rect: Rect2) -> void:
	var lcd := Rect2(Vector2(rect.position.x, rect.end.y - 58), Vector2(rect.size.x, 54))
	var screen := Rect2(rect.position, Vector2(rect.size.x, rect.size.y - 66))
	_inset(screen)
	_inset(lcd)
	var glass := lcd.grow(-5)
	draw_rect(glass, LCD)
	if photos.is_empty():
		_label(screen.get_center() - Vector2(110, 6), "NO PHOTOS YET  //  F10 IN THE FIELD", 10.0, Color(0.85, 0.87, 0.9))
		_label(glass.position + Vector2(10, 10), "READY", 11.0, LCD_INK)
		return
	var photo: Dictionary = photos[selected]
	var texture := _texture(str(photo.path))
	if texture != null:
		var fitted := _fit(texture, screen.grow(-10))
		draw_rect(fitted.grow(5), Color(0.97, 0.97, 0.95))
		draw_texture_rect(texture, fitted, false)
	var meta: Dictionary = photo.meta
	var hour := float(meta.get("hour", 0.0))
	var first := "%03d/%03d   %02d:%02d   %s   %dMM" % [selected + 1, photos.size(), int(hour) % 24, int(fposmod(hour, 1.0) * 60.0), str(meta.get("filter", "")), int(12.0 / tan(deg_to_rad(float(meta.get("fov", 70.0))) * 0.5))]
	_label(glass.position + Vector2(10, 8), first, 10.0, LCD_INK)
	var caption := str(meta.get("caption", ""))
	_label(glass.position + Vector2(10, 26), (caption if not caption.is_empty() else "NOTHING IN FRAME").to_upper().left(70), 9.0, LCD_INK)


## A rounded rect with a vertical gradient and the gloss of a Y2K gel button.
func _gel(rect: Rect2, radius: float, top: Color, bottom: Color, outline: Color) -> void:
	var points := _rounded(rect, radius)
	var colours := PackedColorArray()
	for point in points:
		colours.append(top.lerp(bottom, clampf((point.y - rect.position.y) / rect.size.y, 0.0, 1.0)))
	draw_polygon(points, colours)
	var gloss_rect := Rect2(rect.position + Vector2(radius * 0.5, 2), Vector2(rect.size.x - radius, rect.size.y * 0.45))
	var gloss := _rounded(gloss_rect, minf(radius, gloss_rect.size.y * 0.5))
	var gloss_colours := PackedColorArray()
	for point in gloss:
		gloss_colours.append(Color(1, 1, 1, lerpf(0.55, 0.08, clampf((point.y - gloss_rect.position.y) / gloss_rect.size.y, 0.0, 1.0))))
	draw_polygon(gloss, gloss_colours)
	points.append(points[0])
	draw_polyline(points, outline, 1.2, true)


## A recessed well: dark, with a shadow along the top edge and light along the bottom.
func _inset(rect: Rect2) -> void:
	var points := _rounded(rect, 6.0)
	draw_colored_polygon(points, WELL)
	draw_line(rect.position + Vector2(6, 1), Vector2(rect.end.x - 6, rect.position.y + 1), Color(0, 0, 0, 0.6), 2.0)
	draw_line(Vector2(rect.position.x + 6, rect.end.y), rect.end - Vector2(6, 0), Color(1, 1, 1, 0.7), 1.0)


func _rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var centres := [rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r), rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r)]
	for corner in 4:
		for step in 7:
			var angle := (corner + step / 6.0) * PI * 0.5
			var point := (centres[corner] as Vector2) + Vector2(cos(angle), sin(angle)) * r
			# A full-round pill makes neighbouring arcs meet at one point; a
			# repeated vertex fails triangulation.
			if points.is_empty() or points[points.size() - 1].distance_to(point) > 0.01:
				points.append(point)
	if points.size() > 2 and points[0].distance_to(points[points.size() - 1]) <= 0.01:
		points.remove_at(points.size() - 1)
	return points


func _fit(texture: Texture2D, rect: Rect2) -> Rect2:
	var aspect := float(texture.get_width()) / float(maxi(1, texture.get_height()))
	var fitted := rect.size
	if rect.size.x / rect.size.y > aspect:
		fitted.x = rect.size.y * aspect
	else:
		fitted.y = rect.size.x / aspect
	return Rect2(rect.position + (rect.size - fitted) * 0.5, fitted)


func _label(at: Vector2, text: String, height: float, colour: Color) -> void:
	CellOutzType.draw_text(self, at, text, height, colour, 1.0)
