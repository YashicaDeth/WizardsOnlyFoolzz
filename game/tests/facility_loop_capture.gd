extends Node

const FACILITY := preload("res://systems/facility_territory.gd")
const HANDHELD := preload("res://systems/handheld_device.gd")
const FPS := 30

var device: Control
var caption: Label


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


func _label(text: String) -> void:
	caption.text = text


func _open_map() -> void:
	device.pending_mode_index = -1
	device.mode_index = 1
	device._activate_mode(1)
	device._map.facility_sheet = true
	device._map.facility_selected = device._map._first_revealed_facility_sector()
	device.queue_redraw()


func _select_index_record(id: String) -> void:
	device.pending_mode_index = -1
	device.mode_index = 0
	device._activate_mode(0)
	device._index.page = 0
	device._index.refresh()
	for index in device._index._rail_cache.size():
		if str(device._index._rail_cache[index].id) == id:
			device._index.rail_index = index
			device._index.highlight_y = float(index)
			break
	device.queue_redraw()


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "UNINDEXED COMPANY ASSET",
		"faction": "Unbound", "status": "contained",
		"memory": "Decanted on the Growing Floor with a debt in the meat.",
	})
	WorldHistory.register_subject("celloutz", {
		"name": "CELLOUTZ", "kind": "faction", "role": "Occult liability platform",
		"faction": "CellOutz", "status": "watching",
	})
	FACILITY.apply_event("opening_woke")

	var layer := CanvasLayer.new()
	add_child(layer)
	device = HANDHELD.new()
	layer.add_child(device)
	device.open_device()
	_open_map()

	caption = Label.new()
	caption.position = Vector2(28, 18)
	caption.size = Vector2(1224, 60)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 19)
	caption.add_theme_color_override("font_color", Color("f2d7ad"))
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(caption)

	_label("THE GROWING FLOOR // ONE KNOWN ROOM, THREE REDACTED HOLDINGS")
	await _frames(FPS * 2)
	FACILITY.apply_event("opening_entered_pit")
	_open_map()
	_label("INTO THE PIT // ROUTES AND SURVEILLANCE RESOLVE AS THEY ARE WALKED")
	await _frames(FPS * 2)
	FACILITY.apply_event("derby_round_won")
	_open_map()
	device._map.facility_selected = 1
	_label("HEAT WON // THE UNDERGROUND COLOSSEUM CHANGES HANDS")
	await _frames(FPS * 2)
	await _capture("res://captures/phase3_facility_liberated.png")

	_select_index_record("facility:underground_colosseum")
	_label("INDEX UNLOCKED // THE MAP'S HOLDING BECOMES A RECOVERED FILE")
	await _frames(FPS * 2)
	await _capture("res://captures/phase3_facility_index.png")

	_open_map()
	var saved := WorldHistory.snapshot()
	_label("CELLOUTZ RESPONSE // REPOSSESSION ORDER 0C-7 CIRCULATING")
	await _frames(FPS * 2)
	WorldHistory.clear_history()
	FACILITY.ensure()
	device._map.facility_selected = 1
	_label("NEW BRANCH // THE PIT IS CORPORATE-CONTROLLED AGAIN")
	await _frames(FPS * 2)
	WorldHistory.restore_snapshot(saved)
	device._map.facility_sheet = true
	device._map.facility_selected = 1
	_label("BRANCH RELOADED // LIBERATION, FILE AND BOUNTY RETURN TOGETHER")
	await _frames(FPS * 2)
	await _capture("res://captures/phase3_facility_reloaded.png")
	get_tree().quit()
