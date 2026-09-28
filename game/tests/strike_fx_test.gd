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

	# The real arsenal mount: a `<id>_model` plus the gripping hand, with a long
	# forearm rod attached under the hand at runtime. The tip must be the
	# blade's, not the rod's -- measuring the whole mount drew the trail
	# nowhere near the blade in the Hunt.
	var mount := Node3D.new()
	add_child(mount)
	var sword := Node3D.new()
	sword.name = "sword_model"
	mount.add_child(sword)
	var real_blade := MeshInstance3D.new()
	var real_box := BoxMesh.new()
	real_box.size = Vector3(0.05, 0.02, 0.9)
	real_blade.mesh = real_box
	real_blade.position = Vector3(0, 0, -0.45)
	sword.add_child(real_blade)
	var hand := Node3D.new()
	hand.name = "RightGripHand"
	mount.add_child(hand)
	var forearm := MeshInstance3D.new()
	var rod := BoxMesh.new()
	rod.size = Vector3(0.15, 3.86, 0.15)
	forearm.mesh = rod
	forearm.position = Vector3(0, 1.9, 0)
	hand.add_child(forearm)
	var tip := trail.tip_local(mount)
	check(tip.z < -0.8 and absf(tip.y) < 0.3, "the tip is the blade's, not a forearm hanging off the grip hand")

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
