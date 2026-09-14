extends Node

## AF10.1. "A round travels, drops, slows and cannot tunnel." Drop and slow
## are already proven in `ballistics_test.gd`; tunnelling is the one nobody
## ever forced. `_step_rounds()` traces the whole segment a round crosses in
## a step (`was` to `at`), not just where it lands — so it cannot miss
## geometry that lay anywhere along the way, however far that step was.
##
## The only way to actually exercise that is to make the step itself absurd:
## one second of flight in a single call, hundreds of metres for a rifle
## round. A version of this that only checked the destination point would
## sail straight through a wall sitting in the middle of that jump and see
## nothing at all. Calling `_step_rounds()` directly, once, with that huge
## delta is the whole point — waiting out real physics frames could only
## ever prove the ordinary case, at a plausible delta, which nobody doubted.

const BALLISTICS := preload("res://systems/ballistics.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	await tree.process_frame

	var world := Node3D.new()
	tree.root.add_child(world)
	tree.current_scene = world

	# A pane, not a bunker: two centimetres, five metres out. The claim is
	# about tracing, not thickness — the thinnest real wall still has to
	# stop a round that jumped hundreds of metres past it.
	var wall_at := Vector3(0, 5, -5)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 20, 0.02)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.global_position = wall_at

	var guns: Ballistics = BALLISTICS.new()
	world.add_child(guns)
	var hits: Array = []
	guns.round_hit.connect(func(hit: Dictionary) -> void: hits.append(hit))
	await tree.physics_frame

	guns.fire(Vector3(0, 5, 0), Vector3.FORWARD, "rifle", 0.0, 1, "player")
	check(guns.rounds.size() == 1, "a round is in flight, at the muzzle")

	# One second at a rifle's muzzle velocity is on the order of 780 metres —
	# past the wall, past MAX_RANGE, past everything — taken in a single
	# manual step rather than however many real physics frames that would
	# actually take.
	guns._step_rounds(1.0)
	check(hits.size() == 1, "the pane five metres out still stops a round that jumped hundreds of metres in one step")
	if hits.size() == 1:
		var landed_at: Vector3 = hits[0].get("position", Vector3.ZERO)
		check(landed_at.distance_to(wall_at) < 0.5, "and it lands where the wall actually is, not somewhere along the long jump (%s)" % landed_at)
	check(guns.rounds.is_empty(), "the round is retired at the wall rather than continuing past it")

	if failures.is_empty():
		print("tunnelling: a segment trace cannot skip a wall, no matter how big the step")
		tree.quit(0)
	else:
		print("tunnel FAILURES: ", failures)
		tree.quit(1)
