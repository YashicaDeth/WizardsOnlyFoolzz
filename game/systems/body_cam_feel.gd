class_name BodyCamFeel
extends RefCounted

## Greg, 28 September (question boxes): the opening felt floaty. He asked for
## less head bob, more body-cam sway, a kick on landings and hits, and a lean
## with strafing. One shared piece every opening scene calls once a frame,
## after `move_and_slide()`, in place of setting the camera's rotation itself.
## State lives on the camera as metadata, so a scene needs no new fields.

const AMBIENT_AUDIO := preload("res://systems/ambient_audio.gd")

## A slow handheld drift, always on, a little more while moving.
const SWAY := 0.006
const SWAY_MOVING := 0.01
## Roll per metre per second of sideways speed, and its cap.
const LEAN := 0.009
const LEAN_MAX := 0.045
## A landing dips the view by this per metre per second of fall speed.
const LAND_KICK := 0.011
const LAND_KICK_MAX := 0.09
const KICK_RECOVER := 6.0


## Sets `camera.rotation` from `pitch` plus the feel. Call once a frame.
static func apply(camera: Camera3D, body: CharacterBody3D, delta: float, pitch: float) -> void:
	if camera == null or body == null:
		return
	AMBIENT_AUDIO.step(camera, body, delta)
	var clock := float(camera.get_meta("feel_clock", 0.0)) + delta
	camera.set_meta("feel_clock", clock)
	# Landing: the frame the body touches down after falling.
	var was_floor := bool(camera.get_meta("feel_floor", true))
	var fall_speed := float(camera.get_meta("feel_fall", 0.0))
	var on_floor := body.is_on_floor()
	var kick := float(camera.get_meta("feel_kick", 0.0))
	if on_floor and not was_floor and fall_speed > 2.5:
		kick = maxf(kick, minf(fall_speed * LAND_KICK, LAND_KICK_MAX))
	camera.set_meta("feel_floor", on_floor)
	camera.set_meta("feel_fall", maxf(0.0, -body.velocity.y))
	kick = move_toward(kick, 0.0, delta * KICK_RECOVER * maxf(kick, 0.02))
	camera.set_meta("feel_kick", kick)
	# Strafe lean: sideways speed in the body's own frame.
	var local: Vector3 = body.global_transform.basis.inverse() * body.velocity
	var lean_target := clampf(-local.x * LEAN, -LEAN_MAX, LEAN_MAX)
	var lean := lerpf(float(camera.get_meta("feel_lean", 0.0)), lean_target, clampf(delta * 8.0, 0.0, 1.0))
	camera.set_meta("feel_lean", lean)
	var moving := clampf(Vector2(body.velocity.x, body.velocity.z).length() / 4.0, 0.0, 1.0)
	var sway := lerpf(SWAY, SWAY_MOVING, moving)
	camera.rotation = Vector3(
		pitch - kick + sin(clock * 0.9) * sway,
		sin(clock * 0.63 + 1.1) * sway,
		lean + sin(clock * 0.47 + 2.3) * sway * 0.8)


## A hit: the view jolts, then settles through the same recovery.
static func hit(camera: Camera3D, amount := 0.05) -> void:
	if camera == null:
		return
	camera.set_meta("feel_kick", maxf(float(camera.get_meta("feel_kick", 0.0)), amount))


## The walking bob, kept small: an offset for the eye height.
static func bob(body: CharacterBody3D, clock: float) -> float:
	var stride := Vector2(body.velocity.x, body.velocity.z).length()
	return sin(clock * 5.5) * stride * 0.006 if body.is_on_floor() else 0.0
