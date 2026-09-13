class_name MenuPlate
extends Control

## Greg: *"make the settings and contuine have design and ui instead of looking
## so lack luster"*.
##
## The front door's rows were Godot `Button`s carrying their own text, which
## means the engine's fallback UI font — the one thing this project has a
## standing rule against, and the exact "tutorial look" Greg keeps pointing at.
## Every other screen sets its type with `CellOutzType`, which is procedural
## stroke glyphs drawn onto a canvas rather than a font resource, so a `Button`
## cannot be told to use it and there is no .ttf anywhere in the project to fall
## back on instead.
##
## So the buttons keep their job and lose their looks: they still own hit
## testing, focus, the signal wiring and the slide tween, and their own `text` is
## blanked. This draws over them in the house type, reading each row's label and
## live rect off the button it belongs to, so nothing about navigating the menu
## changes and all of it is set in the right face.

const INK := Color("dce6ba")
const HOT := Color("ff7138")
const ARTERIAL := Color("c81f16")

## Rows, as {button, label}. The label is lifted off the button at adopt time so
## the button can be blanked without losing what it said.
var rows: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Takes the column over. Called once, after the buttons exist.
func adopt(buttons: Array) -> void:
	rows.clear()
	for button in buttons:
		if button == null or not is_instance_valid(button):
			continue
		rows.append({"button": button, "label": String(button.text)})
		# Blanked, not hidden: a hidden Button stops taking the mouse, and the
		# whole point is that it keeps doing that.
		button.text = ""
	queue_redraw()


func _process(_delta: float) -> void:
	# The rows slide on focus, so the type has to follow them every frame rather
	# than being placed once.
	queue_redraw()


func _draw() -> void:
	for row in rows:
		var button: Button = row["button"]
		if button == null or not is_instance_valid(button) or not button.visible:
			continue
		var label := str(row["label"])
		if label.is_empty():
			continue
		var rect := Rect2(button.global_position, button.size)
		# The button's own modulate carries both the focus tween and the cold
		# open's fade-in, so reading it here keeps one source of truth for what
		# is selected and means the type arrives with the row rather than
		# sitting at full strength over a menu that has not appeared yet.
		var lit := button.modulate
		if lit.a <= 0.01:
			continue
		var focused := lit.r > 0.9 and lit.g < 0.6
		var cap := 17.0 if focused else 15.0
		var tone := (HOT if focused else INK * Color(1, 1, 1, 0.72)) * Color(1, 1, 1, lit.a)
		var baseline := rect.position + Vector2(0.0, (rect.size.y - cap) * 0.5)

		if focused:
			# A struck bar behind the live row, so selection is a thing on the
			# plate rather than a colour change you have to notice.
			var width := CellOutzType.width(label, cap, 2.2) + 26.0
			draw_rect(Rect2(baseline - Vector2(14.0, 7.0), Vector2(width, cap + 14.0)),
				ARTERIAL * Color(1, 1, 1, 0.13 * lit.a))
			draw_line(baseline + Vector2(-14.0, -7.0), baseline + Vector2(-14.0, cap + 7.0),
				ARTERIAL * Color(1, 1, 1, 0.9 * lit.a), 2.0)
			CellOutzType.draw_text(self, baseline + Vector2(1.5, 1.5), label, cap,
				Color(0, 0, 0, 0.55 * lit.a), 2.2)

		CellOutzType.draw_text(self, baseline, label, cap, tone, 2.2)
