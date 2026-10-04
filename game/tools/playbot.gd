extends Node

## PlayBot: a file bridge that lets an outside agent play the demo the way a
## person does (Greg, 4 Oct: "a somewhat smart model to PLAY the demo like a
## human at human pace and report what is engaging, what bugs it hits, and
## what feels dumb or breaks immersion"). Usage is in `DESIGN/PLAYBOT.md`.
##
## Not an autoload, and it does nothing unless `ATG_PLAYBOT=1`. Run
## `res://tools/playbot.tscn` as the main scene: it hangs itself off the root
## (so it outlives every `change_scene_*`) and then loads the real start scene.
## The export preset excludes `tools/playbot*`, so shipping never sees it.
##
## The loop, all through files in `dir` (default P:/GameDev/AgentHub/playbot):
##   cmd.json      {"seq": N, "actions": [...]}, written by `tools/playbot_step.py`
##   shot_N.png    the viewport after command N (absent when headless: no pixels)
##   state.json    written last, so its `seq` means the shot is already on disk
##   events.jsonl  scene changes, loading screens, script errors, falls, stuck
##                 spots and invisible walls, one JSON object per line
##
## Actions go in through the same doors the player's do: `hold` / `press`
## inject the InputMap action's own key event (so code reading `KEY_E`
## directly hears it too), `pad` injects joypad buttons that `PadBridge`
## turns into keys, and `look` turns the scene's own `yaw` / `pitch` (or moves
## the mouse when a scene has none) at a capped rate -- no instant 180s.

const DEFAULT_DIR := "P:/GameDev/AgentHub/playbot"
## Degrees per second. A brisk human flick; a 180 takes most of a second.
const LOOK_RATE := 220.0
## Mouse fallback for scenes without `yaw`: matches the scenes' 0.0026 rad/px.
const MOUSE_RAD_PER_PX := 0.0026
const MAX_HOLD := 10.0
const MAX_WAIT := 10.0
const TAP := 0.12
const POLL := 0.2
const LOG_LINES := 20
## Seconds of acting with nothing changing (position, objective, prompt,
## scene) before it is called stuck. Greg's brief: 20 s.
const STUCK_AFTER := 20.0
## Metres below the lowest ground the player has stood on that counts as
## having fallen out of the world.
const FALL_DEPTH := 40.0

const PAD_BUTTONS := {
	"cross": JOY_BUTTON_A, "circle": JOY_BUTTON_B, "square": JOY_BUTTON_X,
	"triangle": JOY_BUTTON_Y, "l1": JOY_BUTTON_LEFT_SHOULDER,
	"r1": JOY_BUTTON_RIGHT_SHOULDER, "l3": JOY_BUTTON_LEFT_STICK,
	"r3": JOY_BUTTON_RIGHT_STICK, "up": JOY_BUTTON_DPAD_UP,
	"down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT,
	"right": JOY_BUTTON_DPAD_RIGHT, "touchpad": JOY_BUTTON_TOUCHPAD,
	"create": JOY_BUTTON_BACK, "options": JOY_BUTTON_START,
}
const PAD_TRIGGERS := {"l2": JOY_AXIS_TRIGGER_LEFT, "r2": JOY_AXIS_TRIGGER_RIGHT}
const MOUSE_BUTTONS := {"left": MOUSE_BUTTON_LEFT, "right": MOUSE_BUTTON_RIGHT, "middle": MOUSE_BUTTON_MIDDLE}


## Every print, warning and error, kept for `state.json` and turned into
## `script_error` events. Engine callbacks can arrive on any thread.
class Tap extends Logger:
	var lines: Array[String] = []
	var errors: Array[Dictionary] = []
	var mutex := Mutex.new()

	func _log_message(message: String, error: bool) -> void:
		mutex.lock()
		for line in message.strip_edges(false, true).split("\n"):
			lines.append(("ERR " if error else "") + line)
		while lines.size() > 200:
			lines.pop_front()
		mutex.unlock()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		var kind: String = ["error", "warning", "script_error", "shader_error"][clampi(error_type, 0, 3)]
		var text := rationale if not rationale.is_empty() else code
		mutex.lock()
		lines.append("%s: %s (%s:%d %s)" % [kind.to_upper(), text, file, line, function])
		errors.append({"kind": kind, "text": text, "file": file, "line": line, "function": function})
		mutex.unlock()

	func take_errors() -> Array[Dictionary]:
		mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		mutex.unlock()
		return out

	func tail(count: int) -> Array[String]:
		mutex.lock()
		var out := lines.slice(maxi(0, lines.size() - count))
		mutex.unlock()
		return out


