extends Control

## Every seam wipe, side by side, on real art. Keys 1–5 (or click a name) play
## one; SPACE replays; the scene swaps between two of Greg's plates under each
## wipe so the seam is visible.
##
## `-- --shots=DIR` writes each style at three points of its cover and quits:
##   Godot --path game res://prototype_lab/transition_gallery.tscn -- --shots=P:/GameDev/Temp/wipes

const PLATES := ["res://art/derived/splash_room.png", "res://art/derived/wire/collage_00.png"]
const INK := Color("e9d5c6")
const HOT := Color("e0442a")
const SHOT_POINTS := [0.35, 0.7, 1.0]

var kit: TransitionKit
var backdrop: TextureRect
var plate := 0
var playing := false
var _hot_rects: Array[Rect2] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture = load(PLATES[0])
	add_child(backdrop)
	var labels := Control.new()
	labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.draw.connect(_draw_labels.bind(labels))
	add_child(labels)
	kit = TransitionKit.new()
	add_child(kit)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			_shoot(argument.trim_prefix("--shots="))
			return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key >= KEY_1 and key < KEY_1 + TransitionKit.STYLES.size():
			play(key - KEY_1)
		elif key == KEY_SPACE:
			play(kit.style)
	elif event is InputEventMouseButton and event.pressed:
		var at := (event as InputEventMouseButton).position
		for i in _hot_rects.size():
			if _hot_rects[i].has_point(at):
				play(i)


func play(which: int) -> void:
	if playing:
		return
	playing = true
	kit.set_style(which)
	queue_redraw_labels()
	await kit.cover()
	plate = 1 - plate
	backdrop.texture = load(PLATES[plate])
	await get_tree().create_timer(0.12).timeout
	await kit.reveal()
	playing = false


func queue_redraw_labels() -> void:
	for child in get_children():
		if child is Control and child != backdrop:
			child.queue_redraw()


func _draw_labels(canvas: Control) -> void:
	_hot_rects.clear()
	var x := 36.0
	var y := canvas.size.y - 70.0
	CellOutzType.draw_text(canvas, Vector2(36, 32), "SEAM WIPES", 26.0, INK, 2.0)
	for i in TransitionKit.STYLES.size():
		var label := "%d %s" % [i + 1, str(TransitionKit.STYLES[i]).to_upper()]
		var colour := HOT if i == kit.style else INK
		var w := CellOutzType.draw_text(canvas, Vector2(x, y), label, 20.0, colour, 1.5)
		_hot_rects.append(Rect2(x - 6, y - 6, w + 12, 32))
		x += w + 40.0


func _shoot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().process_frame
	for i in TransitionKit.STYLES.size():
		kit.set_style(i)
		queue_redraw_labels()
		for point in SHOT_POINTS:
			kit.progress = point
			for _frame in 4:
				await get_tree().process_frame
			var image := get_viewport().get_texture().get_image()
			var path := "%s/%s_%02d.png" % [dir, TransitionKit.STYLES[i], int(point * 100)]
			image.save_png(path)
			print("SHOT %s" % path)
	get_tree().quit(0)
