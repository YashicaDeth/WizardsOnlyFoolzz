extends Node

## Greg, 30 September: "you should be able to fight 1v1 and it's not just
## they all rush to kill you and merge into each other", "or instead of take
## turns there more space in between". J switches the two: a duel, or the
## pack spread out. Neither lets two bodies stand inside each other.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _standing(demo) -> Array:
	var out: Array = []
	for index in demo.bodies.size():
		if demo._can_duel(index):
			out.append(index)
	return out


func _gap_to_eye(demo, index: int) -> float:
	var holder := demo.bodies[index].holder as Node3D
	return Vector2(holder.global_position.x - demo.eye.x, holder.global_position.z - demo.eye.z).length()


func _closest_pair(demo) -> float:
	var standing := _standing(demo)
	var best := INF
	for i in standing.size():
		for j in range(i + 1, standing.size()):
			var a := (demo.bodies[standing[i]].holder as Node3D).global_position
			var b := (demo.bodies[standing[j]].holder as Node3D).global_position
			best = minf(best, Vector2(a.x - b.x, a.z - b.z).length())
	return best


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await _frames(3)
	demo.spar_level = 0
	demo._set_enemies_enabled(true)

	# --- Duel: one comes, the rest wait in the ring. ---
	check(demo.duel_mode, "the sandbox opens on the duel")
	var closest := INF
	for _second in 8:
		demo.simulation_health = 100
		await _frames(60)
		closest = minf(closest, _closest_pair(demo))
	var near := 0
	var waiting := 0
	for index in _standing(demo):
		var gap := _gap_to_eye(demo, index)
		if gap < 3.5:
			near += 1
		elif gap > 3.9 and gap < 6.5:
			waiting += 1
	# The duelist circles at CIRCLE_RADIUS between blows, stepping in to strike.
	check(near == 1, "one body is engaging you (%d)" % near)
	check(waiting == _standing(demo).size() - 1, "every other one waits in the ring (%d of %d)" % [waiting, _standing(demo).size() - 1])
	check(closest >= demo.BODY_SPACING - 0.05, "no two bodies inside each other (closest %.2f m)" % closest)

	# --- The duelist drops: the next steps in. ---
	var first: int = demo.duelist
	demo.bodies[first].rig.anatomy.finish("test")
	await _frames(180)
	check(demo.duelist >= 0 and demo.duelist != first and _gap_to_eye(demo, demo.duelist) < 3.5, "the next one steps in")

	# --- Pack: all of them, spread out. ---
	demo._unhandled_input(_key(KEY_J))
	check(not demo.duel_mode, "J switches to the pack")
	closest = INF
	for _second in 8:
		demo.simulation_health = 100
		await _frames(60)
		closest = minf(closest, _closest_pair(demo))
	near = 0
	for index in _standing(demo):
		if _gap_to_eye(demo, index) < 3.6:
			near += 1
	check(near >= 3, "the pack closes in together (%d near)" % near)
	check(closest >= demo.PACK_SPACING - 0.1, "spread out: no two closer than %.1f m (closest %.2f m)" % [demo.PACK_SPACING, closest])

	# --- The rhythm: it circles between blows, steps in, and strikes. ---
	demo.duel_mode = true
	demo.duelist = -1
	demo.simulation_health = 100
	var closest_in := INF
	var farthest := 0.0
	for _i in 360:
		await get_tree().physics_frame
		if demo.duelist >= 0:
			var gap := _gap_to_eye(demo, demo.duelist)
			closest_in = minf(closest_in, gap)
			farthest = maxf(farthest, gap)
		demo.simulation_health = maxi(demo.simulation_health, 50)
	check(closest_in < 1.7 and farthest > 2.4, "the duelist steps in to strike and backs out to circle (%.2f to %.2f m)" % [closest_in, farthest])

	print("SANDBOX_DUEL_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
