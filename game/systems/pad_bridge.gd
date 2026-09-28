extends Node

## Greg: controller support, PlayStation layout. The game reads the keyboard
## and mouse directly in ~290 places and through six input actions; rather
## than rewrite every scene, this turns the pad into the keys and mouse they
## already read. One file, every scene.
##
##   Left stick   move (the move_* actions), flicks = arrow keys in menus
##   Right stick  look (mouse motion)
##   R2 attack (LMB)   L2 guard / aim (RMB)   R1 heavy (MMB)
##   Cross jump / climb (Space)   Circle crouch / slide (Ctrl)
##   Square use (E)   Triangle shoulder / file (F)
##   L1 wizard eyes (K)   L3 sprint (Shift)   R3 lock on (Z)
##   D-pad: up K, down hold J depth scan, left hold 4 dress wound, right hold I inspect
##   Touchpad inventory (Tab)   Options pause (Esc)
##
## ponytail: synthetic key/mouse events, no per-scene pad code. Button
## prompts still show keyboard keys; PlayStation glyphs are a later pass.

const LOOK_SPEED := 900.0
const DEADZONE := 0.18
const FLICK := 0.7

const BUTTON_KEYS := {
	JOY_BUTTON_A: KEY_SPACE,          # Cross
	JOY_BUTTON_B: KEY_CTRL,           # Circle
	JOY_BUTTON_X: KEY_E,              # Square
	JOY_BUTTON_Y: KEY_F,              # Triangle
	JOY_BUTTON_LEFT_SHOULDER: KEY_K,  # L1
	JOY_BUTTON_LEFT_STICK: KEY_SHIFT, # L3
	JOY_BUTTON_RIGHT_STICK: KEY_Z,    # R3
	JOY_BUTTON_DPAD_UP: KEY_K,
	JOY_BUTTON_DPAD_DOWN: KEY_J,
	JOY_BUTTON_DPAD_LEFT: KEY_4,
	JOY_BUTTON_DPAD_RIGHT: KEY_I,
	JOY_BUTTON_TOUCHPAD: KEY_TAB,
	JOY_BUTTON_BACK: KEY_TAB,         # Share, for pads without a touchpad click
	JOY_BUTTON_START: KEY_ESCAPE,     # Options
}
const BUTTON_MOUSE := {JOY_BUTTON_RIGHT_SHOULDER: MOUSE_BUTTON_MIDDLE}
const TRIGGER_MOUSE := {JOY_AXIS_TRIGGER_RIGHT: MOUSE_BUTTON_LEFT, JOY_AXIS_TRIGGER_LEFT: MOUSE_BUTTON_RIGHT}

var _trigger_down := {}
var _flick := Vector2i.ZERO


func _ready() -> void:
	name = "PadBridge"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_movement()


## The six real actions get the stick natively.
func _bind_movement() -> void:
	for pair in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_back", JOY_AXIS_LEFT_Y, 1.0]]:
		if not InputMap.has_action(pair[0]):
			continue
		var motion := InputEventJoypadMotion.new()
		motion.axis = pair[1]
		motion.axis_value = pair[2]
		InputMap.action_add_event(pair[0], motion)
	for pair in [["sprint", JOY_BUTTON_LEFT_STICK], ["crouch", JOY_BUTTON_B]]:
		if InputMap.has_action(pair[0]):
			var button := InputEventJoypadButton.new()
			button.button_index = pair[1]
			InputMap.action_add_event(pair[0], button)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		if BUTTON_KEYS.has(pad.button_index):
			_send_key(BUTTON_KEYS[pad.button_index], pad.pressed)
		elif BUTTON_MOUSE.has(pad.button_index):
			_send_mouse(BUTTON_MOUSE[pad.button_index], pad.pressed)
	elif event is InputEventJoypadMotion:
		var axis := (event as InputEventJoypadMotion).axis
		if TRIGGER_MOUSE.has(axis):
			var down := (event as InputEventJoypadMotion).axis_value > 0.5
			if down != bool(_trigger_down.get(axis, false)):
				_trigger_down[axis] = down
				_send_mouse(TRIGGER_MOUSE[axis], down)


func _process(delta: float) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if look.length() > DEADZONE:
		var motion := InputEventMouseMotion.new()
		motion.relative = look * look.length() * LOOK_SPEED * delta
		motion.position = get_viewport().get_mouse_position()
		Input.parse_input_event(motion)
	# Stick flicks as arrow keys, for the intake tabs, rows and menus.
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var flick := Vector2i(int(stick.x > FLICK) - int(stick.x < -FLICK), int(stick.y > FLICK) - int(stick.y < -FLICK))
	if flick.x != _flick.x and flick.x != 0:
		_tap(KEY_RIGHT if flick.x > 0 else KEY_LEFT)
	if flick.y != _flick.y and flick.y != 0:
		_tap(KEY_DOWN if flick.y > 0 else KEY_UP)
	_flick = flick


func _send_key(keycode: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = pressed
	Input.parse_input_event(key)


func _tap(keycode: Key) -> void:
	_send_key(keycode, true)
	_send_key(keycode, false)


func _send_mouse(button: MouseButton, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = button
	click.pressed = pressed
	click.position = get_viewport().get_mouse_position()
	Input.parse_input_event(click)
