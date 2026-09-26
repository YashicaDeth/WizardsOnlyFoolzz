class_name RunCard
extends CanvasLayer

## The end-of-run card (Greg, 26 September): shown once, when you surface
## from the facility, with the time in each area and the total against the
## 30-minute mark. Drawn like the F1 keys card. Fades on its own; never
## takes input.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const RUN_TIMER := preload("res://systems/run_timer.gd")
const BONE := Color("ead4ad")
const COPPER := Color("dc5827")
const ACID := Color("b4da48")
const BLOOD := Color("a81716")
const HOLD_SECONDS := 9.0
const FADE_SECONDS := 1.2

var summary: Dictionary = {}
var age := 0.0
var sheet: Control


func show_summary(data: Dictionary) -> void:
	summary = data
	layer = 60
	sheet = Control.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.draw.connect(_draw_sheet)


func _process(delta: float) -> void:
	if sheet == null:
		return
	age += delta
	if age > HOLD_SECONDS + FADE_SECONDS:
		queue_free()
		return
	sheet.queue_redraw()


func _draw_sheet() -> void:
	var alpha := clampf(age / 0.4, 0.0, 1.0) * clampf((HOLD_SECONDS + FADE_SECONDS - age) / FADE_SECONDS, 0.0, 1.0)
	var rows: Array = summary.get("rows", [])
	var plate := Vector2(520.0, 132.0 + 26.0 * rows.size())
	var origin := Vector2((sheet.size.x - plate.x) * 0.5, sheet.size.y * 0.22)
	sheet.draw_rect(Rect2(origin, plate), Color(0.02, 0.01, 0.012, 0.9 * alpha))
	sheet.draw_rect(Rect2(origin, plate), Color(COPPER, 0.8 * alpha), false, 1.5)
	CellOutzType.draw_stamped(sheet, origin + Vector2(28.0, 40.0), "SURFACED", 22.0, Color(COPPER, alpha), Color(BLOOD, 0.5 * alpha))
	var total := float(summary.get("total", 0.0))
	var under := bool(summary.get("under_target", false))
	CellOutzType.draw_condensed(sheet, origin + Vector2(28.0, 76.0),
		"MINUTES 0-30 // %s  %s" % [RUN_TIMER.clock(total), "UNDER THE 30" if under else "OVER THE 30"], 11.0,
		Color(ACID if under else BLOOD, alpha), 1.6)
	sheet.draw_line(origin + Vector2(28.0, 90.0), origin + Vector2(plate.x - 28.0, 90.0), Color(COPPER, 0.5 * alpha), 1.0)
	var y := 118.0
	for row: Dictionary in rows:
		CellOutzType.draw_condensed(sheet, origin + Vector2(28.0, y), str(row.label), 10.5, Color(COPPER, 0.92 * alpha), 1.8)
		CellOutzType.draw_condensed(sheet, origin + Vector2(plate.x - 110.0, y), RUN_TIMER.clock(float(row.seconds)), 10.5, Color(BONE, 0.8 * alpha), 1.4)
		y += 26.0
