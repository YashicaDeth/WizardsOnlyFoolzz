extends Node

const CombatLayer := preload("res://systems/combat_input_layer.gd")

## Compatibility bridge for detached labs and other unmigrated scenes. The
## production route reads InputProfile's native actions, so pad input never
## masquerades as a key or mouse event there. Semantic combat dispatch remains
## here until disciplines own it; it does not synthesize an event.
##
##   Left stick   move (the move_* actions), flicks = arrow keys in menus
##   Right stick  look (mouse motion)
##   Souls combat layer: R1 light, R2 heavy, L1 block, L2 parry
##   Firearm context: R2 fire, L2 aim; L2+R2 remains aimed X-ray / VATS
##   Cross jump / climb (Space)   Circle crouch / slide (Ctrl)
##   Square use (E)   Triangle shoulder / file (F)
##   D-pad up wizard eyes (K)   L3 sprint (Shift)   R3 lock on (Z)
##   D-pad: down hold J depth scan, left hold 4 dress wound, right hold I inspect
##   Touchpad inventory (Tab)   Create device (G)   Options pause (Esc)
##
## ponytail: synthetic key/mouse events, no per-scene pad code. Prompts
## follow the same trick: while the pad was the last thing touched, prompt
## labels (a "//" strip, HOLD or PRESS) have their key names swapped for
## buttons after the scene sets them. Custom-drawn prompts call `keys()`.

const LOOK_SPEED := 900.0
const DEADZONE := 0.18
const FLICK := 0.7

const BUTTON_KEYS := {
	JOY_BUTTON_A: KEY_SPACE,          # Cross
	JOY_BUTTON_B: KEY_CTRL,           # Circle
	JOY_BUTTON_X: KEY_E,              # Square
	JOY_BUTTON_Y: KEY_F,              # Triangle
	JOY_BUTTON_LEFT_STICK: KEY_SHIFT, # L3
	JOY_BUTTON_RIGHT_STICK: KEY_Z,    # R3
	JOY_BUTTON_DPAD_UP: KEY_K,
	JOY_BUTTON_DPAD_DOWN: KEY_J,
	JOY_BUTTON_DPAD_LEFT: KEY_4,
	JOY_BUTTON_DPAD_RIGHT: KEY_I,
	JOY_BUTTON_TOUCHPAD: KEY_TAB,
	JOY_BUTTON_BACK: KEY_G,           # Create / Share: the device (G had no button)
	JOY_BUTTON_START: KEY_ESCAPE,     # Options
}
const COMBAT_BUTTONS := {
	JOY_BUTTON_RIGHT_SHOULDER: CombatLayer.R1,
	JOY_BUTTON_LEFT_SHOULDER: CombatLayer.L1,
}
const COMBAT_TRIGGERS := {
	JOY_AXIS_TRIGGER_RIGHT: CombatLayer.R2,
	JOY_AXIS_TRIGGER_LEFT: CombatLayer.L2,
}

## Our own synthetic events carry this device id, so they never count as
## the player going back to the keyboard.
const SYNTHETIC := 99
## Keyboard word -> button, whole words only, prompt text only.
const BUTTON_NAMES := {
	"WASD": "L-STICK", "MOUSE": "R-STICK", "LMB": "R1", "RMB": "L2", "MMB": "R2",
	"SPACE": "CROSS", "CTRL": "CIRCLE", "E": "SQUARE", "F": "TRIANGLE",
	"K": "D-UP", "SHIFT": "L3", "Z": "R3", "J": "D-DOWN", "4": "D-LEFT", "I": "D-RIGHT",
	"TAB": "TOUCHPAD", "ESC": "OPTIONS", "X": "L1", "G": "CREATE",
}

var using_pad := false
var _labels: Array[Label] = []
## label -> [text the scene set, text we showed]
var _swapped := {}
var _trigger_down := {}
var _flick := Vector2i.ZERO
const MIGRATED_SCENES := [
	"res://country_town_menu.tscn", "res://vat_chamber.tscn",
	"res://facility.tscn", "res://service_arcade.tscn", "res://support_unit.tscn",
	"res://buried_city.tscn", "res://old_drains.tscn",
	"res://doctor_vehicle_bay.tscn", "res://rift_derby.tscn",
	"res://derby_tunnels.tscn", "res://blood_waterfall_exit.tscn",
	"res://bone_yard_hunt.tscn",
]
var combat_layer_id := "souls_base"
var combat_layer: Dictionary = CombatLayer.souls_base()
var combat_context := "melee"
var _combat_receiver: Node = null
## Physical action -> verb emitted at press time. Release uses this saved verb,
## even if a discipline or weapon context changes while the control is held.
var _combat_down: Dictionary = {}


