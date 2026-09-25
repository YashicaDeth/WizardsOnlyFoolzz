class_name CuriosityBot
extends Node

## A player that is interested in the game (Greg, 24 September: "make an ai
## that is interested in playing the game ... to learn what to make the
## funnest normal gameplay exploration is"). DESIGN/OVERWORLD_EVENTS.md,
## assistant proposal: "interest is novelty with boredom".
##
## It plays a scene the way a person does -- through the game's own input
## actions (`move_forward`, `sprint`, ...), synthetic key presses for verbs
## (E by default) and the scene's own `yaw` / `pitch` for looking -- and it
## only MEASURES. Nothing here changes a scene's rules.
##
## What pulls it: grid cells it has not stood in, things it has not seen
## (other bodies, interactables the scene registers, areas, props, signs,
## lights), prompt lines it has not read, and WorldHistory event types it has
## not caused. What pushes it away: time spent on one thing, and the same kind
## of thing or the same event type coming round again (boredom). It records
## how long each thing held it, what it walked away from and why, which
## events kept it attending, and where it got stuck.
##
## Bind it with `bind(scene)`; it drives in `_physics_process` and writes its
## findings through `report()` / `markdown()`.

## Coarse spatial grid, metres per cell.
@export var cell_size := 4.0
## How far it notices things.
@export var view_radius := 22.0
## Within this, time counts as "near" a thing.
@export var near_radius := 4.0
## Within this, it stops walking and attends (looks, presses verbs).
@export var attend_radius := 2.4
## Seconds of commanded movement with almost no displacement = blocked.
@export var stuck_window := 3.0
## Seconds with no new cell, thing, prompt or event type = stale.
@export var stale_window := 45.0
## Keys it tries on things. Key names as `OS.find_keycode_from_string` reads them.
@export var verbs: Array[String] = ["E"]
## Keys it tries when blocked, after backing off.
@export var unstick_keys: Array[String] = ["Space"]
## Baseline for comparison: wanders on random headings, ignores interest.
@export var random_walk := false
## Radians per second it can turn; a person, not an aimbot.
@export var turn_rate := 3.2

const THING_WEIGHT := {
	"interactable": 1.6,
	"body": 1.35,
	"rigid": 0.9,
	"scripted": 0.75,
	"area": 0.6,
	"sign": 0.6,
	"light": 0.3,
}
const MAX_ATTEND := 90.0
const MAX_THINGS := 1500
const SCAN_NODE_BUDGET := 60000

var rng := RandomNumberGenerator.new()
var scene: Node
var body: Node3D
var sim_time := 0.0
var enabled := true

# --- memory -----------------------------------------------------------------
var visited := {}          ## Vector2i -> seconds stood in it
var cell_first := {}       ## Vector2i -> sim time first entered
var cell_open := {}        ## Vector2i -> bool, floor under the cell centre
var cell_fail := {}        ## Vector2i -> attempts that ended blocked
var things := {}           ## instance id -> record (see _note_thing)
var kind_boredom := {}     ## thing kind -> boredom
var event_stats := {}      ## event type -> record
var prompts_seen := {}     ## normalised prompt text -> {count, first_at}
var episodes: Array = []   ## every focus it had on a thing, in order
var walked_away: Array = []
var stuck_spots := {}      ## Vector2i -> record
var distance_walked := 0.0
var cells_reached_as_targets := 0
var verb_presses := 0
var scene_log: Array = []

# --- control state ----------------------------------------------------------
var focus := {}
var last_novel_at := 0.0
var last_stale_mark := -INF
var heading_offset := 0.0
var calibrated := false
var move_history: Array = []  ## [time, position, commanding]
var last_pos := Vector3.ZERO
var perceive_clock := 0.0
var scan_clock := 99.0
var choose_clock := 0.0
var verb_clock := 0.0
var verb_index := 0
var last_verb_at := -INF
var unstick_until := -INF
var unstick_heading := 0.0
var unstick_side := 0  ## 0 backs off and turns; -1 / 1 sidesteps left / right
var random_heading := 0.0
var random_until := 0.0
var held_keys := {}        ## keycode -> release sim time
var pressed_actions := {}
var candidates: Array = [] ## node refs from the last scan


func _ready() -> void:
	process_physics_priority = -100


func bind(target: Node) -> void:
	_release_all()
	if scene != null and scene != target:
		_close_focus("scene_changed")
	scene = target
	body = null
	calibrated = false
	scan_clock = 99.0
	candidates.clear()
	scene_log.append({"at": snappedf(sim_time, 0.1), "scene": target.scene_file_path if target.scene_file_path != "" else str(target.name)})
	if not WorldHistory.event_recorded.is_connected(_on_event):
		WorldHistory.event_recorded.connect(_on_event)
	last_novel_at = sim_time


