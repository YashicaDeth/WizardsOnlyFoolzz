class_name ExitReveal
extends CanvasLayer

## The arrival reveal (DESIGN/OVERWORLD_EVENTS.md, decided): "Every exit gets
## its own arrival reveal. The camera rises from the exact spot the player
## came out of and sweeps over the real overworld, marking the nearby
## settlements on the map as it passes them."
##
## The Hunt hands this the facility handoff it consumed in `_ready` and its
## own camera. When there was a handoff, the world is held (the tree is paused,
## as photo mode does) while a camera of this node's own rises from the
## handoff's `surface_position`, sweeps over the settlements nearest to it and
## pulls up over all of them, then hands the Hunt's camera back. Each
## settlement is marked with the map's own discovery call,
## `AshbloomHoldings.observe()`, the moment the camera passes it, so the MAP
## shows exactly what the reveal showed. Nothing here is per exit: a new exit
## gets its reveal from its `surface_position` alone.
##
## Any key or click after the first half second skips; skipping still marks
## what the reveal would have marked, because the player came out there
## either way. `WorldHistory` gets one `exit_reveal_seen` event naming the
## exit and the settlements marked.

signal finished(skipped: bool)

const HOLDINGS := preload("res://systems/ashbloom_holdings.gd")
const CellOutzType := preload("res://systems/celloutz_type.gd")

## Settlements further than this from the exit are not "nearby".
const REACH := 200.0
const MAX_MARKED := 2
const EYE := 1.7
const SHOULDER_BACK := 4.0
const SHOULDER_UP := 1.4
const SHOULDER_SIDE := 1.0
## Seconds: rising off the exit, each settlement pass, the pull-up, the hand-back.
## A beat on the spot first, at eye height, so the rise reads as leaving it.
const HOLD := 0.9
const RISE := 3.2
const PASS := 2.6
const PULL_UP := 2.2
const HAND_BACK := 0.8
const RISE_HEIGHT := 34.0
const PASS_HEIGHT := 58.0
const PASS_STANDOFF := 60.0
const OVERVIEW_HEIGHT := 140.0
## The Hunt's haze is set for walking; from the air it hides everything.
const AERIAL_FOG := 0.3
## Before this, a key press is the one that brought the player here.
const ARM_AFTER := 0.5
const AMBER := Color(1.0, 0.62, 0.22)
const BLOOD := Color(0.86, 0.12, 0.10)
const INK := Color(0.93, 0.89, 0.8)

var active := false
var clock := 0.0
var duration := 0.0
var skipped := false
var handoff: Dictionary = {}
var exit_at := Vector3.ZERO
var exit_name := ""
var route_label := ""
## [{id, name, at: Vector3, distance, key_time, marked}] nearest first.
var settlements: Array[Dictionary] = []
var marked_ids: Array[String] = []
var cam: Camera3D
## [time, position, look_at] keyframes, in order.
var keys: Array = []

var _previous: Camera3D
var _was_paused := false
var _hidden: Array[CanvasLayer] = []
var _overlay: Control
var _started := false
var _eye := Vector3.ZERO
## False until `_settle` has asked the world where the walls are.
var _planned := false


## The Hunt's one call. Returns null when there was no handoff (a resumed
## save, a debug start), so there is nothing to play and nothing to hold.
static func attach(host: Node, consumed_handoff: Dictionary, from: Camera3D) -> ExitReveal:
	if consumed_handoff.is_empty() or (consumed_handoff.get("surface_position", []) as Array).size() != 3:
		return null
	var reveal := ExitReveal.new()
	reveal.name = "ExitReveal"
	host.add_child(reveal)
	reveal.play(consumed_handoff, from)
	return reveal


func _init() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_overlay = Control.new()
	_overlay.name = "RevealOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	visible = active


