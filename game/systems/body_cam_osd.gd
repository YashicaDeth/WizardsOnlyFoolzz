class_name BodyCamOSD
extends Control

## The in-game HUD as body-cam footage (Greg, 24 September): a REC dot and a
## running timestamp, vitals as a thin readout, the objective as a stamped
## line, and prompts drawn as a key cap with the verb, placed near the thing
## in the world rather than as a sentence along the bottom.
##
## Additive: a scene keeps writing its own Vitals / Objective / Prompt labels
## exactly as before, and `adopt()` hides them and reads their text. The only
## new call a scene makes is `point_at()` while a prompt belongs to something
## you can see, so the key cap can sit beside it.

const INK := Color("e8e1d2")
const DIM := Color(0.91, 0.88, 0.82, 0.55)
const REC := Color("e0321e")
const STAMP := Color("e4a058")
const KEYCAP := Color(0.06, 0.05, 0.045, 0.82)

var camera: Camera3D
var location := ""
var vitals_source: Label
var objective_source: Label
var prompt_source: Label
var footage := 0.0
var _anchor := Vector3.ZERO
var _anchor_time := 0.0
var _anchor_frames := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Takes over a scene's plain HUD labels. They keep receiving text; they just
## stop drawing it.
func adopt(vitals: Label, objective: Label, prompt: Label, where: String) -> void:
	vitals_source = vitals
	objective_source = objective
	prompt_source = prompt
	location = where
	for label in [vitals, objective, prompt]:
		if label != null:
			label.self_modulate.a = 0.0


## The current prompt belongs to something at `world_point`. Held for a
## moment in time, not frames: scenes say it on their physics tick, and a
## display running faster than physics would otherwise drop the pin between
## ticks and flicker the key cap back to the bottom of the screen.
const ANCHOR_HOLD := 0.15


func point_at(world_point: Vector3) -> void:
	_anchor = world_point
	_anchor_time = ANCHOR_HOLD
	# And a few frames, for a machine so slow one frame outlasts the hold.
	_anchor_frames = 3


func _process(delta: float) -> void:
	footage += delta
	_anchor_time = maxf(0.0, _anchor_time - delta)
	_anchor_frames = maxi(0, _anchor_frames - 1)
	queue_redraw()


func _draw() -> void:
	var view := size
	_draw_frame(view)
	_draw_rec(view)
	_draw_objective(view)
	_draw_vitals(view)
	_draw_prompt(view)


## Thin corner brackets: the camera's own frame, not a border.
func _draw_frame(view: Vector2) -> void:
	var inset := 18.0
	var arm := 26.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := Vector2(lerpf(inset, view.x - inset, corner.x), lerpf(inset, view.y - inset, corner.y))
		var sx := 1.0 if corner.x == 0 else -1.0
		var sy := 1.0 if corner.y == 0 else -1.0
		draw_line(at, at + Vector2(arm * sx, 0), DIM, 1.0)
		draw_line(at, at + Vector2(0, arm * sy), DIM, 1.0)


func _draw_rec(view: Vector2) -> void:
	var at := Vector2(34, 30)
	if fmod(footage, 1.2) < 0.75:
		draw_circle(at + Vector2(5, 7), 5.0, REC)
	CellOutzType.draw_condensed(self, at + Vector2(16, 0), "REC", 14.0, INK, 0.8)
	var seconds := int(footage)
	var stamp := "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	CellOutzType.draw_condensed(self, at + Vector2(58, 0), stamp, 14.0, INK, 0.8)
	var minutes := WorldClock.minutes()
	var hour := int(minutes / 60.0) % 24
	var clock := "%02d:%02d" % [hour, int(minutes) % 60]
	var where := location if not location.is_empty() else "BODY CAM"
	CellOutzType.draw_condensed(self, at + Vector2(0, 20), "%s  //  %s" % [where, clock], 10.0, DIM, 0.7)


func _objective_text() -> String:
	if objective_source == null:
		return ""
	var text := objective_source.text.strip_edges()
	for prefix in ["OBJECTIVE //", "OBJECTIVE\n", "OBJECTIVE"]:
		if text.begins_with(prefix):
			text = text.trim_prefix(prefix).strip_edges()
	return text.replace("\n", "  ")


## Stamped: a copper box and heavy caps, the way the facility marks things.
func _draw_objective(view: Vector2) -> void:
	var text := _objective_text()
	if text.is_empty():
		return
	var width := CellOutzType.width_condensed(text, 15.0, 0.8) + 24.0
	var box := Rect2(Vector2(view.x - 34 - width, 26), Vector2(width, 32))
	draw_rect(box, Color(0.05, 0.03, 0.02, 0.55))
	draw_rect(box, STAMP * Color(1, 1, 1, 0.85), false, 1.5)
	CellOutzType.draw_condensed(self, box.position + Vector2(0, -12), "OBJECTIVE", 9.0, STAMP * Color(1, 1, 1, 0.8), 0.7)
	CellOutzType.draw_condensed(self, box.position + Vector2(12, 8), text, 15.0, STAMP, 0.8)


