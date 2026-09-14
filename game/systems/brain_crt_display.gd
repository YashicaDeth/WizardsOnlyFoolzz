extends SubViewport

## Live phosphor face fitted to the cortex specimen in `PartViewer`.
## The viewport is deliberately plain information, not a menu: the physical
## curve, bezel and surrounding brain carry the object while this surface reads
## the same index `BrainIndex` exposes to gameplay.

const BrainIndex := preload("res://systems/brain_index.gd")

const PHOSPHOR := Color("b8d98c")
const DIM := Color("667c55")
const HOT := Color("d86b3f")
const GLASS := Color("071009")

var subject_id := "player"
var folder_id := "trauma"
var _root: Control
var _title: Label
var _status: Label
var _rows: VBoxContainer


func _ready() -> void:
	size = Vector2i(384, 216)
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_root = Control.new()
	_root.name = "PhosphorFace"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var back := ColorRect.new()
	back.name = "BlackGlass"
	back.color = GLASS
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)

	_title = _label("WETWIRE // CORTEX:/TRAUMA", 18, PHOSPHOR)
	_title.name = "Path"
	_title.position = Vector2(20, 13)
	_title.size = Vector2(350, 28)
	_root.add_child(_title)

	_status = _label("", 11, HOT)
	_status.name = "Reach"
	_status.position = Vector2(22, 43)
	_status.size = Vector2(340, 20)
	_root.add_child(_status)

	var rule := ColorRect.new()
	rule.name = "RasterRule"
	rule.color = DIM
	rule.position = Vector2(18, 65)
	rule.size = Vector2(348, 2)
	_root.add_child(rule)

	_rows = VBoxContainer.new()
	_rows.name = "IndexRows"
	_rows.position = Vector2(22, 74)
	_rows.size = Vector2(340, 112)
	_rows.add_theme_constant_override("separation", 1)
	_root.add_child(_rows)

	# Actual raster lines on the emitted image. Their low alpha survives the
	# texture filtering on the bent mesh without swallowing the file names.
	for y in range(2, 216, 4):
		var scan := ColorRect.new()
		scan.color = Color(0.0, 0.0, 0.0, 0.17)
		scan.position = Vector2(0, y)
		scan.size = Vector2(384, 1)
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(scan)
	refresh()


func configure(value_subject_id: String = "player", value_folder_id: String = "trauma") -> void:
	subject_id = value_subject_id
	folder_id = value_folder_id if BrainIndex.FOLDERS.has(value_folder_id) else "trauma"
	if is_node_ready():
		refresh()


func refresh() -> void:
	if _rows == null:
		return
	var folder_label := str((BrainIndex.FOLDERS.get(folder_id, {}) as Dictionary).get("label", folder_id.to_upper()))
	_title.text = "WETWIRE // CORTEX:/%s" % folder_label
	var counts: Dictionary = BrainIndex.folder_counts(subject_id).get(folder_id, {})
	_status.text = "REACH %02dD   OPEN %02d/%02d   LOCAL ORGAN" % [
		BrainIndex.reach(subject_id), int(counts.get("open", 0)), int(counts.get("total", 0))]
	for child in _rows.get_children():
		child.queue_free()
	var listing: Array = BrainIndex.listing(folder_id, subject_id)
	for index in mini(5, listing.size()):
		var entry: Dictionary = listing[index]
		var sealed := not bool(entry.get("open", false))
		var line := _label("%s  %s" % ["×" if sealed else ">", str(entry.get("title", entry.get("id", "")))], 15, DIM if sealed else PHOSPHOR)
		line.name = "Row%d" % index
		line.custom_minimum_size = Vector2(330, 20)
		_rows.add_child(line)
	if listing.is_empty():
		_rows.add_child(_label("— NO RETURN FROM THIS REGION —", 14, DIM))


func displayed_rows() -> Array[String]:
	var out: Array[String] = []
	if _rows == null:
		return out
	for child in _rows.get_children():
		if child is Label:
			out.append((child as Label).text)
	return out


func _label(copy: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0.2, 0.55, 0.25, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label
