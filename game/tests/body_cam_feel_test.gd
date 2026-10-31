extends Node3D

## Greg, 28 September: less bob, body-cam sway, a kick on landing and hits, a
## lean when strafing. Checked on a real body on a floor.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	add_child(floor_body)
	var body := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	capsule.shape = CapsuleShape3D.new()
	body.add_child(capsule)
	body.position.y = 4.0
	add_child(body)
	var camera := Camera3D.new()
	body.add_child(camera)
	await get_tree().physics_frame

	var dipped := false
	for i in 120:
		body.velocity.y -= 21.0 / 60.0
		body.move_and_slide()
		BodyCamFeel.apply(camera, body, 1.0 / 60.0, 0.0)
		if camera.rotation.x < -0.03:
			dipped = true
		await get_tree().physics_frame
	check(dipped, "a fall of a few metres dips the view on landing")
	check(camera.rotation.x > -0.03, "and it settles again (%.3f)" % camera.rotation.x)

	for i in 30:
		body.velocity = Vector3(4.0, -1.0, 0.0)
		body.move_and_slide()
		BodyCamFeel.apply(camera, body, 1.0 / 60.0, 0.0)
		await get_tree().physics_frame
	check(camera.rotation.z < -0.02, "strafing right leans the view (%.3f)" % camera.rotation.z)

	body.velocity = Vector3.ZERO
	for i in 60:
		BodyCamFeel.apply(camera, body, 1.0 / 60.0, 0.0)
	var rest := absf(camera.rotation.x)
	check(rest < 0.02 and rest > 0.0, "standing still, only a small handheld sway is left (%.4f)" % rest)
	BodyCamFeel.hit(camera, 0.06)
	BodyCamFeel.apply(camera, body, 1.0 / 60.0, 0.0)
	check(camera.rotation.x < -0.04, "a hit jolts the view")
	check(absf(BodyCamFeel.bob(body, 1.0)) < 0.001, "no bob standing still")

	print("BODY_CAM_FEEL_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