## Bridge folder. `ATG_PLAYBOT_DIR` overrides it.
var dir := DEFAULT_DIR
## Tests bind a stub here instead of following `get_tree().current_scene`.
var scene_override: Node = null
var active := false
var stuck_after := STUCK_AFTER

var last_seq := 0
var _queue: Array = []
var _running_seq := 0
var _current: Dictionary = {}
var _current_left := 0.0
var _look_left := Vector2.ZERO
var _held: Array = []
var _poll_left := 0.0
var _cmd_mtime := 0
var _tap: Tap = null
var _clock := 0.0

var _scene_path := ""
var _scene_since := 0.0
var _travel_since := -1.0
var _travel_to := ""
var _dialogue := ""
var _dialogue_speaker := ""
var _lowest_ground := INF
var _fell_reported := false
var _progress_key := ""
var _no_progress := 0.0
var _stuck_reported := false
var _wall_seen := {}
var _events_this_cmd: Array = []


func _ready() -> void:
	if OS.get_environment("ATG_PLAYBOT") != "1":
		# Shipping and every normal run: not here at all.
		if get_tree().current_scene == self:
			get_tree().quit(2)
		queue_free()
		return
	if get_tree().current_scene == self and scene_override == null:
		_hand_off.call_deferred()
		return
	active = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	var env_dir := OS.get_environment("ATG_PLAYBOT_DIR")
	if not env_dir.is_empty():
		dir = env_dir
	DirAccess.make_dir_recursive_absolute(dir)
	# A stale command from a previous run must not replay.
	if FileAccess.file_exists(_path("cmd.json")):
		DirAccess.remove_absolute(_path("cmd.json"))
	_tap = Tap.new()
	OS.add_logger(_tap)
	var dialogue := get_node_or_null("/root/DialogueManager")
	if dialogue != null:
		dialogue.got_dialogue.connect(_on_dialogue_line)
		dialogue.dialogue_ended.connect(_on_dialogue_ended)
	_event({"type": "playbot_started", "dir": dir})
	_write_state()


func _exit_tree() -> void:
	if _tap != null:
		OS.remove_logger(_tap)
		_tap = null
	_release_all()


## Run as the main scene: this node is the current scene and would be freed
## by the first scene change, so a fresh PlayBot goes on the root beside the
## scenes and this one hands the tree to the game.
func _hand_off() -> void:
	var tree := get_tree()
	var target := OS.get_environment("ATG_PLAYBOT_START")
	if target.is_empty():
		target = str(ProjectSettings.get_setting("application/run/main_scene"))
	var bot: Node = (get_script() as Script).new()
	bot.name = "PlayBot"
	tree.root.add_child(bot)
	tree.change_scene_to_file(target)


func _path(file: String) -> String:
	return dir.path_join(file)


func scene() -> Node:
	if scene_override != null and is_instance_valid(scene_override):
		return scene_override
	return get_tree().current_scene


# --- loop ---------------------------------------------------------------

func _process(delta: float) -> void:
	if not active:
		return
	_clock += delta
	_watch_scene()
	_watch_interstitial()
	_watch_errors()
	_poll_left -= delta
	if _poll_left <= 0.0 and _running_seq == 0:
		_poll_left = POLL
		_poll_cmd()
	if _running_seq != 0:
		_step(delta)


func _physics_process(delta: float) -> void:
	if not active:
		return
	_watch_body(delta)


func _poll_cmd() -> void:
	var path := _path("cmd.json")
	if not FileAccess.file_exists(path):
		return
	var mtime := FileAccess.get_modified_time(path)
	if mtime == _cmd_mtime and _cmd_mtime != 0:
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return  # Half-written; next poll.
	_cmd_mtime = mtime
	var seq := int((parsed as Dictionary).get("seq", 0))
	if seq <= last_seq:
		return
	var actions: Variant = (parsed as Dictionary).get("actions", [])
	_queue = (actions as Array).duplicate() if actions is Array else []
	_running_seq = seq
	_current = {}


