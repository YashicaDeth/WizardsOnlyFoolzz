class_name MenuPlate
extends Control

## Greg: *"make the settings and contuine have design and ui instead of looking
## so lack luster"*.
##
## The front door's rows and the settings panel were Godot `Button`s carrying
## their own text, which means the engine's fallback UI font — the one face this
## project has a standing rule against, and exactly the "tutorial look" Greg
## keeps naming. Every other screen sets type with `CellOutzType`.
##
## It cannot be themed away. `CellOutzType` is procedural stroke glyphs drawn
## onto a CanvasItem, not a font resource, and there is no .ttf, .otf or .fnt
## anywhere in the project to point a theme at instead.
##
## So the controls keep the job and lose the looks: they still own hit testing,
## focus, the tweens and every signal, and this draws over them in the house
## type, reading each row's label and live rect off the control it belongs to.
## Nothing about operating either screen changes.

const INK := Color("dce6ba")
const HOT := Color("ff7138")
const ARTERIAL := Color("c81f16")

## The rows this plate speaks for. `Control` rather than `Button` because the
## settings panel's heading is a `Label`, and every property needed here —
## `text`, `size`, `global_position`, `modulate`, `visible` — both already have.
var rows: Array[Control] = []

## Compact rows for a panel rather than the front door's column.
var compact := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Takes a column over. The controls keep their own `text`, so anything that
## rewrites it at runtime — "BLOOM: ON" flipping to "BLOOM: OFF" — still works
## and this picks the new value up on the next frame. What they lose is the
## ability to *draw* it: the engine font is made transparent rather than the
## string being taken off them, which a snapshot would have gone stale against.
func adopt(controls: Array) -> void:
	rows.clear()
	var clear := Color(0, 0, 0, 0)
	for control in controls:
		if control == null or not is_instance_valid(control) or not (control is Control):
			continue
		rows.append(control as Control)
		for slot in ["font_color", "font_hover_color", "font_pressed_color",
				"font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			(control as Control).add_theme_color_override(slot, clear)
		# And the default grey plate behind them, which is the other half of why
		# the settings panel read as an engine dialog rather than as part of the
		# game. A fresh StyleBoxEmpty per slot: one shared instance assigned to
		# five slots on a dozen buttons is one resource every one of them then
		# holds a reference to.
		if control is Button:
			for slot in ["normal", "hover", "pressed", "focus", "disabled"]:
				(control as Button).add_theme_stylebox_override(slot, StyleBoxEmpty.new())
	queue_redraw()


func _process(_delta: float) -> void:
	# The rows slide on focus and their text changes under them, so the type has
	# to follow every frame rather than being placed once.
	queue_redraw()


func _draw() -> void:
	for control in rows:
		if control == null or not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var label := String(control.get("text"))
		if label.is_empty():
			continue
		# The control's own modulate carries both the focus tween and the cold
		# open's fade-in, so reading it here keeps one source of truth for what
		# is selected, and means the type arrives with its row rather than
		# sitting at full strength over a menu that has not appeared yet.
		var lit := control.modulate
		# `self_modulate` is how the title steps the other options back while
		# one is hovered; fold it in so the dim shows in the type.
		lit.a *= control.self_modulate.a
		if lit.a <= 0.01:
			continue
		# Into this plate's own space. `draw_*` is local, and the settings plate
		# is a child of the panel it speaks for rather than of the HUD root, so
		# taking global positions straight to the pen put the whole settings
		# column out on the right of the screen next to the sigil.
		var rect := Rect2(control.global_position - global_position, control.size)
		var focused := lit.r > 0.9 and lit.g < 0.6
		# A row you cannot press is a heading. Taking the distinction off the
		# node's own type keeps the hierarchy the engine labels used to carry —
		# the branch picker's title was 16pt and centred over 16pt rows, and
		# setting everything at one size flattened it into a list.
		var heading := not (control is Button)
		var cap := (11.0 if focused else 10.0) if compact else (17.0 if focused else 15.0)
		var room := rect.size.x - (28.0 if compact else 0.0)
		if heading:
			cap += 1.5
		# Set to the measure. A heading one and a half caps larger than its rows
		# is wider than the panel holding it, and ran out over the border —
		# `CellOutzType` has no wrapping and a Control will not clip it.
		var natural := CellOutzType.width(label, cap, 2.2)
		if natural > room and natural > 0.0 and room > 0.0:
			cap *= room / natural
		var tone := (HOT if focused else INK * Color(1, 1, 1, 0.72)) * Color(1, 1, 1, lit.a)
		if heading:
			tone = Color("e3a070") * Color(1, 1, 1, lit.a * 0.92)
		var inset := 14.0 if compact else 0.0
		if heading:
			inset = maxf(inset, (rect.size.x - CellOutzType.width(label, cap, 2.2)) * 0.5)
		var baseline := rect.position + Vector2(inset, (rect.size.y - cap) * 0.5)

		if focused:
			# A struck bar behind the live row, so selection is a thing on the
			# plate rather than a colour change you have to catch.
			var width := CellOutzType.width(label, cap, 2.2) + 26.0
			draw_rect(Rect2(baseline - Vector2(14.0, 7.0), Vector2(width, cap + 14.0)),
				ARTERIAL * Color(1, 1, 1, 0.13 * lit.a))
			draw_line(baseline + Vector2(-14.0, -7.0), baseline + Vector2(-14.0, cap + 7.0),
				ARTERIAL * Color(1, 1, 1, 0.9 * lit.a), 2.0)
			CellOutzType.draw_text(self, baseline + Vector2(1.5, 1.5), label, cap,
				Color(0, 0, 0, 0.55 * lit.a), 2.2)

		CellOutzType.draw_text(self, baseline, label, cap, tone, 2.2)
