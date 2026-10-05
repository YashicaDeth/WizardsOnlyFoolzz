extends Node

## The one native InputMap used by the opening route, the Hunt and menus.
## PadBridge remains available only for scenes that have not migrated yet.

signal device_changed(family: String)

const LOOK_SPEED := 2.65
const STICK_DEADZONE := 0.18

const GAMEPLAY_ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right",
	"look_left", "look_right", "look_up", "look_down",
	"sprint", "crouch", "jump", "dodge", "interact",
	"attack", "guard", "parry", "heavy", "reload", "lock_on", "perspective",
	"wizard_eyes", "depth_scan", "heal", "inspect", "xray", "grapple",
	"device", "inventory", "pause",
	"vehicle_handbrake", "vehicle_horn",
	"pad_combat_r1", "pad_combat_r2", "pad_combat_l1", "pad_combat_l2",
]

const MENU_ACTIONS := ["ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right"]

const REBINDABLE_ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right",
	"sprint", "crouch", "jump", "dodge", "interact",
	"attack", "guard", "parry", "heavy", "reload", "lock_on", "perspective",
	"wizard_eyes", "depth_scan", "heal", "inspect", "xray", "grapple",
	"device", "inventory", "pause",
	"vehicle_handbrake", "vehicle_horn",
]

const ACTION_LABELS := {
	"move_forward": "MOVE FORWARD", "move_back": "MOVE BACK",
	"move_left": "MOVE LEFT", "move_right": "MOVE RIGHT",
	"look_left": "LOOK LEFT", "look_right": "LOOK RIGHT",
	"look_up": "LOOK UP", "look_down": "LOOK DOWN",
	"sprint": "SPRINT", "crouch": "CROUCH / SLIDE",
	"jump": "JUMP / CLIMB", "dodge": "DODGE / BACKSTEP",
	"interact": "USE", "attack": "LIGHT ATTACK / FIRE",
	"guard": "BLOCK / AIM", "parry": "PARRY",
	"heavy": "HEAVY / GUARD BREAK", "reload": "RELOAD / GRIP",
	"lock_on": "LOCK ON", "perspective": "VIEW / SECONDARY",
	"wizard_eyes": "WIZARD EYES", "depth_scan": "DEPTH SCAN",
	"heal": "DRESS WOUND", "inspect": "INSPECT", "xray": "X-RAY / VATS",
	"grapple": "GRAPPLE", "device": "BLACK MIRROR",
	"inventory": "INVENTORY", "pause": "PAUSE",
	"vehicle_handbrake": "HANDBRAKE", "vehicle_horn": "HORN",
}