func _step(delta: float) -> void:
	if _current.is_empty():
		if _queue.is_empty():
			_finish()
			return
		var next: Variant = _queue.pop_front()
		if next is Dictionary:
			_begin(next)
		return
	_current_left -= delta
	if _current.has("look"):
		_turn(delta)
		if _look_left.length() < 0.01:
			_end_current()
		return
	if _current_left <= 0.0:
		_end_current()


func _begin(action: Dictionary) -> void:
	_current = action
	_current_left = 0.0
	if action.has("hold"):
		_current_left = clampf(float(action.get("s", 0.5)), 0.0, MAX_HOLD)
		var names: Array = action.hold if action.hold is Array else [action.hold]
		for name: Variant in names:
			_inject(str(name), true)
	elif action.has("press"):
		_current_left = TAP
		_inject(str(action.press), true)
	elif action.has("pad"):
		_current_left = clampf(float(action.get("s", TAP)), TAP, MAX_HOLD)
		_pad(str(action.pad).to_lower(), true)
	elif action.has("click"):
		_current_left = clampf(float(action.get("s", TAP)), TAP, MAX_HOLD)
		_mouse_button(str(action.click).to_lower(), true)
	elif action.has("look"):
		var look: Variant = action.look
		_look_left = Vector2(float(look[0]), float(look[1])) if look is Array and (look as Array).size() >= 2 else Vector2.ZERO
	elif action.has("wait"):
		_current_left = clampf(float(action.wait), 0.0, MAX_WAIT)
	else:
		_event({"type": "bad_action", "action": action})


func _end_current() -> void:
	_release_all()
	_current = {}


func _finish() -> void:
	_release_all()
	last_seq = _running_seq
	_running_seq = 0
	# Let the last input land on screen before the shot.
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	_write_state()


# --- input --------------------------------------------------------------

## An InputMap action injects its own first bound event (so code that reads
## `KEY_E` directly hears "interact" too). Anything else is a key name.
func _inject(name: String, pressed: bool) -> void:
	var event: InputEvent = null
	if InputMap.has_action(name):
		for bound: InputEvent in InputMap.action_get_events(name):
			if bound is InputEventKey or bound is InputEventMouseButton:
				event = bound.duplicate()
				break
		if event == null:
			var action_event := InputEventAction.new()
			action_event.action = name
			event = action_event
	else:
		var code := OS.find_keycode_from_string(name)
		if code == KEY_NONE:
			_event({"type": "bad_action", "input": name})
			return
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		event = key
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_NONE:
			key_event.keycode = key_event.physical_keycode
		if key_event.physical_keycode == KEY_NONE:
			key_event.physical_keycode = key_event.keycode
		key_event.pressed = pressed
	elif event is InputEventMouseButton:
		(event as InputEventMouseButton).pressed = pressed
	elif event is InputEventAction:
		(event as InputEventAction).pressed = pressed
	Input.parse_input_event(event)
	if pressed:
		_held.append(["input", name])


func _pad(name: String, pressed: bool) -> void:
	if PAD_BUTTONS.has(name):
		var button := InputEventJoypadButton.new()
		button.button_index = PAD_BUTTONS[name]
		button.pressed = pressed
		button.pressure = 1.0 if pressed else 0.0
		Input.parse_input_event(button)
	elif PAD_TRIGGERS.has(name):
		var axis := InputEventJoypadMotion.new()
		axis.axis = PAD_TRIGGERS[name]
		axis.axis_value = 1.0 if pressed else 0.0
		Input.parse_input_event(axis)
	else:
		_event({"type": "bad_action", "pad": name})
		return
	if pressed:
		_held.append(["pad", name])


func _mouse_button(name: String, pressed: bool) -> void:
	if not MOUSE_BUTTONS.has(name):
		_event({"type": "bad_action", "click": name})
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTONS[name]
	click.pressed = pressed
	click.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(click)
	if pressed:
		_held.append(["click", name])


func _release_all() -> void:
	var held := _held.duplicate()
	_held.clear()
	for row: Array in held:
		match row[0]:
			"input": _inject(row[1], false)
			"pad": _pad(row[1], false)
			"click": _mouse_button(row[1], false)
	_held.clear()