func _exit_tree() -> void:
	_release_all()
	if WorldHistory.event_recorded.is_connected(_on_event):
		WorldHistory.event_recorded.disconnect(_on_event)


# ============================================================================
# The loop
# ============================================================================

func _physics_process(delta: float) -> void:
	if not enabled or scene == null or not is_instance_valid(scene):
		return
	var pos: Variant = player_position()
	if pos == null:
		return
	var here: Vector3 = pos
	sim_time += delta
	_release_due_keys()
	if sim_time > delta * 1.5:
		var step := Vector2(here.x - last_pos.x, here.z - last_pos.z).length()
		if step < 5.0:
			distance_walked += step
	last_pos = here
	_note_cell(here, delta)
	perceive_clock -= delta
	scan_clock += delta
	if perceive_clock <= 0.0:
		perceive_clock = 0.25
		_perceive(here, 0.25)
	_track_motion(here)
	if random_walk:
		_drive_random(here, delta)
	else:
		_drive_curious(here, delta)
	if sim_time - last_novel_at > stale_window and sim_time - last_stale_mark > stale_window:
		last_stale_mark = sim_time
		_mark_stuck(here, "stale", "nothing new for %d s" % int(stale_window))


# ============================================================================
# Body and look
# ============================================================================

## The player's feet, read off whatever the scene calls its player.
func player_position() -> Variant:
	if body != null and is_instance_valid(body) and body.is_inside_tree():
		return body.global_position
	body = null
	for property in ["player_body", "player"]:
		var value: Variant = scene.get(property)
		if value is Node3D and is_instance_valid(value) and (value as Node3D).is_inside_tree():
			body = value
			return body.global_position
	var value: Variant = scene.get("player")
	if value is Vector3:
		return value
	return null


func _get_yaw() -> float:
	var value: Variant = scene.get("yaw")
	if value is float:
		return value
	if body != null:
		return body.rotation.y
	return 0.0


## Turns toward a world heading (atan2(x, z) of travel) at a human rate.
func _turn_toward(heading: float, delta: float) -> float:
	var yaw := _get_yaw()
	var want := heading - heading_offset
	var diff := wrapf(want - yaw, -PI, PI)
	var turned := clampf(diff, -turn_rate * delta, turn_rate * delta)
	if scene.get("yaw") is float:
		scene.set("yaw", yaw + turned)
	else:
		# No yaw to hold: move the mouse, the way a person would.
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-turned / 0.0026, 0.0)
		Input.parse_input_event(motion)
	return absf(diff - turned)


func _pitch_toward(target_pitch: float, delta: float) -> void:
	var value: Variant = scene.get("pitch")
	if value is float:
		scene.set("pitch", move_toward(value, target_pitch, 1.6 * delta))


func _press(action: String, on: bool) -> void:
	if not InputMap.has_action(action):
		return
	if on and not pressed_actions.has(action):
		Input.action_press(action)
		pressed_actions[action] = true
	elif not on and pressed_actions.has(action):
		Input.action_release(action)
		pressed_actions.erase(action)


func _walk(forward: bool, back := false, left := false, right := false, sprint := false) -> void:
	_press("move_forward", forward)
	_press("move_back", back)
	_press("move_left", left)
	_press("move_right", right)
	_press("sprint", sprint)


func _tap_key(key_name: String) -> void:
	var code := OS.find_keycode_from_string(key_name)
	if code == KEY_NONE:
		return
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	held_keys[code] = sim_time + 0.12


func _release_due_keys() -> void:
	for code: int in held_keys.keys():
		if sim_time >= float(held_keys[code]):
			var event := InputEventKey.new()
			event.keycode = code as Key
			event.physical_keycode = code as Key
			event.pressed = false
			Input.parse_input_event(event)
			held_keys.erase(code)


func _release_all() -> void:
	for action: String in pressed_actions.keys():
		Input.action_release(action)
	pressed_actions.clear()
	for code: int in held_keys.keys():
		held_keys[code] = -INF
	if scene != null or not held_keys.is_empty():
		_release_due_keys()


# ============================================================================
# Perception
# ============================================================================

func _cell_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / cell_size), floori(at.z / cell_size))


func _cell_centre(cell: Vector2i, y: float) -> Vector3:
	return Vector3((cell.x + 0.5) * cell_size, y, (cell.y + 0.5) * cell_size)


func _note_cell(at: Vector3, delta: float) -> void:
	var cell := _cell_of(at)
	if not visited.has(cell):
		visited[cell] = 0.0
		cell_first[cell] = sim_time
		cell_open[cell] = true
		_novel()
	visited[cell] = float(visited[cell]) + delta


func _novel() -> void:
	last_novel_at = sim_time


