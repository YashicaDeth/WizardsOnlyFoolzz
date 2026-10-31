extends Node

## AX5.2. Cramped-space handling. `HunterMotor.third_person_clearance_blend()`
## is pure math (how far the collision-safe chase camera got from the eye,
## eased 0.55-1.65 m; 68c40b3 replaced the original three-point ratio) and is
## exercised directly; the second half proves it reaches the real camera in
## `bone_yard_hunt.gd` (`perspective_blend` is only the request now) by putting a real wall
## immediately behind the player and watching third person fail to fully
## open, then watching it recover once the wall is gone — a corridor and a
## vat room are both just "the wall behind you is close", so this is the
## general case rather than a level-specific fixture.

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


## `_update_camera()` reads a fixed physics delta each call regardless of
## whether physics processing is actually running, so a plain loop of direct
## calls converges `perspective_blend` exactly as real frames would, just
## without waiting on them.
func _run_camera_frames(hunt, count: int) -> void:
	for _tick in count:
		hunt._update_camera()


## How far the real camera stands back from the player, flat on the ground.
func _camera_reach(hunt) -> float:
	var offset: Vector3 = hunt.camera.global_position - hunt.player_body.global_position
	return Vector2(offset.x, offset.z).length()


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("AX5.2 - the pure ratio")
	var blend := func(gap: float) -> float: return HUNTER_MOTOR.third_person_clearance_blend(Vector3.ZERO, Vector3(0, 0, gap))
	check(is_equal_approx(blend.call(3.0), 1.0), "a chase camera with room behind it keeps the whole shot")
	check(is_zero_approx(blend.call(0.3)), "a camera pinned at the eye gives the view back to first person")
	check(blend.call(0.8) < blend.call(1.2) and blend.call(1.2) < blend.call(1.6), "clearance eases in between, never snapping")

	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player_body.velocity = Vector3.ZERO
	hunt.yaw = 0.0
	hunt.third_person = true
	await get_tree().physics_frame

	print("AX5.2 - open ground behind the player still earns the full shot")
	_run_camera_frames(hunt, 40)
	var open_reach := _camera_reach(hunt)
	check(hunt.perspective_blend > 0.9 and open_reach > 1.5, "third person opens up all the way with nothing behind the player (%.2f m)" % open_reach)
	check(not hunt.body_motion.first_person, "the arms leave the lens once the camera is out behind the body")

	print("AX5.2 - a wall immediately behind the player is the corridor case")
	hunt.perspective_blend = 0.0
	var behind_wall := _make_wall(Vector3(0, 1.5, 18.4), Vector3(4.0, 4.0, 0.1))
	add_child(behind_wall)
	await get_tree().physics_frame
	_run_camera_frames(hunt, 40)
	var cramped_reach := _camera_reach(hunt)
	check(cramped_reach < 0.3, "a 0.6m gap hands the view back to the eye, not a camera jammed against the wall (%.2f m)" % cramped_reach)
	check(hunt.perspective_blend > 0.9, "and the request for third person is kept, not forgotten")
	check(hunt.body_motion.first_person, "a camera forced into the eye gets first-person arms back")

	print("AX5.2 - the room comes back, so does the shot")
	behind_wall.queue_free()
	await get_tree().physics_frame
	_run_camera_frames(hunt, 40)
	var back_reach := _camera_reach(hunt)
	check(back_reach > 1.5, "clearing the corridor lets the same camera earn the full shot back (%.2f m)" % back_reach)

	print("CAMERA_CLEARANCE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