## `look` is degrees: +x turns right, +y looks up. Capped at LOOK_RATE.
func _turn(delta: float) -> void:
	var step := LOOK_RATE * delta
	var move := Vector2(clampf(_look_left.x, -step, step), clampf(_look_left.y, -step, step))
	_look_left -= move
	var target := scene()
	if target != null and target.get("yaw") is float:
		target.set("yaw", float(target.get("yaw")) - deg_to_rad(move.x))
		if target.get("pitch") is float:
			target.set("pitch", clampf(float(target.get("pitch")) + deg_to_rad(move.y), -1.45, 1.45))
		return
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(deg_to_rad(move.x), -deg_to_rad(move.y)) / MOUSE_RAD_PER_PX
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)


# --- watching -----------------------------------------------------------

func _watch_scene() -> void:
	var current := scene()
	var path := current.scene_file_path if current != null else ""
	if current != null and path.is_empty():
		path = str(current.get_path())
	if path == _scene_path:
		return
	if not _scene_path.is_empty():
		_event({"type": "scene_change", "from": _scene_path, "to": path, "seconds_in_previous": snappedf(_clock - _scene_since, 0.01)})
	_scene_path = path
	_scene_since = _clock
	_lowest_ground = INF
	_fell_reported = false
	_wall_seen.clear()
	_no_progress = 0.0
	_stuck_reported = false


func _watch_interstitial() -> void:
	var interstitial := get_node_or_null("/root/Interstitial")
	var travelling := interstitial != null and bool(interstitial.get("travelling"))
	if travelling and _travel_since < 0.0:
		_travel_since = _clock
		_travel_to = str(interstitial.get("destination"))
		_event({"type": "loading_start", "to": _travel_to, "caption": str(interstitial.get("caption"))})
	elif not travelling and _travel_since >= 0.0:
		_event({"type": "loading_end", "to": _travel_to, "seconds": snappedf(_clock - _travel_since, 0.01)})
		_travel_since = -1.0


func _watch_errors() -> void:
	if _tap == null:
		return
	for row: Dictionary in _tap.take_errors():
		if row.kind == "warning":
			continue
		var event := row.duplicate()
		event.type = "script_error"
		event.kind = row.kind
		_event(event)


func _watch_body(delta: float) -> void:
	var body := player_body()
	if body == null:
		return
	var at := body.global_position
	# Falling out of the world.
	if body is CharacterBody3D and (body as CharacterBody3D).is_on_floor():
		_lowest_ground = minf(_lowest_ground, at.y)
	if not _fell_reported and _lowest_ground < INF and at.y < _lowest_ground - FALL_DEPTH:
		_fell_reported = true
		_event({"type": "fell_through_floor", "position": _vec(at), "lowest_ground_y": snappedf(_lowest_ground, 0.01)})
	# Stuck: acting, and nothing that matters has changed.
	var key := "%s|%d,%d,%d|%s|%s" % [_scene_path, roundi(at.x), roundi(at.y), roundi(at.z), _label_text("Objective"), _label_text("Prompt")]
	if key != _progress_key:
		_progress_key = key
		_no_progress = 0.0
		_stuck_reported = false
	elif _running_seq != 0:
		_no_progress += delta
		if _no_progress >= stuck_after and not _stuck_reported:
			_stuck_reported = true
			_event({"type": "stuck", "seconds": snappedf(_no_progress, 0.1), "position": _vec(at), "action": _current})
	# Invisible walls: pushing into something with nothing drawn on it.
	if body is CharacterBody3D and _is_moving():
		var character := body as CharacterBody3D
		for index in character.get_slide_collision_count():
			var collision := character.get_slide_collision(index)
			var normal := collision.get_normal()
			if absf(normal.y) > 0.6:
				continue  # Floors and ceilings.
			var collider := collision.get_collider() as Node
			if collider == null or _wall_seen.has(collider.get_instance_id()):
				continue
			if not _has_visual(collider):
				_wall_seen[collider.get_instance_id()] = true
				_event({"type": "invisible_wall", "collider": str(collider.get_path()), "position": _vec(collision.get_position())})


func _is_moving() -> bool:
	for row: Array in _held:
		if row[0] == "input" and str(row[1]).begins_with("move_"):
			return true
	return false