## "BLOOD 100%   PAIN 86   DECANTED" becomes a readout: a thin blood bar,
## the two numbers, and whatever status the scene appended.
func _draw_vitals(view: Vector2) -> void:
	if vitals_source == null:
		return
	var text := vitals_source.text
	var blood := -1
	var pain := -1
	var rest := text
	var blood_match := RegEx.create_from_string("BLOOD\\s+(\\d+)%").search(text)
	if blood_match != null:
		blood = int(blood_match.get_string(1))
		rest = rest.replace(blood_match.get_string(0), "")
	var pain_match := RegEx.create_from_string("PAIN\\s+(\\d+)").search(text)
	if pain_match != null:
		pain = int(pain_match.get_string(1))
		rest = rest.replace(pain_match.get_string(0), "")
	rest = rest.strip_edges()
	var at := Vector2(34, view.y - 56)
	if blood >= 0:
		CellOutzType.draw_condensed(self, at, "BLD %03d" % blood, 12.0, INK, 0.8)
		var bar := Rect2(at + Vector2(64, 4), Vector2(110, 5))
		draw_rect(bar, DIM * Color(1, 1, 1, 0.3))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(blood) / 100.0, 0.0, 1.0), bar.size.y)), REC)
	if pain >= 0:
		CellOutzType.draw_condensed(self, at + Vector2(188, 0), "PN %02d" % pain, 12.0, INK if pain < 70 else REC, 0.8)
	if not rest.is_empty():
		CellOutzType.draw_condensed(self, at + Vector2(0, 18), rest, 10.0, DIM, 0.7)


## A prompt is "[KEY] VERB", possibly several joined by "//". Key prompts
## become key caps; anything else (movement hints) stays a quiet line.
func _draw_prompt(view: Vector2) -> void:
	if prompt_source == null:
		return
	var text := prompt_source.text.strip_edges()
	if text.is_empty():
		return
	var actions: Array = []
	var hints: Array = []
	for part in text.split("//"):
		var piece := str(part).strip_edges()
		if piece.is_empty():
			continue
		if piece.begins_with("[") and piece.find("]") > 0:
			actions.append(piece)
		else:
			hints.append(piece)
	if actions.is_empty():
		var hint := "   //   ".join(hints)
		var width := CellOutzType.width_condensed(hint, 11.0, 0.8)
		CellOutzType.draw_condensed(self, Vector2((view.x - width) * 0.5, view.y - 44), hint, 11.0, DIM, 0.8)
		return
	var origin := Vector2(view.x * 0.5, view.y - 96)
	var pinned := false
	if (_anchor_time > 0.0 or _anchor_frames > 0) and camera != null and is_instance_valid(camera) and not camera.is_position_behind(_anchor):
		var projected := camera.unproject_position(_anchor)
		if Rect2(Vector2.ZERO, view).grow(-40).has_point(projected):
			origin = projected + Vector2(0, -34)
			pinned = true
			draw_line(projected, origin + Vector2(0, 14), DIM, 1.0)
			draw_circle(projected, 3.0, DIM)
	var line_y := origin.y - float(actions.size() - 1) * 36.0
	for action in actions:
		_draw_keycap(Vector2(origin.x, line_y), str(action), pinned)
		line_y += 36.0
	for hint in hints:
		var width := CellOutzType.width_condensed(str(hint), 10.0, 0.7)
		CellOutzType.draw_condensed(self, Vector2(origin.x - width * 0.5, line_y - 8), str(hint), 10.0, DIM, 0.7)
		line_y += 16.0


func _draw_keycap(centre: Vector2, action: String, pinned: bool) -> void:
	var close := action.find("]")
	var key := action.substr(1, close - 1)
	var verb := action.substr(close + 1).strip_edges()
	var key_width := maxf(26.0, CellOutzType.width_condensed(key, 13.0, 0.8) + 14.0)
	var verb_width := CellOutzType.width_condensed(verb, 13.0, 0.8)
	var total := key_width + 10.0 + verb_width
	var left := centre.x - total * 0.5
	var cap := Rect2(Vector2(left, centre.y - 13), Vector2(key_width, 26))
	# A key: a darker body with a lighter top face, like a real cap.
	draw_rect(cap, KEYCAP)
	draw_rect(Rect2(cap.position + Vector2(2, 2), cap.size - Vector2(4, 7)), Color(0.16, 0.14, 0.12, 0.95))
	draw_rect(cap, INK * Color(1, 1, 1, 0.8), false, 1.2)
	CellOutzType.draw_condensed(self, cap.position + Vector2((key_width - CellOutzType.width_condensed(key, 13.0, 0.8)) * 0.5, 4), key, 13.0, INK, 0.8)
	var verb_at := Vector2(cap.end.x + 10, centre.y - 8)
	draw_rect(Rect2(verb_at - Vector2(5, 3), Vector2(verb_width + 10, 22)), Color(0.03, 0.02, 0.02, 0.5 if pinned else 0.35))
	CellOutzType.draw_condensed(self, verb_at, verb, 13.0, INK, 0.8)
