extends Node

## body-09. Greg, 4 Oct playtest: "third-person body model has no head and
## massive shoulders." The head hid on the camera blend (<= 0.5), and a
## cramped room held that blend part way, which parked the lens just behind
## the skull: head hidden, first-person pose pulling the torso back into the
## lens. This sweeps a wall behind the player through every gap from a
## corridor to open ground and checks the settled camera is either in the eye
## (head hidden, first-person arms) or clear of the head (head drawn,
## third-person pose) — never parked behind a headless body.

const HUNTER_MOTOR := preload("res://systems/hunter_motor.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _make_wall(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	return body


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("the clearance latch commits, with a dead band")
	check(HUNTER_MOTOR.clearance_open(false, 0.7), "room opens the shoulder")
	check(not HUNTER_MOTOR.clearance_open(true, 0.3), "a wall closes it")
	check(HUNTER_MOTOR.clearance_open(true, 0.5) and not HUNTER_MOTOR.clearance_open(false, 0.5), "the edge keeps whatever it was")
	check(HUNTER_MOTOR.lens_in_head(Vector3.ZERO, Vector3(0, 0, 0.1)), "a lens at the eye is in the head")
	check(not HUNTER_MOTOR.lens_in_head(Vector3.ZERO, Vector3(0, 0, 0.6)), "a lens behind the skull is not")

	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt.third_person = true
	await get_tree().physics_frame
	var head: Node3D = hunt.player_rig.parts["head"]

	print("a wall behind the player, swept from corridor to open ground")
	var parked := 0
	var mismatched := 0
	var gap := 0.35
	while gap <= 2.6:
		var wall := _make_wall(Vector3(0, 1.5, 19.0 - gap), Vector3(6.0, 4.0, 0.1))
		add_child(wall)
		await get_tree().physics_frame
		for _tick in 90:
			hunt._update_camera()
		var eye: Vector3 = hunt.player + Vector3.UP * (hunt.EYE_ABOVE_CENTRE - 0.6)
		var lens: float = hunt.camera.global_position.distance_to(eye)
		var in_head := lens < HUNTER_MOTOR.LENS_IN_HEAD
		print("  wall %.2f m: lens %.2f m from the eye, head %s, first-person pose %s" % [gap, lens, head.visible, hunt.body_motion.first_person])
		if lens >= HUNTER_MOTOR.LENS_IN_HEAD and lens < 0.9:
			parked += 1
		if head.visible == in_head or hunt.body_motion.first_person != in_head:
			mismatched += 1
		wall.free()
		await get_tree().physics_frame
		gap += 0.15
	check(parked == 0, "the settled camera never rests just behind the skull (%d gaps did)" % parked)
	check(mismatched == 0, "the head is drawn exactly when the lens is outside it, and the pose agrees (%d gaps did not)" % mismatched)

	print("open ground: the whole body, head and all")
	for _tick in 90:
		hunt._update_camera()
	check(head.visible, "third person in the open draws the head")
	check(not hunt.body_motion.first_person, "and the third-person pose, not arms raised to a lens behind it")

	print("first person still hides your own head")
	hunt.third_person = false
	for _tick in 60:
		hunt._update_camera()
	check(not head.visible, "the eye does not see the inside of its own skull")
	check(hunt.body_motion.first_person, "first-person arms")

	print("THIRD_PERSON_HEAD_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