## A collider counts as seen when it, its parent or its children draw
## something visible.
func _has_visual(collider: Node) -> bool:
	var candidates: Array[Node] = [collider]
	if collider.get_parent() != null:
		candidates.append(collider.get_parent())
	for node in candidates:
		if node is VisualInstance3D and (node as VisualInstance3D).is_visible_in_tree():
			return true
		for child in node.get_children():
			if child is VisualInstance3D and (child as VisualInstance3D).is_visible_in_tree():
				return true
	return false


func player_body() -> Node3D:
	var target := scene()
	if target == null:
		return null
	for property in ["player_body", "player"]:
		var value: Variant = target.get(property)
		if value is Node3D and is_instance_valid(value) and (value as Node3D).is_inside_tree():
			return value
	return null


func player_position() -> Variant:
	var body := player_body()
	if body != null:
		return body.global_position
	var target := scene()
	if target != null and target.get("player") is Vector3:
		return target.get("player")
	return null


func _on_dialogue_line(line: Variant) -> void:
	_dialogue = str(line.get("text")) if line != null else ""
	_dialogue_speaker = str(line.get("character")) if line != null else ""


func _on_dialogue_ended(_resource: Variant) -> void:
	_dialogue = ""
	_dialogue_speaker = ""


# --- reading the screen -------------------------------------------------

## HUD labels the scenes share by name (`$HUD/Objective`, `$HUD/Prompt`).
func _label_text(label_name: String) -> String:
	var target := scene()
	if target == null:
		return ""
	var node := target.find_child(label_name, true, false)
	if node is Label and (node as Label).is_visible_in_tree():
		return (node as Label).text
	if node is RichTextLabel and (node as RichTextLabel).is_visible_in_tree():
		return (node as RichTextLabel).get_parsed_text()
	return ""


## Only what is on screen: a scene's `objective_text` can exist long before
## the label shows it (the vat holds it back until the escape exists).
func _objective() -> String:
	return _label_text("Objective")


func _health() -> Variant:
	for holder in [player_body(), scene()]:
		if holder == null:
			continue
		for property in ["health", "hp"]:
			var value: Variant = holder.get(property)
			if value is int or value is float:
				return value
	return null


func state() -> Dictionary:
	var interstitial := get_node_or_null("/root/Interstitial")
	var position: Variant = player_position()
	var target := scene()
	return {
		"seq": last_seq,
		"clock": snappedf(_clock, 0.01),
		"scene": _scene_path,
		"seconds_in_scene": snappedf(_clock - _scene_since, 0.01),
		"position": _vec(position) if position is Vector3 else null,
		"yaw_deg": snappedf(rad_to_deg(float(target.get("yaw"))), 0.1) if target != null and target.get("yaw") is float else null,
		"health": _health(),
		"objective": _objective(),
		"prompt": _label_text("Prompt"),
		"dialogue": _dialogue,
		"dialogue_speaker": _dialogue_speaker,
		"interstitial_travelling": interstitial != null and bool(interstitial.get("travelling")),
		"fps": Engine.get_frames_per_second(),
		"paused": get_tree().paused,
		"mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"log": _tap.tail(LOG_LINES) if _tap != null else [],
		"events": _events_this_cmd.duplicate(),
		"screenshot": null,
	}


func _write_state() -> void:
	var out := state()
	var image := get_viewport().get_texture().get_image() if DisplayServer.get_name() != "headless" else null
	if image != null and not image.is_empty():
		var shot := _path("shot_%d.png" % last_seq)
		if image.save_png(shot) == OK:
			out.screenshot = shot
	else:
		out.screenshot_note = "headless: the renderer draws no pixels"
	var temp := _path("state.json.tmp")
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("PlayBot cannot write %s" % temp)
		return
	file.store_string(JSON.stringify(out, "  "))
	file.close()
	_events_this_cmd.clear()
	DirAccess.rename_absolute(temp, _path("state.json"))


func _event(row: Dictionary) -> void:
	row["t"] = snappedf(_clock, 0.01)
	row["seq"] = _running_seq if _running_seq != 0 else last_seq
	if not row.has("scene"):
		row["scene"] = _scene_path
	_events_this_cmd.append(row)
	var path := _path("events.jsonl")
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(row))
	file.close()


static func _vec(at: Vector3) -> Array:
	return [snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01)]
