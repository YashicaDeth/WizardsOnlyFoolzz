class_name BloodReadout
extends Control

## "+N BLOOD // <WEAPON>": the moment a weapon learns something. Pops beside the
## crosshair, rises a little and fades. Blood earned by the same weapon while
## its line is still up is added into that line rather than stacking a second
## one, so a shotgun's ten pellets read as one number. A fixed pool of lines;
## the oldest is reused when it is full.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const BONE := Color("ead4ad")
const LIFE := 2.2
const POOL := 5
const LINE_GAP := 30.0

## Each: {weapon, label, amount, tone, age, bump}
var lines: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func push(weapon_id: String, label: String, amount: int, tone: Color) -> void:
	for line in lines:
		if str(line.weapon) == weapon_id and float(line.age) < LIFE * 0.7:
			line.amount = int(line.amount) + amount
			line.age = minf(float(line.age), 0.25)
			line.bump = 1.0
			return
	if lines.size() >= POOL:
		lines.pop_front()
	lines.append({"weapon": weapon_id, "label": label, "amount": amount, "tone": tone, "age": 0.0, "bump": 1.0})
	queue_redraw()


func active_count() -> int:
	return lines.size()


func text_of(index: int) -> String:
	if index < 0 or index >= lines.size():
		return ""
	return "+%d BLOOD // %s" % [int(lines[index].amount), str(lines[index].label)]


func _process(delta: float) -> void:
	if lines.is_empty():
		return
	for line in lines:
		line.age = float(line.age) + delta
		line.bump = maxf(0.0, float(line.bump) - delta * 5.0)
	var kept: Array[Dictionary] = []
	for line in lines:
		if float(line.age) < LIFE:
			kept.append(line)
	lines = kept
	queue_redraw()


func _draw() -> void:
	if lines.is_empty():
		return
	var origin := Vector2(size.x * 0.5 + 72.0, size.y * 0.5 + 84.0)
	var row := 0
	for index in range(lines.size() - 1, -1, -1):
		var line := lines[index]
		var age := float(line.age)
		var fade := clampf(age / 0.12, 0.0, 1.0) * clampf((LIFE - age) / 0.6, 0.0, 1.0)
		var rise := minf(age, 0.5) * 22.0
		var at := origin + Vector2(0.0, -row * LINE_GAP - rise)
		var tone := line.tone as Color
		var number := "+%d" % int(line.amount)
		var cap := 17.0 + 5.0 * float(line.bump)
		var number_width := CellOutzType.width(number, cap, 1.6)
		var tail := " BLOOD // %s" % str(line.label)
		var tail_width := CellOutzType.width(tail, 11.0, 1.1)
		draw_rect(Rect2(at + Vector2(-8.0, -4.0), Vector2(number_width + tail_width + 20.0, 30.0)), Color(0.02, 0.01, 0.01, 0.62 * fade))
		draw_rect(Rect2(at + Vector2(-8.0, -4.0), Vector2(3.0, 30.0)), tone * Color(1, 1, 1, fade))
		CellOutzType.draw_text(self, at + Vector2(0.0, 22.0 - cap), number, cap, tone * Color(1, 1, 1, fade), 1.6)
		CellOutzType.draw_text(self, at + Vector2(number_width + 2.0, 11.0), tail, 11.0, BONE * Color(1, 1, 1, fade), 1.1)
		row += 1