func _ready() -> void:
	name = "PadBridge"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After every scene script, so the swap sees this frame's prompt text.
	process_priority = 1000
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is Label:
			_labels.append(node))


## A prompt line with its key names as pad buttons, when the pad is in use.
func keys(text: String) -> String:
	var profile := get_node_or_null("/root/InputProfile")
	if profile != null:
		using_pad = bool(profile.using_pad)
	if not using_pad:
		return text
	# A key name is only swapped where a prompt puts one: first word of a
	# "//" segment, or after HOLD / PRESS. "FIND THE WIRES // 4 LEFT" is a
	# count, so digits need the HOLD.
	var words := text.split(" ")
	var segment_start := true
	for i in words.size():
		var bare := words[i].trim_prefix("[").trim_suffix("]")
		var after_verb := i > 0 and words[i - 1] in ["HOLD", "PRESS", "TAP"]
		var placed := after_verb or (segment_start and not bare.is_valid_int())
		if placed and BUTTON_NAMES.has(bare):
			words[i] = words[i].replace(bare, BUTTON_NAMES[bare])
		if words[i] != "":
			segment_start = words[i] == "//"
	return " ".join(words)


## Context-aware prompt conversion. `keys()` remains the generic fallback;
## combat HUDs and the controls sheet pass their verb so FIRE never inherits
## the melee LMB glyph and LIGHT never inherits the old trigger glyph.
func hint(key_text: String, verb_text: String, context := "") -> String:
	if not using_pad:
		return key_text
	var words := verb_text.to_upper()
	var wanted := ""
	var active_context := context if context != "" else combat_context
	if words.contains("VATS") or words.contains("AIMED X-RAY"):
		return "L2 + R2"
	if words.contains("HEAVY") or words.contains("GUARD BREAK"):
		wanted = "heavy"
	elif words.contains("PARRY"):
		wanted = "parry"
	elif words.contains("BLOCK") or words.contains("GUARD"):
		wanted = "block"
	elif words.contains("AIM"):
		wanted = "aim"
	elif words.contains("FIRE") or words.contains("SHOOT"):
		wanted = "fire"
	elif words.contains("LIGHT") or words.contains("ATTACK") or words.contains("STRIKE") or words.contains("PRESS THE HOLD"):
		wanted = "light"
	if wanted != "":
		var glyph := CombatLayer.glyph_for(combat_layer, wanted, active_context)
		if glyph != "":
			return ("HOLD " if key_text.begins_with("HOLD ") else "") + glyph
	return keys(key_text)


func set_combat_receiver(receiver: Node) -> void:
	_combat_receiver = receiver


func clear_combat_receiver(receiver: Node) -> void:
	if _combat_receiver == receiver:
		_release_combat_inputs()
		_combat_receiver = null
		combat_context = "melee"


func set_combat_context(context: String) -> void:
	if context == combat_context:
		return
	_release_combat_inputs()
	combat_context = context


## The discipline manager calls this with its sparse input-layer dictionary.
## Releasing first is the no-stuck-action contract for a mid-input swap.
func set_combat_layer(layer_id: String, overrides: Dictionary = {}) -> void:
	_release_combat_inputs()
	combat_layer_id = layer_id
	combat_layer = CombatLayer.with_overrides(overrides)


func reset_combat_layer() -> void:
	set_combat_layer("souls_base")


func combat_glyph(verb: String, context := "") -> String:
	return CombatLayer.glyph_for(combat_layer, verb, context if context != "" else combat_context)


static func is_prompt(text: String) -> bool:
	return text.contains("//") or text.begins_with("HOLD ") or text.contains("PRESS ")


func _swap_labels() -> void:
	var kept: Array[Label] = []
	for label in _labels:
		if not is_instance_valid(label):
			_swapped.erase(label)
			continue
		kept.append(label)
		var pair: Array = _swapped.get(label, ["", ""])
		var source := label.text if label.text != pair[1] else str(pair[0])
		if not is_prompt(source):
			continue
		var shown := keys(source)
		if label.text != shown:
			label.text = shown
		_swapped[label] = [source, shown]
	_labels = kept


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