## The scene's interesting nodes. Walls and meshes are scenery; bodies,
## areas, scripted props, signs and lights are things.
func _scan() -> void:
	candidates.clear()
	var registered := {}
	var list: Variant = scene.get("world_interactables")
	if list is Array:
		for entry: Variant in list:
			if entry is Dictionary and is_instance_valid((entry as Dictionary).get("node")):
				var node: Node = (entry as Dictionary).get("node")
				registered[node.get_instance_id()] = str((entry as Dictionary).get("prompt", ""))
	var stack: Array[Node] = [scene]
	var budget := SCAN_NODE_BUDGET
	while not stack.is_empty() and budget > 0 and candidates.size() < MAX_THINGS:
		var node: Node = stack.pop_back()
		budget -= 1
		if node == body or node == self:
			continue
		if node is Node3D and node != scene:
			var category := _category(node, registered)
			if category != "":
				candidates.append({"node": node, "category": category, "prompt": registered.get(node.get_instance_id(), "")})
				# A creature's hitboxes and rig are the creature, not more
				# things. Scripted nodes sitting at the origin are usually
				# containers, so those are still looked inside.
				if category != "light" and category != "sign" and not (category == "scripted" and (node as Node3D).global_position.length() < 0.01):
					continue
		for child in node.get_children():
			stack.append(child)


func _category(node: Node, registered: Dictionary) -> String:
	if registered.has(node.get_instance_id()):
		return "interactable"
	if node is CharacterBody3D:
		return "body"
	if node is RigidBody3D:
		return "rigid"
	if node is Area3D:
		return "area"
	if node is Label3D:
		return "sign"
	if node is OmniLight3D or node is SpotLight3D:
		return "light"
	var script: Script = node.get_script()
	if script != null and not (node is MeshInstance3D or node is CollisionShape3D or node is StaticBody3D or node is Camera3D):
		return "scripted"
	return ""


func _kind_of(node: Node, category: String, prompt_text: String) -> String:
	var script: Script = node.get_script()
	var name := ""
	if script != null:
		name = str(script.get_global_name())
		if name == "":
			name = script.resource_path.get_file().get_basename()
	if name == "":
		name = node.get_class()
	if category == "interactable" and prompt_text != "":
		return "interactable:" + _normalise(prompt_text).left(40)
	if category == "sign" and node is Label3D:
		return "sign:" + _normalise((node as Label3D).text).left(32)
	return category + ":" + name


func _normalise(text: String) -> String:
	var out := ""
	for ch in text.strip_edges().to_upper():
		out += "#" if ch >= "0" and ch <= "9" else ch
	return out.replace("\n", " ")


func _perceive(here: Vector3, elapsed: float) -> void:
	if scan_clock > 4.0:
		scan_clock = 0.0
		_scan()
	var facing := _get_yaw() + heading_offset
	var forward := Vector3(sin(facing), 0.0, cos(facing))
	var rays := 24
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state if body != null else null
	for entry: Dictionary in candidates:
		var node: Variant = entry.node
		if not is_instance_valid(node) or not (node as Node3D).is_inside_tree():
			continue
		var at: Vector3 = (node as Node3D).global_position
		var distance := at.distance_to(here)
		var id: int = (node as Node).get_instance_id()
		if things.has(id):
			var record: Dictionary = things[id]
			# Weather, air and other systems that ride along on the player
			# are not things a person walks up to.
			# They copy the player's x/z exactly from the first frame; a
			# creature that walks up and stands in you stays a thing.
			if record.born_on_player and Vector2(at.x - here.x, at.z - here.z).length() < 0.15 and (at - (record.pos as Vector3)).length() > 0.3:
				record.follows = int(record.follows) + 1
				if int(record.follows) >= 4 and not record.rides_along:
					record.rides_along = true
					if not focus.is_empty() and focus.get("id") == id:
						_close_focus("rides_along")
			record.pos = at
			if distance <= near_radius:
				record.near_s = float(record.near_s) + elapsed
			continue
		if distance > view_radius:
			continue
		var flat := Vector3(at.x - here.x, 0.0, at.z - here.z)
		var in_view := distance < 3.0 or (flat.length() > 0.01 and forward.dot(flat.normalized()) > 0.1)
		if not in_view:
			continue
		if space != null and rays > 0 and distance > 3.0:
			rays -= 1
			var eye := here + Vector3.UP * 1.4
			var query := PhysicsRayQueryParameters3D.create(eye, at)
			if body is CollisionObject3D:
				query.exclude = [(body as CollisionObject3D).get_rid()]
			if node is CollisionObject3D:
				query.exclude.append((node as CollisionObject3D).get_rid())
			var hit := space.intersect_ray(query)
			if not hit.is_empty() and (hit.position as Vector3).distance_to(at) > 1.2:
				continue
		elif distance > 3.0:
			continue
		_note_thing(node, entry)
	_read_prompt()