## Plans the flight from the handoff and takes the screen. Safe to call from
## the host's `_ready`: nothing the host builds after this is disturbed. The
## world gets one physics tick to settle (see `_settle`) and is then held
## until the reveal hands back.
func play(consumed_handoff: Dictionary, from: Camera3D) -> void:
	if active:
		return
	handoff = consumed_handoff.duplicate(true)
	var at: Array = handoff.get("surface_position", [0, 0, 0])
	exit_at = Vector3(float(at[0]), float(at[1]), float(at[2]))
	var exit_id := str(handoff.get("exit_id", ""))
	exit_name = str((FacilityRoutes.DISTRICTS.get(exit_id, {}) as Dictionary).get("name", exit_id.replace("_", " "))).to_upper()
	route_label = str(FacilityRoutes.route(str(handoff.get("route_id", ""))).get("label", "")).to_upper()
	settlements = nearby_settlements(exit_at)
	# The host's camera is already standing where the player came out (on the
	# ground there, which is not always at the authored height); start from
	# it when it is, so the first frame of the reveal is the player's own eye.
	var eye := exit_at + Vector3(0, EYE, 0)
	if from != null and from.is_inside_tree():
		var standing := from.global_position
		if Vector2(standing.x - exit_at.x, standing.z - exit_at.z).length() < 6.0 and absf(standing.y - exit_at.y) < 8.0:
			eye = standing
	_eye = eye
	_plan(eye, false)
	_planned = false
	active = true
	clock = 0.0
	skipped = false
	_previous = from
	cam = Camera3D.new()
	cam.name = "ExitRevealCamera"
	cam.far = 1200.0
	cam.fov = 62.0
	add_child(cam)
	cam.environment = _aerial_environment(from)
	var first: Array = keys[0]
	cam.global_position = first[1]
	_look(first[2])
	cam.make_current()
	_was_paused = get_tree().paused if is_inside_tree() else false
	_settle()
	# The host's HUD is not part of the shot.
	var host := get_parent()
	if host != null:
		for node in host.find_children("*", "CanvasLayer", true, false):
			var canvas := node as CanvasLayer
			if canvas != self and canvas.visible:
				canvas.visible = false
				_hidden.append(canvas)
	visible = true


## One physics frame after the host built its world, the world can be asked
## where the walls are: the over-the-shoulder start is pulled in front of any
## that stand between it and the eye. Then the world is held.
func _settle() -> void:
	if is_inside_tree():
		await get_tree().physics_frame
	if not active:
		return
	_plan(_eye, true)
	var first: Array = keys[0]
	cam.global_position = first[1]
	_look(first[2])
	_planned = true
	get_tree().paused = true


## The world's own look, with the haze thinned for the height.
func _aerial_environment(from: Camera3D) -> Environment:
	var source: Environment = from.environment if from != null and from.environment != null else null
	if source == null and is_inside_tree():
		source = get_viewport().world_3d.environment if get_viewport().world_3d != null else null
		if source == null:
			for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
				source = (node as WorldEnvironment).environment
				break
	if source == null:
		return null
	var aerial := source.duplicate() as Environment
	aerial.fog_density *= AERIAL_FOG
	aerial.volumetric_fog_density *= AERIAL_FOG
	return aerial


