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
	await get_tree().process_frame
	index_panel.open()
	# Rects are collected while painting, so the panel has to actually paint.
	for _frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
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
	await RenderingServer.frame_post_draw
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

	_finish()


func _finish() -> void:
	print("")
	if failures.is_empty():
		print("I5 v2 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
