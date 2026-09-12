extends Node

## E2.4/E2.5. The motherboard Greg asked for: a real procedural board (base,
## routed copper, a chip with pins, capacitors) that a seal actually burns
## into or binds onto, using the exact same `CellOutzType.seal_strokes()`
## geometry the 2D ritual app already draws rather than a second shape
## invented for 3D.

const MOTHERBOARD := preload("res://systems/motherboard.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var board: Node3D = MOTHERBOARD.new()
	add_child(board)
	await get_tree().process_frame

	print("E2.5 - the board is a real, populated board")
	var static_children: int = board.get_node("Static").get_child_count()
	_check(static_children > 20, "the base carries real routed copper, a chip and pins rather than a bare plate (%d parts)" % static_children)

	print("E2.4 - binding grows the seal additively, in construction order")
	_check(not board.is_animating(), "nothing is running before a rite happens")
	board.begin_bind(1234, 6, 1.0)
	_check(board.is_animating(), "beginning a bind starts the animation")
	board._process(0.5)
	_check(board.is_animating(), "and it is still running at the halfway point")
	board._process(0.6)
	_check(not board.is_animating(), "and finishes on its own once the duration elapses")
	_check(board.bound_seals.size() == 1, "the bind is recorded as a permanent mark on this board")
	_check(board.bound_seals[0].seed == 1234, "carrying the same seed the seal was actually drawn from")
	_check(board.burnt_seals.is_empty(), "and it did not also register as a burn")

	print("E2.4 - burning consumes the seal subtractively, from a front")
	board.begin_burn(5678, 6, 1.0, 0.4)
	_check(board.is_animating(), "beginning a burn starts the animation")
	board._process(1.1)
	_check(not board.is_animating(), "and finishes on its own")
	_check(board.burnt_seals.size() == 1, "the burn is recorded as a permanent scar")
	_check(board.bound_seals.size() == 1, "which is separate from the earlier bind - this board now carries both")

	print("E2.4 - the same seal geometry the 2D ritual app already draws")
	var CellOutzType := preload("res://systems/celloutz_type.gd")
	var strokes: Array = CellOutzType.seal_strokes(1234, 6)
	var points_3d: PackedVector3Array = board._stroke_points_3d(strokes[0])
	_check(points_3d.size() == (strokes[0] as PackedVector2Array).size(), "every 2D point in a stroke becomes one 3D point on the board")
	_check(points_3d[0].y > 0.0, "sitting above the board's own surface rather than buried in it")

	print("MOTHERBOARD_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
