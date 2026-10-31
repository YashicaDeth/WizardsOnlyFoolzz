class_name GalleryView
extends Control
## The Brain Index's art gallery: a wall of frames. Hornee's card first (you
## carry him), then every piece of Greg's art you have torn off a poster or
## picked up as a card (ArtGallery). Frames still empty are shown empty, so
## the wall says how much is still out there. Click a frame to see it large;
## Hornee's frame asks the hub to open his card.

signal open_hornee

const INK := Color("ead4ad")
const DIM := Color("8a7e6c")
const HOT := Color("c8452a")
const COLUMNS := 3
const HORNEE_ART := preload("res://art/items/hornee/zombie_minion.jpg")

var large := ""
var _frames: Array = []
## Loaded once when the wall opens, not mid-draw (a texture first loaded
## inside _draw came out white).
var _art: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open() -> void:
	for piece_id in ArtGallery.PIECES:
		if not _art.has(piece_id):
			_art[piece_id] = ArtGallery.texture(piece_id)
	large = ""
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


## Left click picks a frame, or closes the large view. Esc/Tab/Backspace are
## the hub's (they put the whole gallery away); in the large view they close
## just the picture.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and large != "":
		if (event as InputEventKey).keycode in [KEY_ESCAPE, KEY_TAB, KEY_BACKSPACE]:
			large = ""
			queue_redraw()
			return true
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if large != "":
			large = ""
			queue_redraw()
			return true
		var local := get_global_transform_with_canvas().affine_inverse() * (event as InputEventMouseButton).position
		for frame: Dictionary in _frames:
			if (frame.rect as Rect2).has_point(local):
				pick(str(frame.id))
				return true
		return true
	return false


func pick(piece_id: String) -> void:
	if piece_id == "hornee":
		open_hornee.emit()
	elif ArtGallery.has(piece_id):
		large = piece_id
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color(0.03, 0.02, 0.02, 0.94))
	var found := ArtGallery.collected()
	CellOutzType.draw_condensed(self, Vector2(16, 12), "GALLERY  //  %d OF %d FOUND" % [found.size(), ArtGallery.PIECES.size()], 12.0, INK, 0.9)
	if large != "":
		_draw_large(area)
		return
	_frames.clear()
	var ids: Array = ["hornee"]
	ids.append_array(ArtGallery.PIECES.keys())
	var cell := Vector2((size.x - 32) / COLUMNS, (size.y - 80) / ceilf(float(ids.size()) / COLUMNS))
	for index in ids.size():
		var id: String = ids[index]
		var rect := Rect2(Vector2(16 + (index % COLUMNS) * cell.x, 40 + (index / COLUMNS) * cell.y), cell - Vector2(12, 12))
		_frames.append({"id": id, "rect": rect})
		var owned := id == "hornee" or found.has(id)
		draw_rect(rect, Color(0.09, 0.07, 0.06))
		draw_rect(rect, (HOT if owned else DIM) * Color(1, 1, 1, 0.7 if owned else 0.3), false, 2.0)
		if not owned:
			CellOutzType.draw_condensed(self, rect.get_center() - Vector2(6, 6), "?", 14.0, DIM * Color(1, 1, 1, 0.5), 0.8)
			continue
		var texture: Texture2D = HORNEE_ART if id == "hornee" else _art.get(id)
		var inner := rect.grow(-6)
		inner.size.y -= 16
		var fit := _fit(texture, inner)
		draw_texture_rect(texture, fit, false)
		var title := "HORNEE" if id == "hornee" else str(ArtGallery.PIECES[id].title)
		CellOutzType.draw_condensed(self, Vector2(rect.position.x + 6, rect.end.y - 16), title.left(24), 7.0, INK * Color(1, 1, 1, 0.8), 0.6)
	CellOutzType.draw_condensed(self, Vector2(16, size.y - 22), "CLICK A FRAME  //  ESC OR TAB: BACK TO THE INDEX", 8.0, DIM, 0.7)


func _draw_large(area: Rect2) -> void:
	var texture: Texture2D = _art.get(large)
	var fit := _fit(texture, Rect2(Vector2(16, 40), area.size - Vector2(32, 80)))
	draw_rect(fit.grow(4), HOT * Color(1, 1, 1, 0.6), false, 2.0)
	draw_texture_rect(texture, fit, false)
	CellOutzType.draw_condensed(self, Vector2(16, size.y - 22), str(ArtGallery.PIECES[large].title) + "  //  CLICK OR ESC: BACK TO THE WALL", 8.0, DIM, 0.7)


func _fit(texture: Texture2D, room: Rect2) -> Rect2:
	var size_in := Vector2(texture.get_size())
	var by := minf(room.size.x / size_in.x, room.size.y / size_in.y)
	var shown := size_in * by
	return Rect2(room.position + (room.size - shown) * 0.5, shown)
