extends Node

## A still weapon leaves nothing; a swung one leaves a trail that dies away.
## The lock ring fades in on a target and out without one.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var trail := StrikeTrail.new()
	add_child(trail)
	var dt := 1.0 / 60.0
	for i in 20:
		trail.feed(Vector3.ZERO, Vector3(0, 0, -1), dt, 0.5)
	check(not trail.active(), "holding still draws no trail")
	for i in 12:
		var a := float(i) * 0.25
		trail.feed(Vector3.ZERO, Vector3(sin(a), 0, -cos(a)), dt, 0.8)
	check(trail.active(), "a real swing leaves a trail")
	for i in 40:
		trail.feed(Vector3.ZERO, Vector3.ZERO, dt, 0.0, false)
	check(not trail.active(), "the trail dies once the weapon is gone")

	var model := Node3D.new()
	add_child(model)
	var blade := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 1.0)
	blade.mesh = box
	blade.position = Vector3(0, 0, -0.5)
	model.add_child(blade)
	check(trail.tip_local(model).z < -0.9, "the tip is measured at the far end of the blade")

	var ring := LockRing.new()
	add_child(ring)
	ring.follow(Vector3(1, 0, 1))
	for i in 30:
		ring._process(dt)
	check(ring.visible and is_equal_approx(ring.strength, 1.0), "locking raises the ring")
	ring.release()
	for i in 30:
		ring._process(dt)
	check(not ring.visible, "releasing lets it fade away")

	print("STRIKE_FX_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
