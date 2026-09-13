extends Node

## B9.1/B9.2. The reflection maths, which is the only part of a mirror that can
## be wrong in a way a screenshot will not show you — a body standing at the
## wrong depth still looks like a body, and a gaze reflected with the point
## formula instead of the direction one is correct dead centre and wrong
## everywhere else.

const BODY_MIRROR := preload("res://systems/body_mirror.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("B9.1 / B9.2 - the mirror on the wall")

	# A mirror on the wall at z = 0, glass facing into the room along +Z.
	var origin := Vector3.ZERO
	var normal := Vector3(0, 0, 1)

	# --- points ------------------------------------------------------------
	var standing := Vector3(0.4, 1.68, 2.0)
	var reflected: Vector3 = BODY_MIRROR.reflect_point(origin, normal, standing)
	_check(is_equal_approx(reflected.z, -2.0), "somebody two metres in front reflects to two metres behind (%.2f)" % reflected.z)
	_check(is_equal_approx(reflected.x, 0.4) and is_equal_approx(reflected.y, 1.68), "and does not move sideways or change height")

	var on_glass := Vector3(0.2, 1.5, 0.0)
	_check(BODY_MIRROR.reflect_point(origin, normal, on_glass).is_equal_approx(on_glass), "a point on the glass is its own reflection")

	var twice: Vector3 = BODY_MIRROR.reflect_point(origin, normal, reflected)
	_check(twice.is_equal_approx(standing), "reflecting twice returns the original - the operation is its own inverse")

	# An off-origin, off-axis plane, because a mirror that only works on a plane
	# through zero is a mirror that works in the test and nowhere else.
	var tilted_origin := Vector3(1.0, 0.0, -3.0)
	var tilted_normal := Vector3(1, 0, 1)
	var p := Vector3(4.0, 1.0, 0.5)
	var r: Vector3 = BODY_MIRROR.reflect_point(tilted_origin, tilted_normal, p)
	_check(BODY_MIRROR.reflect_point(tilted_origin, tilted_normal, r).is_equal_approx(p), "still its own inverse on a tilted plane off the origin")
	var unit := tilted_normal.normalized()
	_check(is_equal_approx(unit.dot(p - tilted_origin), -unit.dot(r - tilted_origin)), "the distance to the plane is preserved and the side is swapped")
	var midpoint := (p + r) * 0.5
	_check(absf(unit.dot(midpoint - tilted_origin)) < 0.0001, "and the halfway point lies on the glass")

	# --- directions --------------------------------------------------------
	# The failure this catches: using the point formula on a look vector. It
	# happens to agree when the plane passes through the origin, which is why it
	# survives a casual test and then breaks every mirror not at world zero.
	var gaze := Vector3(0, 0, -1)
	var bounced: Vector3 = BODY_MIRROR.reflect_direction(tilted_normal, gaze)
	_check(is_equal_approx(bounced.length(), gaze.length()), "reflecting a direction preserves its length")
	var wrong: Vector3 = BODY_MIRROR.reflect_point(tilted_origin, tilted_normal, gaze)
	_check(not bounced.is_equal_approx(wrong), "and is not the same answer the point formula gives on an off-origin plane")

	var along := tilted_normal.normalized()
	_check(BODY_MIRROR.reflect_direction(tilted_normal, along).is_equal_approx(-along), "a direction straight at the glass comes straight back")
	var across := along.cross(Vector3.UP).normalized()
	_check(BODY_MIRROR.reflect_direction(tilted_normal, across).is_equal_approx(across), "a direction along the glass is unchanged")

	# --- the camera placement ----------------------------------------------
	var world := World3D.new()
	var mirror: SubViewport = BODY_MIRROR.make(world, Vector2i(64, 64))
	add_child(mirror)
	mirror.call("place", origin, normal)
	_check(mirror.render_target_update_mode == SubViewport.UPDATE_DISABLED, "a mirror renders nothing until somebody asks")

	var viewer := Transform3D(Basis(), Vector3(0.0, 1.68, 2.5))
	mirror.call("reflect", viewer)
	var eye: Vector3 = mirror.camera.global_position
	_check(is_equal_approx(eye.z, -2.5), "the camera stands where the reflection stands (%.2f)" % eye.z)
	_check(is_equal_approx(eye.y, 1.68), "at the viewer's own eye height, so the body is met level and not looked down on")
	_check(is_equal_approx(float(mirror.call("distance_from", viewer.origin)), 2.5), "and the room can ask how far off the glass the viewer is")

	mirror.call("live")
	_check(mirror.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "a mirror in the room the player is standing in runs live")
	mirror.call("sleep")
	_check(mirror.render_target_update_mode == SubViewport.UPDATE_DISABLED, "and stops the moment they leave")

	print("")
	if failures.is_empty():
		print("B9 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
