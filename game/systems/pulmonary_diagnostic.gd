class_name PulmonaryDiagnostic
extends Control

## A held, rotatable expansion of the contextual lung X-ray.
##
## This is deliberately a presentation of AnatomyComponent's values, not an
## organ minigame with its own damage meters. `PartViewer` supplies the same
## authored lung geometry used by the body inspector; this control only seats
## it in a field reliquary and labels the exact live readings.

const PART_VIEWER := preload("res://systems/part_viewer.gd")
const CellOutzType := preload("res://systems/celloutz_type.gd")

const BONE := Color("ead4ad")
const BLOOD := Color("a81716")
const COPPER := Color("dc5827")
const TEAL := Color("278f87")
const VOID := Color(0.012, 0.006, 0.009, 0.94)

var health := 1.0
var stain := 0.0
var fill := 0.0
var cough := 0.0
var inhaling := false
var expanded := false
var reveal := 0.0
var menu_open := false

var viewer: SubViewport
var specimen: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewer = PART_VIEWER.new()
	viewer.name = "PulmonaryPartViewer"
	add_child(viewer)
	viewer.size = Vector2i(420, 420)
	viewer.spin_speed = 0.24
	viewer.show_pulmonary_pair(health, stain, fill, cough)

	specimen = TextureRect.new()
	specimen.name = "LivePulmonarySpecimen"
	specimen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	specimen.texture = viewer.get_texture()
	specimen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	specimen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	specimen.modulate = Color.TRANSPARENT
	add_child(specimen)
	set_process(true)


func set_state(values: Dictionary) -> void:
	health = clampf(float(values.get("lung_health", health)), 0.0, 1.0)
	stain = clampf(float(values.get("lung_stain", stain)), 0.0, 1.0)
	fill = clampf(float(values.get("lung_fill", fill)), 0.0, 1.0)
	cough = clampf(float(values.get("lung_cough", cough)), 0.0, 1.0)
	inhaling = bool(values.get("lung_inhaling", inhaling))
	menu_open = bool(values.get("menu_open", menu_open))
	expanded = bool(values.get("pulmonary_expanded", expanded)) and not menu_open
	if viewer != null:
		viewer.show_pulmonary_pair(health, stain, fill, cough)


func rotate_by(relative: Vector2) -> void:
	if viewer != null:
		viewer.rotate_by(relative)


func zoom_by(factor: float) -> void:
	if viewer != null:
		viewer.zoom_by(factor)


func diagnostic_state() -> Dictionary:
	return {
		"expanded": expanded, "reveal": reveal, "health": health,
		"stain": stain, "fill": fill, "cough": cough,
		"viewer": viewer.view_state() if viewer != null else {},
	}


func _process(delta: float) -> void:
	var target := 1.0 if expanded else 0.0
	reveal = move_toward(reveal, target, delta * (6.5 if expanded else 8.0))
	_layout_specimen()
	if specimen != null:
		specimen.visible = reveal > 0.001
		specimen.modulate = Color(1, 1, 1, reveal)
	queue_redraw()


func _layout_specimen() -> void:
	if specimen == null:
		return
	var panel := _panel_rect()
	# Keep the live texture below the title/subtitle rather than letting its
	# opaque specimen well erase the first line of instruction.
	specimen.position = panel.position + Vector2(38, 67)
	specimen.size = Vector2(panel.size.x - 76, panel.size.y - 128)


func _panel_rect() -> Rect2:
	var panel_size := Vector2(482, minf(500.0, size.y - 104.0))
	return Rect2(Vector2(28, maxf(48.0, (size.y - panel_size.y) * 0.48)), panel_size)


func _draw() -> void:
	if reveal <= 0.001 or menu_open:
		return
	var alpha := reveal
	var panel := _panel_rect()
	# A dark glass field keeps the wet 3D tissue readable without becoming a
	# conventional rectangular menu. The clipped corners echo the physical HUD.
	var plate := PackedVector2Array([
		panel.position + Vector2(18, 0), panel.position + Vector2(panel.size.x - 42, 0),
		panel.position + Vector2(panel.size.x, 34), panel.end - Vector2(0, 24),
		panel.end - Vector2(24, 0), panel.position + Vector2(38, panel.size.y),
		panel.position + Vector2(0, panel.size.y - 38), panel.position + Vector2(0, 18),
	])
	draw_colored_polygon(plate, Color(VOID, VOID.a * alpha))
	draw_polyline(plate, Color(COPPER, 0.65 * alpha), 1.5)
	for inset in 3:
		draw_arc(panel.get_center(), 178.0 - inset * 8.0, -PI * 0.78, PI * 0.78, 52,
			Color(TEAL, (0.12 - inset * 0.025) * alpha), 1.0)

	CellOutzType.draw_stamped(self, panel.position + Vector2(24, 29),
		"PULMONARY RELIQUARY", 17.0, Color(COPPER, alpha), Color(BLOOD, 0.35 * alpha), 2.4)
	CellOutzType.draw_condensed(self, panel.position + Vector2(25, 48),
		"LIVE LEFT + RIGHT LUNG // V RELEASES", 8.5, Color(BONE, 0.52 * alpha), 1.0)

	var readout := panel.position + Vector2(24, panel.size.y - 25)
	var state_word := "COUGH" if cough > 0.12 else "DRAW" if inhaling else "CLEARING" if fill > 0.02 else "REST"
	CellOutzType.draw_condensed(self, readout, state_word, 9.0,
		Color(BLOOD if cough > 0.12 else TEAL, alpha), 1.5)
	CellOutzType.draw_condensed(self, readout + Vector2(84, 0),
		"TISSUE %03d%%  STAIN %03d%%  SMOKE %03d%%" % [roundi(health * 100.0), roundi(stain * 100.0), roundi(fill * 100.0)],
		8.5, Color(BONE, 0.68 * alpha), 0.85)
	CellOutzType.draw_condensed(self, panel.position + Vector2(panel.size.x - 154, panel.size.y - 43),
		"MOVE MOUSE / WHEEL", 7.5, Color(COPPER, 0.55 * alpha), 0.7)