## The settlements the reveal passes: the nearest within `REACH`, at most
## `MAX_MARKED`, always at least the nearest one so every exit shows somewhere.
static func nearby_settlements(from: Vector3) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for definition: Dictionary in HOLDINGS.DEFINITIONS:
		var at2: Vector2 = definition.at
		var at := Vector3(at2.x, 0.0, at2.y)
		rows.append({
			"id": str(definition.id),
			"name": str(definition.name),
			"at": at,
			"distance": Vector2(from.x, from.z).distance_to(at2),
			"marked": false,
			"key_time": 0.0,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	var result: Array[Dictionary] = []
	for row in rows:
		if result.size() >= MAX_MARKED:
			break
		if result.is_empty() or float(row.distance) <= REACH:
			result.append(row)
	return result


func _plan(eye: Vector3, ask_the_world: bool) -> void:
	keys.clear()
	var ground := Vector3(exit_at.x, eye.y - EYE, exit_at.z)
	var first_at: Vector3 = settlements[0].at if not settlements.is_empty() else ground + Vector3(0, 0, -100)
	var heading := Vector3(first_at.x - ground.x, 0.0, first_at.z - ground.z).normalized()
	if heading.is_zero_approx():
		heading = Vector3.FORWARD
	# Eye height on the exact spot, looking the way the sweep will go.
	# Just over the player's shoulder: at the eye itself the camera sits
	# inside the player's own head.
	var shoulder := eye - heading * SHOULDER_BACK + heading.cross(Vector3.UP) * SHOULDER_SIDE + Vector3(0, SHOULDER_UP, 0)
	if ask_the_world and is_inside_tree() and get_viewport().world_3d != null:
		var ray := PhysicsRayQueryParameters3D.create(eye, shoulder)
		var hit := get_viewport().world_3d.direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			var wall: Vector3 = hit.position
			shoulder = wall + (eye - wall).normalized() * 0.35
	keys.append([0.0, shoulder, eye + heading * 30.0 - Vector3(0, EYE * 0.6, 0)])
	keys.append([HOLD, shoulder + Vector3(0, 0.5, 0), eye + heading * 30.0 - Vector3(0, EYE, 0)])
	# Up and back off it, looking down at where you came out.
	keys.append([RISE, ground - heading * 16.0 + Vector3(0, RISE_HEIGHT, 0), ground])
	var t := RISE
	var previous := ground
	for row in settlements:
		t += PASS
		var at: Vector3 = row.at
		var approach := Vector3(at.x - previous.x, 0.0, at.z - previous.z).normalized()
		if approach.is_zero_approx():
			approach = heading
		keys.append([t, at - approach * PASS_STANDOFF + Vector3(0, PASS_HEIGHT, 0), at])
		row.key_time = t
		previous = at
	# Pull up over the exit and everything it showed.
	var centre := ground
	for row in settlements:
		centre += row.at
	centre /= float(settlements.size() + 1)
	t += PULL_UP
	keys.append([t, centre + Vector3(0, OVERVIEW_HEIGHT, 60.0), centre])
	duration = t + HAND_BACK


func _look(target: Vector3) -> void:
	if cam == null:
		return
	var eye := cam.global_position
	if eye.distance_to(target) < 0.01:
		return
	var up := Vector3.UP
	if absf((target - eye).normalized().dot(up)) > 0.98:
		up = Vector3.FORWARD
	cam.look_at(target, up)


## Position and look target along the planned flight at time `t`.
func sample(t: float) -> Array:
	var last := keys.size() - 1
	if t <= float(keys[0][0]):
		return [keys[0][1], keys[0][2]]
	for index in last:
		var a: Array = keys[index]
		var b: Array = keys[index + 1]
		if t <= float(b[0]):
			var weight := inverse_lerp(float(a[0]), float(b[0]), t)
			weight = weight * weight * (3.0 - 2.0 * weight) * 0.5 + weight * 0.5
			var pre: Array = keys[maxi(index - 1, 0)]
			var post: Array = keys[mini(index + 2, last)]
			var position: Vector3 = (a[1] as Vector3).cubic_interpolate(b[1], pre[1], post[1], weight)
			var target: Vector3 = (a[2] as Vector3).cubic_interpolate(b[2], pre[2], post[2], weight)
			return [position, target]
	return [keys[last][1], keys[last][2]]


func _process(delta: float) -> void:
	if not active:
		return
	# Held on the exit while the transit plate is still up, so the player
	# sees the rise, not the end of it.
	if Interstitial.travelling and clock <= 0.0:
		return
	advance(delta)


## One step of the flight. Public so tests and captures can drive it.
func advance(delta: float) -> void:
	if not active or not _planned:
		return
	_started = true
	clock += delta
	var at := sample(clock)
	cam.global_position = at[0]
	_look(at[1])
	for row in settlements:
		# Marked as the camera arrives over it, not after it has gone.
		if not bool(row.marked) and clock >= float(row.key_time) - PASS * 0.35:
			_mark(row)
	_overlay.queue_redraw()
	if clock >= duration:
		finish(false)


func _mark(row: Dictionary) -> void:
	row.marked = true
	var at: Vector3 = row.at
	HOLDINGS.observe(Vector2(at.x, at.z))
	if not marked_ids.has(str(row.id)):
		marked_ids.append(str(row.id))


func _input(event: InputEvent) -> void:
	if not active or clock < ARM_AFTER:
		return
	var key := event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if key or click:
		get_viewport().set_input_as_handled()
		finish(true)


## Ends the reveal (completed or skipped), marks anything not yet marked,
## records it and gives the host its camera and its world back.
func finish(was_skipped: bool) -> void:
	if not active:
		return
	active = false
	skipped = was_skipped
	for row in settlements:
		if not bool(row.marked):
			_mark(row)
	WorldHistory.record_event("exit_reveal_seen", {
		"route_id": str(handoff.get("route_id", "")),
		"exit_id": str(handoff.get("exit_id", "")),
		"surface_position": handoff.get("surface_position", []),
		"settlements_marked": marked_ids.duplicate(),
		"skipped": was_skipped,
		"seconds": snappedf(clock, 0.1),
	})
	_hand_back()
	finished.emit(was_skipped)


func _hand_back() -> void:
	if is_instance_valid(_previous) and _previous.is_inside_tree():
		_previous.make_current()
	if is_instance_valid(cam):
		cam.queue_free()
	cam = null
	for canvas in _hidden:
		if is_instance_valid(canvas):
			canvas.visible = true
	_hidden.clear()
	if is_inside_tree():
		get_tree().paused = _was_paused
	visible = false


func _exit_tree() -> void:
	# Freed mid-flight (the host left): never leave the tree paused.
	if active:
		active = false
		if get_tree() != null:
			get_tree().paused = _was_paused


# --- the overlay ---------------------------------------------------------------

func _draw_overlay() -> void:
	if not active or cam == null:
		return
	var size := _overlay.size
	var fade_in := clampf(clock / 0.6, 0.0, 1.0)
	var fade_out := clampf((duration - clock) / HAND_BACK, 0.0, 1.0)
	var alpha := fade_in * fade_out
	# Letterbox.
	var bar := size.y * 0.085
	_overlay.draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, 0.92 * fade_out))
	_overlay.draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, 0.92 * fade_out))
	# Where you came out.
	_draw_marker(exit_at + Vector3(0, 0.5, 0), "YOU CAME OUT HERE", INK, 1.0, alpha)
	for row in settlements:
		var marked := bool(row.marked)
		var label := str(row.name) + ("   // MARKED" if marked else "")
		_draw_marker((row.at as Vector3) + Vector3(0, 6, 0), label, AMBER if marked else INK, 1.0 if marked else 0.55, alpha, "%d M" % roundi(float(row.distance)))
	# Title.
	var title := exit_name if not exit_name.is_empty() else "THE SURFACE"
	CellOutzType.draw_text(_overlay, Vector2(48, bar + 34), title, 30.0, Color(AMBER, alpha), 2.0)
	var sub := ("%s   //   THE ASHBLOOM EXPANSE" % route_label) if not route_label.is_empty() else "THE ASHBLOOM EXPANSE"
	CellOutzType.draw_condensed(_overlay, Vector2(50, bar + 80), sub, 13.0, Color(INK, alpha * 0.85), 1.0)
	_draw_chart(Rect2(size.x - 262, size.y - bar - 222, 214, 190), alpha)
	if clock >= ARM_AFTER:
		CellOutzType.draw_condensed(_overlay, Vector2(48, size.y - bar * 0.5 - 6), "ANY KEY SKIPS", 11.0, Color(INK, 0.55 * alpha), 1.0)


