extends Node

## E2.1/E2.4 verification. `seal_strokes` is the testable core underneath
## every `draw_seal*` variant — the drawing calls themselves only run inside
## `_draw()`, so this exercises the geometry they all scale and place.

const CellOutzType := preload("res://systems/celloutz_type.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _flatten(strokes: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for stroke: PackedVector2Array in strokes:
		out.append_array(stroke)
	return out


func _ready() -> void:
	var a := CellOutzType.seal_strokes(9)
	var b := CellOutzType.seal_strokes(9)
	check(a.size() == b.size(), "the same seed produces the same number of strokes")
	var same_points := true
	for index in a.size():
		var stroke_a: PackedVector2Array = a[index]
		var stroke_b: PackedVector2Array = b[index]
		if stroke_a.size() != stroke_b.size():
			same_points = false
			break
		for point_index in stroke_a.size():
			if not stroke_a[point_index].is_equal_approx(stroke_b[point_index]):
				same_points = false
				break
	check(same_points, "a seal is deterministic from its seed, point for point")

	var different_seeds_differ := false
	var reference := _flatten(CellOutzType.seal_strokes(1))
	for seed_value in [2, 3, 4, 5]:
		var candidate := _flatten(CellOutzType.seal_strokes(seed_value))
		if candidate.size() != reference.size():
			different_seeds_differ = true
			break
		for index in candidate.size():
			if not candidate[index].is_equal_approx(reference[index]):
				different_seeds_differ = true
				break
		if different_seeds_differ:
			break
	check(different_seeds_differ, "different seeds actually produce different seals, not one shape relabelled")

	var within_bounds := true
	var has_ring := false
	for seed_value in range(20):
		var strokes := CellOutzType.seal_strokes(seed_value)
		if strokes.size() > 0 and (strokes[0] as PackedVector2Array).size() > 20:
			has_ring = true
		for stroke: PackedVector2Array in strokes:
			for point: Vector2 in stroke:
				if point.length() > 1.35:
					within_bounds = false
	check(has_ring, "every seal is built on a containment ring")
	check(within_bounds, "seal geometry stays close to the unit circle it will be scaled against")

	var goetia_and_original_resolve := true
	for entry: Dictionary in GoeticSeals.GOETIA:
		var strokes := CellOutzType.seal_strokes(int(entry.number))
		if strokes.is_empty():
			goetia_and_original_resolve = false
			break
	for entry: Dictionary in GoeticSeals.ORIGINAL:
		var strokes := CellOutzType.seal_strokes(hash(str(entry.id)))
		if strokes.is_empty():
			goetia_and_original_resolve = false
			break
	check(goetia_and_original_resolve, "every seal in GoeticSeals — Goetic number or original id — draws something")

	print("SEAL_DRAW_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
