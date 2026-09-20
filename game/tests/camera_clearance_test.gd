extends Node

## AX5.2. Cramped-space handling. `HunterMotor.third_person_clearance_blend()`
## is pure math (three points in, a ratio out) and gets exercised directly
## with no scene at all; the second half proves the number actually reaches
## `bone_yard_hunt.gd`'s own `perspective_blend` by putting a real wall
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


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("AX5.2 - the pure ratio")
	check(is_equal_approx(HUNTER_MOTOR.third_person_clearance_blend(Vector3.ZERO, Vector3(0, 0, -5), Vector3(0, 0, -5)), 1.0),
		"an unobstructed shot keeps the whole distance it asked for")
	check(is_equal_approx(HUNTER_MOTOR.third_person_clearance_blend(Vector3.ZERO, Vector3(0, 0, -5), Vector3(0, 0, -0.5)), 0.1),
		"a shot stopped a tenth of the way out reads back as a tenth of clearance")
	check(HUNTER_MOTOR.third_person_clearance_blend(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -5)) == 1.0,
		"asking for zero distance is never starved for room, whatever `achieved` says")

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
	check(hunt.perspective_blend > 0.9, "third person opens up all the way with nothing behind the player (%.3f)" % hunt.perspective_blend)

	print("AX5.2 - a wall immediately behind the player is the corridor case")
	hunt.perspective_blend = 0.0
	var behind_wall := _make_wall(Vector3(0, 1.5, 18.4), Vector3(4.0, 4.0, 0.1))
	add_child(behind_wall)
	await get_tree().physics_frame
	_run_camera_frames(hunt, 40)
	check(hunt.perspective_blend < 0.5, "third person cannot open past the clearance a 0.6m gap actually leaves (%.3f)" % hunt.perspective_blend)
	check(hunt.perspective_blend >= 0.0, "and never goes negative doing it")

	print("AX5.2 - the room comes back, so does the shot")
	behind_wall.queue_free()
	await get_tree().physics_frame
	_run_camera_frames(hunt, 40)
	check(hunt.perspective_blend > 0.9, "clearing the corridor lets the same camera earn the full shot back (%.3f)" % hunt.perspective_blend)

	print("CAMERA_CLEARANCE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
