class_name LockReadout
extends Control

## What you are fighting, read off their body — never a health bar (FINAL_V
## law 1: one anatomical truth). Over whoever you are locked on to floats a
## small X-ray figure: six zones tinted from intact bone to arterial red by
## their real remaining health, struck through when gone, the critical ones
## (head, torso) outlined. You see that their left arm is finished and their
## head is one blow away, which is a decision; a bar is only a number.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const BONE := Color("ead4ad")
const ARTERIAL := Color("c81f16")
const SCAN := Color("35b7a7")

## Where each zone sits on the little figure, in figure units (1 = 28 px).
const PLAN := {
	"head": Vector2(0, -1.55), "torso": Vector2(0, -0.35),
	"left_arm": Vector2(-0.75, -0.35), "right_arm": Vector2(0.75, -0.35),
	"left_leg": Vector2(-0.3, 1.0), "right_leg": Vector2(0.3, 1.0),
}

var shown := false
var subject_name := ""
var ratios: Dictionary = {}
var _anchor := Vector2.ZERO
var _fade := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## `zones` is an AnatomyComponent-style dictionary: zone -> {"health": n}.
func show_for(screen_point: Vector2, display_name: String, zones: Dictionary, defaults: Dictionary) -> void:
	shown = true
	_anchor = screen_point
	subject_name = display_name
	ratios.clear()
	for zone_id in PLAN:
		var ceiling := float((defaults.get(zone_id, {"health": 1.0}) as Dictionary).get("health", 1.0))
		var current := float((zones.get(zone_id, {"health": ceiling}) as Dictionary).get("health", ceiling))
		ratios[zone_id] = clampf(current / maxf(ceiling, 1.0), 0.0, 1.0)


func hide_readout() -> void:
	shown = false


func zone_ratio(zone_id: String) -> float:
	return float(ratios.get(zone_id, 1.0))


func _process(delta: float) -> void:
	_fade = move_toward(_fade, 1.0 if shown else 0.0, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	if _fade <= 0.001:
		return
	var unit := 28.0
	var at := _anchor + Vector2(0, -unit * 2.4)
	var a := _fade
	for zone_id in PLAN:
		var r := zone_ratio(zone_id)
		var centre: Vector2 = at + (PLAN[zone_id] as Vector2) * unit
		var tone := SCAN.lerp(ARTERIAL, 1.0 - r)
		var rect := _zone_rect(zone_id, centre, unit)
		draw_rect(rect, Color(0.02, 0.02, 0.02, 0.55 * a))
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * (1.0 - r)), Vector2(rect.size.x, rect.size.y * r)), tone * Color(1, 1, 1, 0.75 * a))
		var critical: bool = zone_id in ["head", "torso"]
		draw_rect(rect, (BONE if critical else BONE * Color(1, 1, 1, 0.5)) * Color(1, 1, 1, a), false, 1.6 if critical else 1.0)
		if r <= 0.001:
			draw_line(rect.position, rect.end, ARTERIAL * Color(1, 1, 1, a), 2.0)
			draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), ARTERIAL * Color(1, 1, 1, a), 2.0)
	var label := subject_name.to_upper()
	var width := CellOutzType.width_condensed(label, 8.0, 0.8)
	CellOutzType.draw_condensed(self, at + Vector2(-width * 0.5, unit * 1.75), label, 8.0, BONE * Color(1, 1, 1, 0.8 * a), 0.8)


func _zone_rect(zone_id: String, centre: Vector2, unit: float) -> Rect2:
	var size := Vector2(0.55, 0.55)
	match zone_id:
		"torso":
			size = Vector2(0.8, 1.2)
		"left_arm", "right_arm":
			size = Vector2(0.28, 1.1)
		"left_leg", "right_leg":
			size = Vector2(0.32, 1.2)
	return Rect2(centre - size * unit * 0.5, size * unit)
