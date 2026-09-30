class_name SoulsPad
extends Node

## A PS4 pad (or any SDL-mapped pad) in the sandbox, laid out like Bloodborne
## and Dark Souls 3 (Greg, 30 September: "map it to Dark Souls controls for
## the fighting and the big swings ... or Bloodborne"). This only reads the
## pad and says what was asked for; the sandbox decides what that does, so the
## same verbs stay reachable from the keyboard.
##
##   left stick  move            right stick  camera
##   R1  light (the chain)       R2  heavy (held: charged)
##   triangle  one hand / two hands
##   L1  guard (held)            L2  parry (a guard raised late)
##   O   tap: roll / backstep    hold: sprint
##   R3  lock on                 X (cross)  take
##   touchpad / share  1st/3rd person
##   d-pad left/right  weapon    d-pad up  duel / pack    options  enemies

signal light
## R2 is released with how long it was held (Bloodborne: a hold charges).
signal heavy(held: float)
signal stance_toggle
signal roll
signal lock
signal view
signal interact
signal guard_changed(held: bool, parry: bool)
signal weapon_step(step: int)
signal duel_toggle
signal enemies_toggle

const DEADZONE := 0.18
## Radians a second at full right-stick deflection.
const LOOK_YAW_RATE := 3.0
const LOOK_PITCH_RATE := 2.0
## Circle held this long is a sprint rather than a roll.
const SPRINT_HOLD := 0.28
## Triggers count as pressed past this.
const TRIGGER_PRESS := 0.5

var device := 0
## A PS4 pad under DS4Windows / Steam shows up twice (the raw pad and an
## emulated Xbox pad), and both send every press. Only the pad in use counts:
## another one takes over once this one has been quiet for DEVICE_HANDOVER.
const DEVICE_HANDOVER := 1.0
var _quiet := DEVICE_HANDOVER
var sprinting := false
var _circle_held := -1.0
var _r2_down := false
var _r2_held := 0.0
var _l2_down := false


func _ready() -> void:
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		device = pads[0]
	Input.joy_connection_changed.connect(func(id: int, connected: bool) -> void:
		if connected:
			device = id)


## The left stick, flat, in the pad's own sense (x right, y down), with the
## deadzone removed and the rest rescaled so a half push is a half speed.
func move_stick() -> Vector2:
	return _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)


## Camera turn this frame from the right stick, in radians (x yaw, y pitch;
## positive x turns right, positive y looks down, like a mouse).
func look(delta: float) -> Vector2:
	var aim := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	# Squared response: fine aim near the centre, fast turns at the edge.
	aim = aim * aim.length()
	return Vector2(aim.x * LOOK_YAW_RATE, aim.y * LOOK_PITCH_RATE) * delta


func _stick(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	var raw := Vector2(Input.get_joy_axis(device, axis_x), Input.get_joy_axis(device, axis_y))
	var amount := raw.length()
	if amount < DEADZONE:
		return Vector2.ZERO
	return raw / amount * clampf((amount - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)


func _process(delta: float) -> void:
	_quiet += delta
	if _circle_held >= 0.0:
		_circle_held += delta
		sprinting = _circle_held >= SPRINT_HOLD
	var r2 := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_PRESS
	if r2:
		_r2_held = 0.0 if not _r2_down else _r2_held + delta
	elif _r2_down:
		heavy.emit(_r2_held)
	_r2_down = r2
	var l2 := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > TRIGGER_PRESS
	if l2 != _l2_down:
		guard_changed.emit(l2, true)
	_l2_down = l2


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event.device != device:
		if _quiet < DEVICE_HANDOVER or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < DEADZONE):
			get_viewport().set_input_as_handled()
			return
		device = event.device
	if event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= DEADZONE:
			_quiet = 0.0
		return
	_quiet = 0.0
	if event.is_echo():
		return
	var button := event as InputEventJoypadButton
	var down: bool = button.pressed
	match button.button_index:
		JOY_BUTTON_RIGHT_SHOULDER:
			if down:
				light.emit()
		JOY_BUTTON_LEFT_SHOULDER:
			guard_changed.emit(down, false)
		JOY_BUTTON_B:
			if down:
				_circle_held = 0.0
			else:
				# A tap rolls; a hold was a sprint and just stops.
				if _circle_held >= 0.0 and _circle_held < SPRINT_HOLD:
					roll.emit()
				_circle_held = -1.0
				sprinting = false
		JOY_BUTTON_RIGHT_STICK:
			if down:
				lock.emit()
		JOY_BUTTON_A:
			if down:
				interact.emit()
		JOY_BUTTON_Y:
			if down:
				stance_toggle.emit()
		JOY_BUTTON_TOUCHPAD, JOY_BUTTON_BACK:
			if down:
				view.emit()
		JOY_BUTTON_DPAD_LEFT:
			if down:
				weapon_step.emit(-1)
		JOY_BUTTON_DPAD_RIGHT:
			if down:
				weapon_step.emit(1)
		JOY_BUTTON_DPAD_UP:
			if down:
				duel_toggle.emit()
		JOY_BUTTON_START:
			if down:
				enemies_toggle.emit()
	get_viewport().set_input_as_handled()