func _note_thing(node: Node3D, entry: Dictionary) -> void:
	var category: String = entry.category
	var kind := _kind_of(node, category, str(entry.prompt))
	things[node.get_instance_id()] = {
		"node": node,
		"name": str(node.name),
		"kind": kind,
		"category": category,
		"pos": node.global_position,
		"first_seen": snappedf(sim_time, 0.1),
		"near_s": 0.0,
		"attend_s": 0.0,
		"visits": 0,
		"verbs": 0,
		"events": {},
		"left": {},
		"abandoned_until": -INF,
		"follows": 0,
		"born_on_player": Vector2(node.global_position.x - last_pos.x, node.global_position.z - last_pos.z).length() < 0.15,
		"rides_along": false,
	}
	_novel()


func _read_prompt() -> void:
	var label: Variant = scene.get("prompt")
	if not (label is Label) or not is_instance_valid(label) or not (label as Label).is_visible_in_tree():
		return
	var text := _normalise((label as Label).text)
	if text == "":
		return
	if not prompts_seen.has(text):
		prompts_seen[text] = {"count": 0, "first_at": snappedf(sim_time, 0.1), "cell": var_to_str(_cell_of(last_pos))}
		_novel()
		if not focus.is_empty():
			focus.interest = float(focus.interest) + 0.35
	prompts_seen[text].count = int(prompts_seen[text].count) + 1


func _on_event(event: Dictionary) -> void:
	if scene == null:
		return
	var type := str(event.get("type", "?"))
	if not event_stats.has(type):
		event_stats[type] = {"count": 0, "hold_s": 0.0, "first_at": snappedf(sim_time, 0.1), "after_verb": 0, "near": {}}
		_novel()
	var stats: Dictionary = event_stats[type]
	stats.count = int(stats.count) + 1
	if sim_time - last_verb_at < 1.0:
		stats.after_verb = int(stats.after_verb) + 1
	for record: Dictionary in things.values():
		if (record.pos as Vector3).distance_to(last_pos) <= near_radius:
			record.events[type] = int(record.events.get(type, 0)) + 1
			stats.near[record.kind] = int(stats.near.get(record.kind, 0)) + 1
	if not focus.is_empty():
		focus.events.append({"type": type, "at": sim_time})
		# A new kind of consequence holds it; the hundredth of one does not.
		focus.interest = float(focus.interest) + 0.9 / float(stats.count * stats.count)


# ============================================================================
# Deciding
# ============================================================================

func _thing_interest(record: Dictionary) -> float:
	var weight: float = THING_WEIGHT.get(record.category, 0.5)
	var boredom := float(kind_boredom.get(record.kind, 0.0))
	var fatigue := exp(-float(record.attend_s) / 20.0)
	return weight * fatigue / (1.0 + boredom)


func _choose(here: Vector3) -> void:
	var best := _best_target(here)
	_open_focus(best, float(best.score))


## The most interesting target from here, without committing to it.
func _best_target(here: Vector3) -> Dictionary:
	var best := {}
	var best_score := 0.0
	for id: int in things:
		var record: Dictionary = things[id]
		if not is_instance_valid(record.node) or record.rides_along or sim_time < float(record.abandoned_until):
			continue
		var distance := (record.pos as Vector3).distance_to(here)
		if distance > view_radius * 1.6:
			continue
		var score := _thing_interest(record) / (1.0 + distance / 10.0)
		if score > best_score:
			best_score = score
			best = {"type": "thing", "id": id, "key": record.kind, "label": "%s '%s'" % [record.kind, record.name]}
	var facing := _get_yaw() + heading_offset
	for cell: Vector2i in _frontier(here):
		var centre := _cell_centre(cell, here.y)
		var offset := centre - here
		offset.y = 0.0
		var distance := offset.length()
		var along := Vector3(sin(facing), 0, cos(facing)).dot(offset.normalized()) if distance > 0.1 else 0.0
		var score := 0.7 / (1.0 + distance / 8.0) * (1.0 + 0.25 * along) / (1.0 + float(cell_fail.get(cell, 0)))
		score *= 0.9 + rng.randf() * 0.2
		if score > best_score:
			best_score = score
			best = {"type": "cell", "cell": cell, "key": "cell", "label": "unvisited cell %s" % var_to_str(cell)}
	if best.is_empty():
		# Everything known is worn out: wander somewhere far.
		var heading := rng.randf() * TAU
		best = {"type": "wander", "key": "wander", "label": "wander", "target": here + Vector3(sin(heading), 0, cos(heading)) * 20.0}
	best.score = best_score
	return best


