extends Node

## AD1.1. "Jumping worth doing - height, arc and a landing that reads."
## HunterMotor.move_body() already ran real gravity, air acceleration and
## floor-stick every physics frame and nothing ever gave the player an
## upward velocity to work with. SPACE now jumps when there is no
## directional input (a dodge in place makes no sense anyway); with
## direction held, it still dodges exactly as before.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("AD1.1 - a jump is a real upward impulse, not a flag")
	check(hunt.player_body.is_on_floor(), "the player starts grounded")
	hunt._jump()
	check(hunt.jump_queued, "the request is queued rather than applied immediately")
	hunt._physics_process(1.0 / 60.0)
	check(not hunt.jump_queued, "and consumed on the very next physics step")
	check(hunt.player_body.velocity.y > 0.0, "leaving the player with real upward velocity (%.2f)" % hunt.player_body.velocity.y)

	print("AD1.1 - gravity and a landing that reads take it from there")
	var airborne := false
	for _tick in 90:
		hunt._physics_process(1.0 / 60.0)
		if not hunt.player_body.is_on_floor():
			airborne = true
		if airborne and hunt.player_body.is_on_floor():
			break
	check(airborne, "the jump actually left the ground at some point during the arc")
	check(hunt.player_body.is_on_floor(), "and gravity brought it back down on its own - no teleport, no floor lock")
	check(hunt.body_motion.landing_time > 0.0, "the landing pose HunterBodyMotion already had is triggered for real now")

	print("AD1.1 - you cannot jump again mid-air")
	hunt.player_body.velocity.y = 2.0
	hunt._jump()
	check(not hunt.jump_queued, "a jump request while airborne is refused outright, not merely deferred")

	print("AD1.1 - space with a direction still dodges, exactly as before")
	hunt.player_body.position = Vector3(0, 1.0, 19)
	hunt.player_body.velocity = Vector3.ZERO
	for _settle in 10:
		hunt._physics_process(1.0 / 60.0)
	check(hunt.player_body.is_on_floor(), "settled back on the floor before testing the dodge branch")
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	Input.action_press("move_forward")
	hunt._unhandled_input(event)
	check(hunt.dodge_remaining > 0.0, "held direction + space dodges, not jumps")
	check(not hunt.jump_queued, "and does not also queue a jump")
	Input.action_release("move_forward")

	print("JUMP_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
