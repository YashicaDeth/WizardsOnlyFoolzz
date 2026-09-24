extends Node

## Phase 2 decision reel. Every candidate receives the same source page,
## destination page, 0.52-second movement and hold durations. This scene is
## evidence for Greg to choose from; it never changes the production fallback.

const HANDHELD := preload("res://systems/handheld_device.gd")
const FPS := 30

var slate: ColorRect
var slate_label: Label
var style_label: Label


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(path) != OK:
		push_error("CAPTURE_FAILED %s" % path)
	else:
		print("CAPTURED: ", path)


func _show_slate(title: String, detail: String) -> void:
	slate.visible = true
	slate_label.text = "%s\n\n%s" % [title, detail]
	style_label.visible = false


func _show_device(title: String) -> void:
	slate.visible = false
	style_label.text = title
	style_label.visible = true


func _reset_to_index(device: Control) -> void:
	device.pending_mode_index = -1
	device.page_transition = 1.0
	device.mode_index = 0
	device._activate_mode(0)
	device.queue_redraw()
	device._overlay.queue_redraw()


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "UNINDEXED CAPTIVE",
		"faction": "Unbound", "status": "contained",
		"memory": "The facility knew the body before the body knew itself.",
	})
	WorldHistory.register_subject("celloutz", {
		"name": "CELLOUTZ", "kind": "faction", "role": "Occult liability platform",
		"faction": "CellOutz", "status": "watching",
		"territory": "The Growing Floor",
	})

	var layer := CanvasLayer.new()
	add_child(layer)
	var device: Control = HANDHELD.new()
	layer.add_child(device)
	device.open_device()
	device.stand_at(Vector2(-150.0, 10.0))

	style_label = Label.new()
	style_label.position = Vector2(24, 14)
	style_label.add_theme_font_size_override("font_size", 18)
	style_label.add_theme_color_override("font_color", Color("e6d4ac"))
	layer.add_child(style_label)

	slate = ColorRect.new()
	slate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slate.color = Color("070a09")
	slate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(slate)
	slate_label = Label.new()
	slate_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slate_label.add_theme_font_size_override("font_size", 28)
	slate_label.add_theme_color_override("font_color", Color("e6d4ac"))
	slate.add_child(slate_label)

	await _frames(15)
	var candidates := [
		{"style": "shutter", "title": "01  MECHANICAL SHUTTER", "sound": "RATCHET + DIGITAL TEAR + CRACKED GLASS"},
		{"style": "corruption", "title": "02  CRACKED-GLASS CORRUPTION", "sound": "PACKET CHATTER + TORN DECODE + CRACKED GLASS"},
		{"style": "carousel", "title": "03  OCCULT CAROUSEL", "sound": "INDEXED WHEEL + DETUNED BELL + CRACKED GLASS"},
	]
	for candidate in candidates:
		var style := str(candidate.style)
		_show_slate(str(candidate.title), "%0.2f SECONDS // %s" % [device.PAGE_TRANSITION_SECONDS, str(candidate.sound)])
		await _frames(roundi(FPS * 0.9))
		_reset_to_index(device)
		device.set_page_transition_style(style)
		_show_device(str(candidate.title))
		await _frames(roundi(FPS * 0.35))
		device.set_mode("MAP")
		await _frames(roundi(FPS * device.PAGE_TRANSITION_SECONDS * 0.5))
		await _capture("res://captures/phase2_transition_%s.png" % style)
		await _frames(roundi(FPS * device.PAGE_TRANSITION_SECONDS * 0.5) + 1)
		await _frames(roundi(FPS * 0.65))

	_show_slate("NO SELECTION APPLIED", "PRODUCTION FALLBACK REMAINS THE TESTED MECHANICAL SHUTTER")
	await _frames(roundi(FPS * 1.1))
	get_tree().quit()