## Each entry is [kind, key/button/axis, optional direction]. Keyboard and
## mouse remain full peers; all gameplay and menu actions receive a pad event.
const SPECS := {
	"move_forward": [["key", KEY_W], ["axis", JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [["key", KEY_S], ["axis", JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [["key", KEY_A], ["axis", JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [["key", KEY_D], ["axis", JOY_AXIS_LEFT_X, 1.0]],
	"look_left": [["axis", JOY_AXIS_RIGHT_X, -1.0]],
	"look_right": [["axis", JOY_AXIS_RIGHT_X, 1.0]],
	"look_up": [["axis", JOY_AXIS_RIGHT_Y, -1.0]],
	"look_down": [["axis", JOY_AXIS_RIGHT_Y, 1.0]],
	"sprint": [["key", KEY_SHIFT], ["button", JOY_BUTTON_LEFT_STICK]],
	"crouch": [["key", KEY_CTRL], ["button", JOY_BUTTON_B]],
	"jump": [["key", KEY_SPACE], ["button", JOY_BUTTON_A]],
	"dodge": [["key", KEY_SPACE], ["button", JOY_BUTTON_B]],
	"interact": [["key", KEY_E], ["button", JOY_BUTTON_X]],
	"attack": [["mouse", MOUSE_BUTTON_LEFT], ["button", JOY_BUTTON_RIGHT_SHOULDER]],
	"guard": [["mouse", MOUSE_BUTTON_RIGHT], ["button", JOY_BUTTON_LEFT_SHOULDER]],
	"parry": [["key", KEY_X], ["axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"heavy": [["mouse", MOUSE_BUTTON_MIDDLE], ["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"reload": [["key", KEY_R], ["button", JOY_BUTTON_Y]],
	"lock_on": [["key", KEY_Z], ["button", JOY_BUTTON_RIGHT_STICK]],
	"perspective": [["key", KEY_F], ["button", JOY_BUTTON_Y]],
	"wizard_eyes": [["key", KEY_K], ["button", JOY_BUTTON_DPAD_UP]],
	"depth_scan": [["key", KEY_J], ["button", JOY_BUTTON_DPAD_DOWN]],
	"heal": [["key", KEY_4], ["button", JOY_BUTTON_DPAD_LEFT]],
	"inspect": [["key", KEY_I], ["button", JOY_BUTTON_DPAD_RIGHT]],
	"xray": [["key", KEY_Q], ["button", JOY_BUTTON_DPAD_UP]],
	"grapple": [["key", KEY_C], ["button", JOY_BUTTON_B]],
	"device": [["key", KEY_G], ["button", JOY_BUTTON_BACK]],
	"inventory": [["key", KEY_TAB], ["button", JOY_BUTTON_TOUCHPAD]],
	"pause": [["key", KEY_ESCAPE], ["button", JOY_BUTTON_START]],
	"vehicle_handbrake": [["key", KEY_SPACE], ["button", JOY_BUTTON_RIGHT_SHOULDER]],
	"vehicle_horn": [["key", KEY_H], ["button", JOY_BUTTON_A]],
	"pad_combat_r1": [["button", JOY_BUTTON_RIGHT_SHOULDER]],
	"pad_combat_r2": [["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"pad_combat_l1": [["button", JOY_BUTTON_LEFT_SHOULDER]],
	"pad_combat_l2": [["axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"ui_accept": [["key", KEY_ENTER], ["button", JOY_BUTTON_A]],
	"ui_cancel": [["key", KEY_ESCAPE], ["button", JOY_BUTTON_B]],
	"ui_up": [["key", KEY_UP], ["button", JOY_BUTTON_DPAD_UP], ["axis", JOY_AXIS_LEFT_Y, -1.0]],
	"ui_down": [["key", KEY_DOWN], ["button", JOY_BUTTON_DPAD_DOWN], ["axis", JOY_AXIS_LEFT_Y, 1.0]],
	"ui_left": [["key", KEY_LEFT], ["button", JOY_BUTTON_DPAD_LEFT], ["axis", JOY_AXIS_LEFT_X, -1.0]],
	"ui_right": [["key", KEY_RIGHT], ["button", JOY_BUTTON_DPAD_RIGHT], ["axis", JOY_AXIS_LEFT_X, 1.0]],
}

var using_pad := false
var last_joypad := -1
## Tests can name a family without manufacturing platform-specific hardware.
var device_family_override := ""


func _ready() -> void:
	name = "InputProfile"
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_actions()


func ensure_actions() -> void:
	for action in SPECS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, STICK_DEADZONE)
		for spec: Array in SPECS[action]:
			var candidate := _event_from_spec(spec)
			if candidate != null and not _has_equivalent(action, candidate):
				InputMap.action_add_event(action, candidate)


func _event_from_spec(spec: Array) -> InputEvent:
	match str(spec[0]):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(spec[1])
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(spec[1]) as MouseButton
			return mouse
		"button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(spec[1]) as JoyButton
			return button
		"axis":
			var axis := InputEventJoypadMotion.new()
			axis.axis = int(spec[1]) as JoyAxis
			axis.axis_value = float(spec[2])
			return axis
	return null


func _has_equivalent(action: String, candidate: InputEvent) -> bool:
	for current: InputEvent in InputMap.action_get_events(action):
		if current is InputEventKey and candidate is InputEventKey:
			if (current as InputEventKey).physical_keycode == (candidate as InputEventKey).physical_keycode:
				return true
		elif current is InputEventMouseButton and candidate is InputEventMouseButton:
			if (current as InputEventMouseButton).button_index == (candidate as InputEventMouseButton).button_index:
				return true
		elif current is InputEventJoypadButton and candidate is InputEventJoypadButton:
			if (current as InputEventJoypadButton).button_index == (candidate as InputEventJoypadButton).button_index:
				return true
		elif current is InputEventJoypadMotion and candidate is InputEventJoypadMotion:
			var a := current as InputEventJoypadMotion
			var b := candidate as InputEventJoypadMotion
			if a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value):
				return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		last_joypad = event.device
		_set_pad(true)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.45:
		last_joypad = event.device
		_set_pad(true)
	elif event is InputEventKey and event.pressed:
		_set_pad(false)
	elif event is InputEventMouseButton and event.pressed:
		_set_pad(false)
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length_squared() > 4.0:
		_set_pad(false)


func _set_pad(value: bool) -> void:
	if using_pad == value:
		return
	using_pad = value
	device_changed.emit(device_family())


func set_device_preference(pad: bool) -> void:
	_set_pad(pad)


func device_family() -> String:
	if not device_family_override.is_empty():
		return device_family_override
	if not using_pad:
		return "keyboard"
	var id := last_joypad
	if id < 0 and not Input.get_connected_joypads().is_empty():
		id = int(Input.get_connected_joypads()[0])
	var product := Input.get_joy_name(id).to_lower() if id >= 0 else ""
	if product.contains("dualsense") or product.contains("ps5"):
		return "ps5"
	if product.contains("dualshock") or product.contains("ps4") or product.contains("wireless controller") or product.contains("sony"):
		return "ps4"
	return "gamepad"


func look_delta(delta: float) -> Vector2:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() < STICK_DEADZONE:
		return Vector2.ZERO
	var scaled := stick.normalized() * inverse_lerp(STICK_DEADZONE, 1.0, stick.length())
	return scaled * LOOK_SPEED * delta


func apply_stick_look(target: Object, delta: float, pitch_min := -1.15, pitch_max := 0.95) -> bool:
	var turn := look_delta(delta)
	if turn.is_zero_approx():
		return false
	target.set("yaw", float(target.get("yaw")) - turn.x)
	target.set("pitch", clampf(float(target.get("pitch")) - turn.y, pitch_min, pitch_max))
	return true


func glyph(action: String, family := "") -> String:
	var wanted := family if not family.is_empty() else device_family()
	for event: InputEvent in InputMap.action_get_events(action):
		if wanted == "keyboard":
			if event is InputEventKey:
				return (event as InputEventKey).as_text_physical_keycode().to_upper()
			if event is InputEventMouseButton:
				return _mouse_name((event as InputEventMouseButton).button_index)
		elif event is InputEventJoypadButton:
			return _joy_button_name((event as InputEventJoypadButton).button_index, wanted)
		elif event is InputEventJoypadMotion:
			return _joy_axis_name(event as InputEventJoypadMotion, wanted)
	return "--"


func _joy_button_name(button: JoyButton, family: String) -> String:
	var prefix := "PS5 " if family == "ps5" else "PS4 " if family == "ps4" else "PAD "
	var names := {
		JOY_BUTTON_A: "CROSS", JOY_BUTTON_B: "CIRCLE", JOY_BUTTON_X: "SQUARE", JOY_BUTTON_Y: "TRIANGLE",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_DPAD_UP: "D-UP", JOY_BUTTON_DPAD_DOWN: "D-DOWN",
		JOY_BUTTON_DPAD_LEFT: "D-LEFT", JOY_BUTTON_DPAD_RIGHT: "D-RIGHT",
		JOY_BUTTON_BACK: "CREATE", JOY_BUTTON_START: "OPTIONS", JOY_BUTTON_TOUCHPAD: "TOUCHPAD",
	}
	return prefix + str(names.get(button, "B%d" % int(button)))


func _joy_axis_name(event: InputEventJoypadMotion, family: String) -> String:
	var prefix := "PS5 " if family == "ps5" else "PS4 " if family == "ps4" else "PAD "
	match event.axis:
		JOY_AXIS_LEFT_X: return prefix + ("L-STICK LEFT" if event.axis_value < 0.0 else "L-STICK RIGHT")
		JOY_AXIS_LEFT_Y: return prefix + ("L-STICK UP" if event.axis_value < 0.0 else "L-STICK DOWN")
		JOY_AXIS_RIGHT_X: return prefix + ("R-STICK LEFT" if event.axis_value < 0.0 else "R-STICK RIGHT")
		JOY_AXIS_RIGHT_Y: return prefix + ("R-STICK UP" if event.axis_value < 0.0 else "R-STICK DOWN")
		JOY_AXIS_TRIGGER_LEFT: return prefix + "L2"
		JOY_AXIS_TRIGGER_RIGHT: return prefix + "R2"
	return prefix + "AXIS %d" % int(event.axis)


func _mouse_name(button: MouseButton) -> String:
	match button:
		MOUSE_BUTTON_LEFT: return "LMB"
		MOUSE_BUTTON_RIGHT: return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
	return "MOUSE %d" % int(button)


static func is_joy_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func same_device_kind(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey or a is InputEventMouseButton:
		return b is InputEventKey or b is InputEventMouseButton
	return is_joy_event(a) and is_joy_event(b)