func _draw_marker(world: Vector3, label: String, colour: Color, strength: float, alpha: float, note := "") -> void:
	if cam.is_position_behind(world):
		return
	var point := cam.unproject_position(world)
	var size := _overlay.size
	if point.x < -40 or point.y < -40 or point.x > size.x + 40 or point.y > size.y + 40:
		return
	var tint := Color(colour, alpha * strength)
	var pulse := 0.5 + 0.5 * sin(clock * 6.0)
	_overlay.draw_arc(point, 9.0 + pulse * 3.0 * strength, 0.0, TAU, 24, tint, 2.0)
	_overlay.draw_circle(point, 3.0, tint)
	var bar := size.y * 0.085
	var label_width := CellOutzType.width_condensed(label, 13.0, 1.0)
	var anchor := point + Vector2(16, -30)
	anchor.x = clampf(anchor.x, 24.0, size.x - label_width - 24.0)
	anchor.y = clampf(anchor.y, bar + 12.0, size.y - bar - 40.0)
	_overlay.draw_line(point + Vector2(6, -6), anchor + Vector2(0, 8), tint, 1.4)
	CellOutzType.draw_condensed(_overlay, anchor, label, 13.0, tint, 1.0)
	if not note.is_empty():
		CellOutzType.draw_condensed(_overlay, anchor + Vector2(0, 20), note, 10.0, Color(tint, tint.a * 0.7), 1.0)


