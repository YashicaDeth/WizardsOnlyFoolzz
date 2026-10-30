extends Node

## I5 `v2`. The rail was arrow-keys-only. Every row was drawn and none of them
## was ever a target, so a list of forty people could only be reached by holding
## Down — Greg: "make it clickable its just too restrictive".

const INDEX := preload("res://systems/world_index.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("I5 v2 - the rail is pointable")
	WorldHistory.clear_history()
	for index in 6:
		WorldHistory.register_subject("body_%d" % index, {
			"name": "Subject %02d" % index, "kind": "person", "role": "Ashline hand",
		})

	var layer := CanvasLayer.new()
	add_child(layer)
	var index_panel: Control = INDEX.new()
	layer.add_child(index_panel)
	# The panel lays itself out against its own size, falling back to the
	# viewport. Headless reports a 64x64 viewport, which is under the 640x400
	# floor the layout refuses to draw below, so the suite passed only on a
	# machine with a real window and silently proved nothing anywhere else.
	# Give it the design resolution instead of inheriting the host's.
	index_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	index_panel.size = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	await get_tree().process_frame
	index_panel.open()
	# Rects are collected while painting, so the panel has to actually paint.
	# No paint needed: the rail's hit areas come from `_process`, so a few frames
	# are enough. The old wait on `RenderingServer.frame_post_draw` never returned
	# under `--headless` and turned this suite into a 200s timeout.
	for _frame in 6:
		await get_tree().process_frame

	var rects: Array = index_panel.get("_rail_rects")
	_check(rects.size() > 0, "the rail collects a hit area per visible row (%d)" % rects.size())
	if rects.is_empty():
		_finish()
		return

	# Every row is a real, non-empty target somewhere on screen.
	var sane := true
	for row in rects:
		var r: Rect2 = row["rect"]
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			sane = false
	_check(sane, "every hit area has a real size")

	# Clicking a row selects it.
	var target: Dictionary = rects[mini(2, rects.size() - 1)]
	var before: int = index_panel.get("rail_index")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (target["rect"] as Rect2).get_center()
	index_panel._unhandled_input(click)
	_check(int(index_panel.get("rail_index")) == int(target["index"]), "clicking a row selects it (%d -> %d)" % [before, int(index_panel.get("rail_index"))])

	# Selecting scrolls the rail, so the hit areas move. Re-read them after the
	# repaint rather than hovering coordinates that have gone stale — which is
	# also exactly what a real pointer does.
	for _frame in 4:
		await get_tree().process_frame
	rects = index_panel.get("_rail_rects")

	# Hovering marks it without selecting it.
	var other: Dictionary = rects[0] if int(rects[0]["index"]) != int(target["index"]) else rects[1]
	var selected_now: int = index_panel.get("rail_index")
	var motion := InputEventMouseMotion.new()
	motion.position = (other["rect"] as Rect2).get_center()
	index_panel._unhandled_input(motion)
	_check(int(index_panel.get("rail_hover")) == int(other["index"]), "hovering a row marks it")
	_check(int(index_panel.get("rail_index")) == selected_now, "and hovering never changes what is selected")

	# Off the rail, nothing is hovered.
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-500, -500)
	index_panel._unhandled_input(away)
	_check(int(index_panel.get("rail_hover")) == -1, "moving off the rail clears the hover")

	# Slice 8. Local work used to be readable only on the FILE page of the place
	# that posted it. WORK is where a player looks for work, so it lists them.
	AshbloomHoldings.ensure()
	WorldHistory.amend_subject("ashbloom:bone_yard", {"revealed": true})
	AshbloomHoldings.work_orders("bone_yard")
	var expected := 0
	for definition: Dictionary in AshbloomHoldings.DEFINITIONS:
		if bool(WorldHistory.subject(str(definition["record"])).get("revealed", false)):
			expected += AshbloomHoldings.work_orders(str(definition["id"])).size()
	var lines: Array = index_panel.local_work_lines()
	_check(expected > 0, "a revealed holding posts real local work (%d orders)" % expected)
	_check(lines.size() == expected, "the WORK page lists every posted order (%d of %d)" % [lines.size(), expected])
	var complete := not lines.is_empty()
	for line: Dictionary in lines:
		if ["name", "place", "status", "progress"].any(func(key: String) -> bool: return str(line.get(key, "")).is_empty()):
			complete = false
	_check(complete, "every row names its order, its place, its state and the claim it presses on")

	_finish()


func _finish() -> void:
	print("")
	if failures.is_empty():
		print("I5 v2 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	# The runner reads `<NAME>_RESULT failures=N`; without it this suite reported
	# "(no marker)" even when it passed, which reads exactly like a suite that
	# proved nothing.
	print("RAIL_CLICK_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
