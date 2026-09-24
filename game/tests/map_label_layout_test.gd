extends Node

const MAP := preload("res://systems/living_map.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var map := MAP.new()
	add_child(map)
	map._chart = Rect2(40, 30, 920, 500)
	map._map_label_rects.clear()
	var choices := [Vector2(10, -16), Vector2(10, 9), Vector2(-130, -16), Vector2(-130, 9)]
	map._reserve_map_label(Vector2(500, 260), Vector2(120, 13), choices)
	map._reserve_map_label(Vector2(500, 260), Vector2(120, 13), choices)
	map._reserve_map_label(Vector2(500, 260), Vector2(120, 13), choices)
	check(map._map_label_rects.size() == 3, "districts, objectives and contacts share one reservation list")
	var clear := true
	for first in map._map_label_rects.size():
		for second in range(first + 1, map._map_label_rects.size()):
			if (map._map_label_rects[first] as Rect2).intersects(map._map_label_rects[second] as Rect2):
				clear = false
	check(clear, "three labels at one world coordinate choose distinct authored registers")
	map._map_label_rects.clear()
	var at: Vector2 = map._reserve_map_label(Vector2(-100, -100), Vector2(180, 20), [Vector2.ZERO])
	check(at.x >= map._chart.position.x and at.y >= map._chart.position.y, "a displaced label remains clamped inside the physical chart")
	print("MAP_LABEL_LAYOUT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