## Unvisited cells next to visited ones, with a floor under them.
func _frontier(here: Vector3, limit := 40.0) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var reach := int(ceil(limit / cell_size))
	var centre := _cell_of(here)
	for cell: Vector2i in visited:
		if absi(cell.x - centre.x) > reach or absi(cell.y - centre.y) > reach:
			continue
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if visited.has(next) or int(cell_fail.get(next, 0)) >= 3:
				continue
			if not cell_open.has(next):
				cell_open[next] = _has_floor(next, here.y)
			if cell_open[next] and not out.has(next):
				out.append(next)
	return out


func _has_floor(cell: Vector2i, y: float) -> bool:
	if body == null:
		return true
	var space := body.get_world_3d().direct_space_state
	var centre := _cell_centre(cell, y)
	var query := PhysicsRayQueryParameters3D.create(centre + Vector3.UP * 2.5, centre + Vector3.DOWN * 4.0)
	if body is CollisionObject3D:
		query.exclude = [(body as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	# A ceiling slab hit from inside a tunnel is not a floor.
	return (hit.position as Vector3).y < y + 1.2


func _open_focus(target: Dictionary, score: float) -> void:
	focus = target.duplicate()
	focus.start = sim_time
	focus.interest = 1.0
	focus.score = score
	focus.events = []
	focus.fails = 0
	focus.arrived = false
	focus.verbs = 0
	if focus.type == "thing":
		things[focus.id].visits = int(things[focus.id].visits) + 1


func _close_focus(reason: String) -> void:
	if focus.is_empty():
		return
	var duration := sim_time - float(focus.start)
	# Each event is credited with the attention that followed it, up to the
	# next event or the moment it walked away, so the totals never overlap.
	var trail: Array = focus.events
	for index in trail.size():
		var event: Dictionary = trail[index]
		var until := sim_time if index == trail.size() - 1 else float(trail[index + 1].at)
		var stats: Dictionary = event_stats.get(event.type, {})
		if not stats.is_empty():
			stats.hold_s = float(stats.hold_s) + (until - float(event.at))
	if focus.type == "thing":
		var record: Dictionary = things.get(focus.id, {})
		var types := {}
		for event: Dictionary in focus.events:
			types[event.type] = true
		var episode := {
			"thing": focus.label,
			"kind": focus.key,
			"start": snappedf(float(focus.start), 0.1),
			"seconds": snappedf(duration, 0.1),
			"attended": focus.arrived,
			"verbs": focus.verbs,
			"events": types.keys(),
			"reason": reason,
		}
		episodes.append(episode)
		if not record.is_empty():
			record.left[reason] = int(record.left.get(reason, 0)) + 1
		if focus.arrived and reason != "scene_changed":
			walked_away.append(episode)
		if reason in ["bored", "stuck", "unreachable"] and not record.is_empty():
			record.abandoned_until = sim_time + (60.0 if reason == "bored" else 45.0)
		if reason == "bored":
			kind_boredom[focus.key] = float(kind_boredom.get(focus.key, 0.0)) + 0.6
	elif focus.type == "cell":
		if reason == "reached":
			cells_reached_as_targets += 1
		elif reason in ["stuck", "unreachable"]:
			cell_fail[focus.cell] = int(cell_fail.get(focus.cell, 0)) + 1
	focus = {}


func _focus_position(here: Vector3) -> Variant:
	match str(focus.type):
		"thing":
			var record: Dictionary = things.get(focus.id, {})
			if record.is_empty() or not is_instance_valid(record.node):
				return null
			return record.pos
		"cell":
			return _cell_centre(focus.cell, here.y)
		_:
			return focus.target


func _drive_curious(here: Vector3, delta: float) -> void:
	if sim_time < unstick_until:
		if unstick_side == 0:
			_turn_toward(unstick_heading, delta)
			_walk(true)
		else:
			# Keep pushing on and slide sideways along whatever stopped it.
			_walk(true, false, unstick_side < 0, unstick_side > 0)
		return
	choose_clock -= delta
	if focus.is_empty():
		_choose(here)
		choose_clock = 1.0
	var target: Variant = _focus_position(here)
	if target == null:
		_close_focus("vanished")
		_walk(false)
		return
	var goal: Vector3 = target
	var offset := goal - here
	offset.y = 0.0
	var distance := offset.length()
	var elapsed := sim_time - float(focus.start)
	match str(focus.type):
		"cell":
			if _cell_of(here) == focus.cell:
				_close_focus("reached")
				return
			if elapsed > 25.0:
				_close_focus("unreachable")
				return
		"wander":
			if distance < 2.0 or elapsed > 15.0:
				_close_focus("reached")
				return
	# Something new and brighter in view pulls it off a walk.
	if choose_clock <= 0.0 and not focus.arrived:
		choose_clock = 1.0
		var alternative := _best_target(here)
		if float(alternative.score) > float(focus.score) * 1.5 and str(alternative.label) != str(focus.label):
			_close_focus("distracted")
			_open_focus(alternative, float(alternative.score))
			return
	if focus.type == "thing" and distance <= attend_radius:
		_attend(here, goal, delta)
		return
	if focus.type == "thing" and elapsed > 40.0 and not focus.arrived:
		_close_focus("unreachable")
		return
	var heading := atan2(offset.x, offset.z)
	var remaining := _turn_toward(heading, delta)
	_pitch_toward(-0.05, delta)
	_walk(remaining < 1.0, false, false, false, distance > 14.0)


func _attend(here: Vector3, goal: Vector3, delta: float) -> void:
	var record: Dictionary = things[focus.id]
	if not focus.arrived:
		focus.arrived = true
		focus.arrived_at = sim_time
		verb_clock = 0.4
	_walk(false)
	var offset := goal - here
	_turn_toward(atan2(offset.x, offset.z), delta)
	var flat := Vector2(offset.x, offset.z).length()
	_pitch_toward(clampf(atan2(goal.y - (here.y + 1.4), maxf(flat, 0.3)), -0.9, 0.7), delta)
	record.attend_s = float(record.attend_s) + delta
	verb_clock -= delta
	if verb_clock <= 0.0 and int(focus.verbs) < 8 and not verbs.is_empty():
		verb_clock = 1.3
		_tap_key(verbs[verb_index % verbs.size()])
		verb_index += 1
		verb_presses += 1
		last_verb_at = sim_time
		focus.verbs = int(focus.verbs) + 1
		record.verbs = int(record.verbs) + 1
	var boredom := float(kind_boredom.get(focus.key, 0.0))
	focus.interest = float(focus.interest) - delta * (0.12 + 0.06 * boredom)
	if float(focus.interest) < 0.15:
		_close_focus("bored")
	elif sim_time - float(focus.arrived_at) > MAX_ATTEND:
		_close_focus("bored")


func _drive_random(here: Vector3, delta: float) -> void:
	if sim_time >= random_until:
		random_heading = rng.randf() * TAU
		random_until = sim_time + rng.randf_range(2.0, 4.0)
	var heading := unstick_heading if sim_time < unstick_until else random_heading
	var remaining := _turn_toward(heading, delta)
	_walk(remaining < 1.0)


# ============================================================================
# Stuck
# ============================================================================

func _track_motion(here: Vector3) -> void:
	var commanding := pressed_actions.has("move_forward") or pressed_actions.has("move_back")
	move_history.append([sim_time, here, commanding])
	while move_history.size() > 2 and sim_time - float(move_history[0][0]) > stuck_window:
		move_history.pop_front()
	# Learn which way "forward" really points in this scene.
	if pressed_actions.has("move_forward") and move_history.size() > 10 and sim_time >= unstick_until:
		var start: Array = move_history[maxi(0, move_history.size() - 20)]
		var moved: Vector3 = here - (start[1] as Vector3)
		moved.y = 0.0
		var measured := wrapf(atan2(moved.x, moved.z) - _get_yaw(), -PI, PI)
		if moved.length() > 0.25 and not calibrated:
			heading_offset = measured
			calibrated = true
		elif moved.length() > 1.0 and absf(wrapf(measured - heading_offset, -PI, PI)) < 0.5:
			# Small corrections only; a slide along a wall is not a new forward.
			heading_offset = wrapf(heading_offset + 0.1 * wrapf(measured - heading_offset, -PI, PI), -PI, PI)
	if sim_time - float(move_history[0][0]) < stuck_window * 0.95:
		return
	for sample: Array in move_history:
		if not sample[2]:
			return
	var travelled: Vector3 = here - (move_history[0][1] as Vector3)
	travelled.y = 0.0
	if travelled.length() < 0.4:
		_mark_stuck(here, "blocked", str(focus.get("label", "wandering")))
		move_history.clear()
		# Back off, try a jump, and pick a new way.
		for key_name in unstick_keys:
			_tap_key(key_name)
		# A person tries sidestepping first, then turning round.
		var attempts := int(stuck_spots[_cell_of(here)].blocked)
		unstick_side = 0 if attempts % 3 == 0 else (-1 if rng.randf() < 0.5 else 1)
		unstick_heading = _get_yaw() + heading_offset + PI + rng.randf_range(-1.4, 1.4)
		unstick_until = sim_time + 1.4
		random_until = 0.0
		if not focus.is_empty():
			focus.fails = int(focus.fails) + 1
			if int(focus.fails) >= 2:
				_close_focus("stuck")


func _mark_stuck(here: Vector3, kind: String, pursuing: String) -> void:
	var cell := _cell_of(here)
	if not stuck_spots.has(cell):
		stuck_spots[cell] = {"cell": var_to_str(cell), "pos": [snappedf(here.x, 0.1), snappedf(here.y, 0.1), snappedf(here.z, 0.1)], "blocked": 0, "stale": 0, "first_at": snappedf(sim_time, 0.1), "pursuing": {}}
	var spot: Dictionary = stuck_spots[cell]
	spot[kind] = int(spot[kind]) + 1
	spot.pursuing[pursuing] = int(spot.pursuing.get(pursuing, 0)) + 1


# ============================================================================
# Report
# ============================================================================

func report() -> Dictionary:
	_close_focus("run_ended")
	var here: Variant = player_position() if scene != null and is_instance_valid(scene) else null
	var open_frontier := 0
	var given_up := 0
	for cell: Vector2i in cell_open:
		if not visited.has(cell) and cell_open[cell]:
			open_frontier += 1
			if int(cell_fail.get(cell, 0)) >= 3:
				given_up += 1
	var kinds := {}
	for record: Dictionary in things.values():
		var kind_name := str(record.kind) + (" (rides along with the player)" if record.rides_along else "")
		var entry: Dictionary = kinds.get(kind_name, {"kind": kind_name, "count": 0, "near_s": 0.0, "attend_s": 0.0, "visits": 0, "verbs": 0, "events": {}, "left": {}})
		entry.count += 1
		entry.near_s += float(record.near_s)
		entry.attend_s += float(record.attend_s)
		entry.visits += int(record.visits)
		entry.verbs += int(record.verbs)
		for type: String in record.events:
			entry.events[type] = int(entry.events.get(type, 0)) + int(record.events[type])
		for reason: String in record.left:
			entry.left[reason] = int(entry.left.get(reason, 0)) + int(record.left[reason])
		kinds[kind_name] = entry
	var kind_rows: Array = kinds.values()
	for row: Dictionary in kind_rows:
		row.near_s = snappedf(row.near_s, 0.1)
		row.attend_s = snappedf(row.attend_s, 0.1)
		row.boredom = snappedf(float(kind_boredom.get(row.kind, 0.0)), 0.01)
	kind_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.attend_s + a.near_s * 0.25 > b.attend_s + b.near_s * 0.25)
	var event_rows: Array = []
	for type: String in event_stats:
		var stats: Dictionary = event_stats[type]
		event_rows.append({"type": type, "count": stats.count, "hold_s": snappedf(stats.hold_s, 0.1), "mean_hold_s": snappedf(float(stats.hold_s) / maxf(1.0, float(stats.count)), 0.1), "first_at": stats.first_at, "after_verb": stats.after_verb, "near": stats.near})
	event_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.hold_s > b.hold_s or (a.hold_s == b.hold_s and a.count > b.count))
	var away := {}
	for episode: Dictionary in walked_away:
		var entry: Dictionary = away.get(episode.kind, {"kind": episode.kind, "times": 0, "seconds": 0.0, "reasons": {}, "with_events": 0})
		entry.times += 1
		entry.seconds += float(episode.seconds)
		entry.reasons[episode.reason] = int(entry.reasons.get(episode.reason, 0)) + 1
		if not (episode.events as Array).is_empty():
			entry.with_events += 1
		away[episode.kind] = entry
	var away_rows: Array = away.values()
	for row: Dictionary in away_rows:
		row.mean_s = snappedf(row.seconds / maxf(1.0, row.times), 0.1)
		row.seconds = snappedf(row.seconds, 0.1)
	away_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.times > b.times)
	var stuck_rows: Array = stuck_spots.values()
	stuck_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.blocked + a.stale > b.blocked + b.stale)
	var prompt_rows: Array = []
	for text: String in prompts_seen:
		prompt_rows.append({"text": text, "count": prompts_seen[text].count, "first_at": prompts_seen[text].first_at})
	prompt_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.first_at < b.first_at)
	var bounds := Rect2i()
	var first := true
	for cell: Vector2i in visited:
		if first:
			bounds = Rect2i(cell, Vector2i.ONE)
			first = false
		else:
			bounds = bounds.expand(cell).expand(cell + Vector2i.ONE)
	return {
		"mode": "random_walk" if random_walk else "curiosity",
		"scenes": scene_log,
		"sim_seconds": snappedf(sim_time, 0.1),
		"cell_size_m": cell_size,
		"cells_visited": visited.size(),
		"cells_open_unvisited": open_frontier,
		"cells_given_up": given_up,
		"coverage_pct": snappedf(100.0 * visited.size() / maxf(1.0, visited.size() + open_frontier), 0.1),
		"visited_bounds_m": [bounds.position.x * cell_size, bounds.position.y * cell_size, bounds.size.x * cell_size, bounds.size.y * cell_size],
		"distance_walked_m": snappedf(distance_walked, 0.1),
		"things_seen": things.size(),
		"thing_kinds": kind_rows,
		"events": event_rows,
		"walked_away": away_rows,
		"episodes": episodes,
		"stuck_spots": stuck_rows,
		"prompts": prompt_rows,
		"verb_presses": verb_presses,
		"heading_offset": snappedf(heading_offset, 0.01),
		"final_position": [snappedf(here.x, 0.1), snappedf(here.y, 0.1), snappedf(here.z, 0.1)] if here is Vector3 else [],
	}


