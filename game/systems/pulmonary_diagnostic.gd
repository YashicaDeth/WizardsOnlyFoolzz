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
var blood := 1.0
var pain := 0.0
var consciousness := 100.0
var wound_regions := {"head": 0.0, "torso": 0.0, "arms": 0.0, "legs": 0.0}
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
	blood = clampf(float(values.get("blood", blood)), 0.0, 1.0)
	pain = clampf(float(values.get("pain", pain)), 0.0, 100.0)
	consciousness = clampf(float(values.get("consciousness", consciousness)), 0.0, 100.0)
	var incoming_regions: Dictionary = values.get("wound_regions", wound_regions)
	for region in wound_regions:
		wound_regions[region] = clampf(float(incoming_regions.get(region, wound_regions[region])), 0.0, 1.0)
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
		"stain": stain, "fill": fill, "cough": cough, "blood": blood,
		"pain": pain, "consciousness": consciousness,
		"wound_regions": wound_regions.duplicate(),
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
	specimen.position = panel.position + Vector2(26, 67)
	specimen.size = Vector2(420, panel.size.y - 128)


func _panel_rect() -> Rect2:
	# Full-rect controls can receive one draw before their anchor layout settles
	# in headless and scene transitions. Never author a negative/self-crossing
	# plate during that frame; use the viewport as the honest fallback canvas.
	var canvas := size
	if canvas.x < 720.0 or canvas.y < 480.0:
		canvas = get_viewport_rect().size
	var panel_size := Vector2(minf(690.0, maxf(482.0, canvas.x - 56.0)), minf(500.0, maxf(360.0, canvas.y - 104.0)))
	return Rect2(Vector2(28, maxf(48.0, (canvas.y - panel_size.y) * 0.48)), panel_size)


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

	# V is now an honest self-condition inspection rather than lungs floating in
	# isolation. The pulmonary specimen remains the centrepiece Greg liked; the
	# body's real blood, consciousness, pain and regional damage sit beside it.
	var body_x := panel.position.x + 468.0
	CellOutzType.draw_stamped(self, Vector2(body_x, panel.position.y + 86.0),
		"SELF CONDITION", 12.0, Color(BONE, 0.82 * alpha), Color(BLOOD, 0.28 * alpha), 1.4)
	var vitals := [
		["BLOOD", blood, "%03d%%" % roundi(blood * 100.0)],
		["CONSCIOUS", consciousness / 100.0, "%03d%%" % roundi(consciousness)],
		# Rails read as remaining function. Pain's printed number remains literal,
		# but its rail empties as pain rises rather than rewarding agony with teal.
		["PAIN", 1.0 - pain / 100.0, "%03d%%" % roundi(pain)],
	]
	var read_y := panel.position.y + 121.0
	for vital: Array in vitals:
		_draw_condition_rail(Vector2(body_x, read_y), str(vital[0]), float(vital[1]), str(vital[2]), alpha)
		read_y += 38.0
	read_y += 12.0
	for region in ["head", "torso", "arms", "legs"]:
		var integrity := 1.0 - float(wound_regions.get(region, 0.0))
		_draw_condition_rail(Vector2(body_x, read_y), region.to_upper(), integrity, "%03d%%" % roundi(integrity * 100.0), alpha)
		read_y += 38.0


func _draw_condition_rail(at: Vector2, label: String, ratio: float, value: String, alpha: float) -> void:
	var amount := clampf(ratio, 0.0, 1.0)
	var tone := TEAL if amount > 0.62 else COPPER if amount > 0.28 else BLOOD
	CellOutzType.draw_condensed(self, at, label, 8.0, Color(BONE, 0.58 * alpha), 0.7)
	var value_width := CellOutzType.width_condensed(value, 8.0, 0.7)
	CellOutzType.draw_condensed(self, at + Vector2(164.0 - value_width, 0), value, 8.0, Color(tone, alpha), 0.7)
	var rail := Rect2(at + Vector2(0, 17), Vector2(164, 5))
	draw_rect(rail, Color(BONE, 0.08 * alpha))
	draw_rect(Rect2(rail.position, Vector2(rail.size.x * amount, rail.size.y)), Color(tone, 0.78 * alpha))
