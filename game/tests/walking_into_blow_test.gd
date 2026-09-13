extends Node

## AN10.14. `_advance_arm()` has read `player_body.velocity` into
## `LimbMomentum.advance()`'s `body_velocity` parameter since AN1.2 shipped —
## "Walking into the swing counts. A step forward is real force and the game
## should not be the only place that is untrue" is the comment already sitting
## on that line — but nothing had ever driven the real hunt loop with a moving
## body while swinging. `limb_momentum_test.gd` drives `LimbMomentum` in
## isolation with a hand-picked vector; `firearm_momentum_test.gd` holds the
## player still while equipping weapons; `arm_calibration_test.gd`'s one
## "walking into it" gesture changes the turn rate at the same time, so it
## cannot show what walking alone is worth. This throws the identical swing
## twice through the real `_advance_arm()` the game calls every physics
## frame, the only difference being whether `player_body.velocity` is zero or
## a real run speed.

const SWING_FRAMES := 16
## Deliberately weak — below `LimbMomentum.IDLE_SPEED` on a still body, so a
## standing swing this gentle should not even register as a blow at all. That
## makes "walking into it" an honest either/or rather than a small percentage
## nudged in the right direction.
const LOOK_DELTA := 0.015

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## Resets the arm to rest and throws the same weak turn while the body
## carries `body_speed` along the way it is facing for the whole swing.
## Returns what the blow ended up worth.
func _swing_while_moving(hunt: Node, body_speed: float) -> float:
	hunt.arm.at = hunt.arm.anchor
	hunt.arm.velocity = Vector3.ZERO
	hunt.arm.spin = Vector2.ZERO
	hunt.arm.tilt = Vector2.ZERO
	hunt.arm._work = 0.0
	hunt.arm._peak_decay = 0.0
	var step := 1.0 / 60.0
	var forward := Vector3(sin(hunt.yaw), 0.0, cos(hunt.yaw))
	for _frame in SWING_FRAMES:
		hunt.player_body.velocity = forward * body_speed
		hunt.apply_look(Vector2(LOOK_DELTA, 0.0))
		hunt._advance_arm(step)
	hunt.player_body.velocity = Vector3.ZERO
	return hunt.arm.commitment()


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	hunt._equip_weapon(0)
	hunt._advance_arm(1.0 / 60.0) # let _carry_current_weapon() settle the sword in first

	var standing := _swing_while_moving(hunt, 0.0)
	var running := _swing_while_moving(hunt, 14.0)
	print("commitment: standing %.3f  vs  running into it %.3f" % [standing, running])
	check(is_zero_approx(standing), "a weak turn on a still body is not a blow at all")
	check(running > 0.02, "the identical turn while running into it is a real blow")

	# `advance()` adds the body's own velocity to the weapon's regardless of
	# which way it points relative to the swing — it cannot tell a charge from
	# a retreat, only that the body moved. Named here rather than papered
	# over: real body speed counts, "forward" specifically does not yet.
	var retreating := _swing_while_moving(hunt, -14.0)
	print("commitment: retreating %.3f" % retreating)
	check(retreating > 0.02, "and any real body speed counts, not only closing the distance")

	if failures.is_empty():
		print("walking into a blow: verified through the real hunt loop")
		get_tree().quit(0)
	else:
		print("walking into a blow FAILURES: ", failures)
		get_tree().quit(1)