## Native physical actions are the stable bottom layer pad-04 intended. A
## discipline remaps their verbs in data; legacy key/mouse synthesis happens
## only after that resolution and only for scenes without a semantic receiver.
func _bind_native_combat() -> void:
	for action in CombatLayer.PHYSICAL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
	for button_index in COMBAT_BUTTONS:
		var button_action: String = COMBAT_BUTTONS[button_index]
		if InputMap.action_get_events(button_action).any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton):
			continue
		var button := InputEventJoypadButton.new()
		button.button_index = button_index
		InputMap.action_add_event(button_action, button)
	for axis_index in COMBAT_TRIGGERS:
		var trigger_action: String = COMBAT_TRIGGERS[axis_index]
		if InputMap.action_get_events(trigger_action).any(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion):
			continue
		var trigger := InputEventJoypadMotion.new()
		trigger.axis = axis_index
		trigger.axis_value = 1.0
		InputMap.action_add_event(trigger_action, trigger)


func _input(event: InputEvent) -> void:
	if event.device != SYNTHETIC:
		if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
			using_pad = true
		elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0):
			using_pad = false
	if event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		if COMBAT_BUTTONS.has(pad.button_index):
			_dispatch_combat(COMBAT_BUTTONS[pad.button_index], pad.pressed)
			return
		if not _fallback_active():
			return
		# D-pad drives menus whenever a control has focus (the gameplay keys
		# K/J/4/I would do nothing there).
		var dpad := {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN, JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT}
		if dpad.has(pad.button_index) and get_viewport().gui_get_focus_owner() != null:
			if pad.pressed:
				_tap(dpad[pad.button_index])
			return
		if BUTTON_KEYS.has(pad.button_index):
			_send_key(BUTTON_KEYS[pad.button_index], pad.pressed)
	elif event is InputEventJoypadMotion:
		var axis := (event as InputEventJoypadMotion).axis
		if COMBAT_TRIGGERS.has(axis):
			var down := (event as InputEventJoypadMotion).axis_value > 0.5
			if down != bool(_trigger_down.get(axis, false)):
				_trigger_down[axis] = down
				_dispatch_combat(COMBAT_TRIGGERS[axis], down)


func _dispatch_combat(physical_action: String, pressed: bool) -> void:
	var verb := ""
	if pressed:
		if _combat_down.has(physical_action):
			return
		verb = CombatLayer.verb(combat_layer, physical_action, combat_context)
		_combat_down[physical_action] = verb
	else:
		if not _combat_down.has(physical_action):
			return
		verb = str(_combat_down[physical_action])
		_combat_down.erase(physical_action)
	if verb == "":
		return
	if is_instance_valid(_combat_receiver) and _combat_receiver.has_method("_pad_combat_verb"):
		_combat_receiver.call("_pad_combat_verb", verb, pressed)
		return
	# Only unmigrated scenes keep the legacy key/mouse path.
	if not _fallback_active():
		return
	match verb:
		"light", "fire": _send_mouse(MOUSE_BUTTON_LEFT, pressed)
		"heavy": _send_mouse(MOUSE_BUTTON_MIDDLE, pressed)
		"block": _send_key(KEY_X, pressed)
		"parry", "aim": _send_mouse(MOUSE_BUTTON_RIGHT, pressed)


func _release_combat_inputs() -> void:
	for physical_action in _combat_down.keys().duplicate():
		_dispatch_combat(str(physical_action), false)


func _process(delta: float) -> void:
	var profile := get_node_or_null("/root/InputProfile")
	if profile != null:
		using_pad = bool(profile.using_pad)
	_swap_labels()
	if Input.get_connected_joypads().is_empty() or not _fallback_active():
		return
	var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if look.length() > DEADZONE:
		var motion := InputEventMouseMotion.new()
		motion.device = SYNTHETIC
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


func _fallback_active() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return not str(scene.scene_file_path) in MIGRATED_SCENES


func _send_key(keycode: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.device = SYNTHETIC
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = pressed
	Input.parse_input_event(key)


func _tap(keycode: Key) -> void:
	_send_key(keycode, true)
	_send_key(keycode, false)


func _send_mouse(button: MouseButton, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.device = SYNTHETIC
	click.button_index = button
	click.pressed = pressed
	click.position = get_viewport().get_mouse_position()
	Input.parse_input_event(click)