static func markdown(data: Dictionary, title := "Curiosity run") -> String:
	var lines: PackedStringArray = []
	lines.append("# %s" % title)
	lines.append("")
	var scenes: PackedStringArray = []
	for entry: Dictionary in data.get("scenes", []):
		scenes.append("%s (from %ss)" % [entry.scene, entry.at])
	lines.append("- Scenes: %s" % ", ".join(scenes))
	lines.append("- Mode: %s; simulated %s s" % [data.mode, data.sim_seconds])
	lines.append("- Coverage: %d cells of %s m visited, %d cells with a floor seen next to them but never reached (%d given up on after 3 blocked tries), **%s%%**; walked %s m" % [data.cells_visited, data.cell_size_m, data.cells_open_unvisited, data.get("cells_given_up", 0), data.coverage_pct, data.distance_walked_m])
	lines.append("- Things noticed: %d; verb presses: %d; distinct event types: %d; distinct prompts read: %d" % [data.things_seen, data.verb_presses, (data.events as Array).size(), (data.prompts as Array).size()])
	lines.append("")
	lines.append("## What held its attention (by kind)")
	lines.append("")
	lines.append("| Kind | n | Attending s | Near s | Visits | Verbs | Events caused nearby | How it left | Boredom |")
	lines.append("|---|---:|---:|---:|---:|---:|---|---|---:|")
	for row: Dictionary in (data.thing_kinds as Array).slice(0, 25):
		lines.append("| %s | %d | %s | %s | %d | %d | %s | %s | %s |" % [str(row.kind).replace("|", "/"), row.count, row.attend_s, row.near_s, row.visits, row.verbs, _pairs(row.events), _pairs(row.left), row.boredom])
	lines.append("")
	lines.append("## Events it caused or met, ranked by how long they held it")
	lines.append("")
	lines.append("| Event type | Count | Held s (total) | Held s (mean) | First at s | Right after a verb |")
	lines.append("|---|---:|---:|---:|---:|---:|")
	for row: Dictionary in data.events:
		lines.append("| %s | %d | %s | %s | %s | %d |" % [row.type, row.count, row.hold_s, row.mean_hold_s, row.first_at, row.after_verb])
	if (data.events as Array).is_empty():
		lines.append("| (none) | | | | | |")
	lines.append("")
	lines.append("## What it walked away from")
	lines.append("")
	lines.append("| Kind | Times | Mean s before leaving | Why | Left after events |")
	lines.append("|---|---:|---:|---|---:|")
	for row: Dictionary in (data.walked_away as Array).slice(0, 25):
		lines.append("| %s | %d | %s | %s | %d |" % [str(row.kind).replace("|", "/"), row.times, row.mean_s, _pairs(row.reasons), row.with_events])
	if (data.walked_away as Array).is_empty():
		lines.append("| (nothing reached) | | | | |")
	lines.append("")
	lines.append("## Stuck spots")
	lines.append("")
	lines.append("| Cell | Position | Blocked | Stale | First at s | Chasing |")
	lines.append("|---|---|---:|---:|---:|---|")
	for row: Dictionary in (data.stuck_spots as Array).slice(0, 20):
		lines.append("| %s | %s | %d | %d | %s | %s |" % [row.cell, str(row.pos), row.blocked, row.stale, row.first_at, _pairs(row.pursuing).left(90)])
	if (data.stuck_spots as Array).is_empty():
		lines.append("| (none) | | | | | |")
	lines.append("")
	lines.append("## Prompts it read, in order")
	lines.append("")
	for row: Dictionary in (data.prompts as Array).slice(0, 30):
		lines.append("- %ss: `%s` (x%d)" % [row.first_at, str(row.text).left(110), row.count])
	lines.append("")
	return "\n".join(lines)


static func _pairs(values: Dictionary) -> String:
	var parts: PackedStringArray = []
	var keys := values.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(values[a]) > int(values[b]))
	for key: Variant in keys.slice(0, 5):
		parts.append("%s x%d" % [str(key).replace("|", "/"), int(values[key])])
	return ", ".join(parts) if not parts.is_empty() else "-"
