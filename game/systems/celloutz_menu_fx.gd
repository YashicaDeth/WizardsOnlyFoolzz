extends Control

const COPPER := Color("ef652e")
const TEAL := Color("25aa9c")
const CREAM := Color("efd0a0")
var elapsed := 0.0
var nodes: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in 24:
		nodes.append({"phase": index * 0.48, "depth": float(index % 6) / 6.0, "side": -1.0 if index % 2 == 0 else 1.0})


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	if size.x < 400:
		return
	_draw_tree()
	_draw_title_signal()
	_draw_archive_nodes()
	_draw_footer()


func _draw_tree() -> void:
	var root := Vector2(size.x * 0.78, size.y * 0.84)
	var crown := Vector2(size.x * 0.78, size.y * 0.17)
	var pulse := 0.55 + sin(elapsed * 1.3) * 0.16
	draw_line(root, crown, COPPER * Color(1, 1, 1, pulse), 2.0)
	for level in 7:
		var t := float(level + 1) / 8.0
		var point := root.lerp(crown, t)
		var reach := 40.0 + level * 18.0
		for side in [-1.0, 1.0]:
			var end := point + Vector2(side * reach, -34.0 - level * 5.0)
			draw_line(point, end, TEAL * Color(1, 1, 1, 0.22 + t * 0.35), 1.5)
			draw_circle(end, 3.0 + sin(elapsed * 2.0 + level) * 1.0, COPPER * Color(1, 1, 1, 0.55))
			if level > 2:
				draw_line(end, end + Vector2(side * 24, -18), CREAM * Color(1, 1, 1, 0.17), 1.0)


func _draw_title_signal() -> void:
	var origin := Vector2(50, 155)
	var length := 280.0 + sin(elapsed * 1.6) * 36.0
	draw_line(origin, origin + Vector2(length, 0), COPPER * Color(1, 1, 1, 0.65), 2.0)
	draw_line(origin + Vector2(0, 7), origin + Vector2(length * 0.67, 7), TEAL * Color(1, 1, 1, 0.48), 1.0)
	var scan := fmod(elapsed * 85.0, length)
	draw_circle(origin + Vector2(scan, 0), 4.0, CREAM)


func _draw_archive_nodes() -> void:
	var center := Vector2(size.x * 0.76, size.y * 0.48)
	for item in nodes:
		var depth := float(item.depth)
		var phase := float(item.phase) + elapsed * (0.08 + depth * 0.12)
		var radius := 90.0 + depth * 230.0
		var point := center + Vector2(cos(phase) * radius, sin(phase) * radius * 0.48)
		var color := TEAL.lerp(COPPER, depth)
		draw_circle(point, 1.5 + depth * 3.0, color * Color(1, 1, 1, 0.16 + depth * 0.25))
		if depth > 0.65:
			draw_line(point, center.lerp(point, 0.82), color * Color(1, 1, 1, 0.09), 1.0)


func _draw_footer() -> void:
	var font := ThemeDB.fallback_font
	var y := size.y - 32.0
	draw_string(font, Vector2(48, y), "WORLD BUILD 0001 // EVERY ACTION LEAVES A WITNESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CREAM * Color(1, 1, 1, 0.56))
	for index in 9:
		var x := size.x - 210 + index * 18
		var height := 4.0 + sin(elapsed * 2.5 + index * 0.7) * 3.0
		draw_line(Vector2(x, y), Vector2(x, y - height), COPPER * Color(1, 1, 1, 0.5), 3.0)
