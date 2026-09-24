extends Node

## Afterimages appear only for a fast, committed swing, never exceed the pool,
## and die away on their own.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var smear := StrikeSmear.new()
	add_child(smear)
	var weapon := Node3D.new()
	add_child(weapon)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	weapon.add_child(mesh)
	var dt := 1.0 / 60.0
	for i in 20:
		smear.feed(weapon, Vector3(0, 0, -1), dt, 1.0)
	check(smear.live_count() == 0, "a still weapon leaves no afterimage")
	for i in 20:
		var a := float(i) * 0.3
		smear.feed(weapon, Vector3(sin(a), 0, -cos(a)), dt, 0.1)
	check(smear.live_count() == 0, "an uncommitted flick leaves none either")
	for i in 40:
		var a := float(i) * 0.3
		smear.feed(weapon, Vector3(sin(a), 0, -cos(a)), dt, 0.9)
	check(smear.live_count() > 0, "a thrown blow smears")
	check(smear.live_count() <= StrikeSmear.MAX_GHOSTS, "never more copies than the pool")
	for i in 30:
		smear.feed(weapon, Vector3(0, 0, -1), dt, 0.9)
	check(smear.live_count() == 0, "afterimages fade out once the swing stops")
	print("STRIKE_SMEAR_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