## The map card: the region, the five settlements, the exit, the camera, and
## which ones this reveal has marked.
func _draw_chart(rect: Rect2, alpha: float) -> void:
	_overlay.draw_rect(rect, Color(0.04, 0.03, 0.03, 0.78 * alpha))
	_overlay.draw_rect(rect, Color(AMBER, 0.5 * alpha), false, 1.0)
	CellOutzType.draw_condensed(_overlay, rect.position + Vector2(10, 10), "MAP // MARKED FROM ABOVE", 10.0, Color(INK, 0.8 * alpha), 1.0)
	var bounds := HOLDINGS.REGION_BOUNDS
	var inner := rect.grow(-14)
	inner.position.y += 16
	inner.size.y -= 16
	var to_chart := func(world: Vector3) -> Vector2:
		var u := (world.x - bounds.position.x) / bounds.size.x
		var v := (world.z - bounds.position.y) / bounds.size.y
		return inner.position + Vector2(u, v) * inner.size
	for definition: Dictionary in HOLDINGS.DEFINITIONS:
		var at2: Vector2 = definition.at
		var point: Vector2 = to_chart.call(Vector3(at2.x, 0, at2.y))
		var marked := marked_ids.has(str(definition.id))
		var known := marked or bool(HOLDINGS.holding(str(definition.id)).get("revealed", false))
		if marked:
			_overlay.draw_circle(point, 5.0, Color(AMBER, alpha))
			CellOutzType.draw_condensed(_overlay, point + Vector2(-30, 8), str(definition.name), 7.0, Color(AMBER, alpha), 0.5)
		else:
			_overlay.draw_arc(point, 4.0, 0.0, TAU, 12, Color(INK, (0.55 if known else 0.25) * alpha), 1.0)
	var exit_point: Vector2 = to_chart.call(exit_at)
	_overlay.draw_line(exit_point + Vector2(-4, -4), exit_point + Vector2(4, 4), Color(BLOOD, alpha), 2.0)
	_overlay.draw_line(exit_point + Vector2(-4, 4), exit_point + Vector2(4, -4), Color(BLOOD, alpha), 2.0)
	if cam != null:
		var eye: Vector2 = to_chart.call(cam.global_position)
		_overlay.draw_circle(eye, 2.5, Color(INK, alpha))
		var forward := -cam.global_transform.basis.z
		_overlay.draw_line(eye, eye + Vector2(forward.x, forward.z).normalized() * 10.0, Color(INK, alpha), 1.0)
