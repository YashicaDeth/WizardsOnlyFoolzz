extends Node

## Greg, playing the 17:50 build: *"you walk to the end of this room and then
## there's just a skybox... I just fell out of the skybox."*
##
## The Growing Floor corridor was capped at the near end and open at the far
## one. Its floor runs to z = -34.6 with side walls the full length, but the
## only thing at the far end was the door slab — 3.4 units wide in a 16-unit
## corridor. Outside x +/-1.7 there was nothing, and walking past the door took
## the player off the edge of the world and out of the run.
##
## This walks the perimeter rather than trusting the geometry. A body is placed
## at each of several offsets across the corridor width, pushed hard at the far
## wall, and asked afterwards whether it is still standing on something. A test
## that only checked the centre line would have passed against the bug.

const SAMPLES := [-7.0, -5.0, -3.0, -1.0, 0.0, 1.0, 3.0, 5.0, 7.0]

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
	# The root is still adding this test during _ready; add_child would fail.
	await tree.process_frame
	var scene: Node = load("res://vat_chamber.tscn").instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene
	for _settle in 60:
		await tree.process_frame

	var aisle: float = scene.get("AISLE_LENGTH") if scene.get("AISLE_LENGTH") != null else 22.0
	var escaped := 0
	for x: float in SAMPLES:
		var probe := CharacterBody3D.new()
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.7
		shape.shape = capsule
		probe.add_child(shape)
		scene.add_child(probe)
		# Start close to the far end so 150 steps is comfortably enough to reach
		# and pass the edge; the first version started too far back and simply
		# never got there, which is why it passed with the wall removed.
		probe.global_position = Vector3(x, 1.2, -aisle + 2.0)
		var lowest := probe.global_position.y
		for _step in 240:
			# Real gravity, not a capped drift. The first version clamped the
			# vertical term at 0.0, so a probe that walked off the edge barely
			# fell and never tripped the threshold.
			probe.velocity.y -= 22.0 * (1.0 / 60.0)
			probe.velocity.x = 0.0
			probe.velocity.z = -7.0
			probe.move_and_slide()
			if probe.is_on_floor():
				probe.velocity.y = -0.5
			lowest = minf(lowest, probe.global_position.y)
			await tree.process_frame
		# The floor top sits at y = 0. Anything that ends up a metre below it,
		# or past the slab's own far edge, has left the world.
		var floor_far_edge := -(aisle * 0.4) - (aisle + 8.0) * 0.5
		var out_of_world := lowest < -1.0 or probe.global_position.z < floor_far_edge
		if out_of_world:
			escaped += 1
			print("   ESCAPED at x=%.1f -> pos %s lowest y %.2f" % [x, str(probe.global_position), lowest])
		probe.queue_free()
		await tree.process_frame

	check(escaped == 0, "no lane of the Growing Floor corridor lets you walk out of the world (%d/%d escaped)" % [escaped, SAMPLES.size()])

	if failures.is_empty():
		print("vat containment: sealed")
		tree.quit(0)
	else:
		print("vat containment FAILURES: ", failures)
		tree.quit(1)
