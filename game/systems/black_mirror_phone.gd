class_name BlackMirrorPhone
extends Control

## v02-51. The Black Mirror as ONE device (Greg, 5 Oct: it "still does not
## cohesively work"; 6 Oct: "we gotta make the black mirror like work").
##
## Before this, the phone was two unrelated things bound to two keys: the
## handheld's seven app pages (Tab) and the rear camera (L), each with its own
## look and its own controls, and neither in the v0.1 route at all. This node
## adds no app. It holds the two existing systems and gives them one hand:
##
##   one button     the `device` action (pad CREATE, key G) raises and lowers
##   one page rail  CAMERA / MAP / CARRY, stepped with d-pad left and right
##   one verb pair  d-pad up/down does the page's own thing: the camera's
##                  night/depth sensor, the bag's selection; Cross on CARRY
##                  opens the player's Brain Index through the head
##
## CAMERA is BlackMirrorCamera (night sensor and the TouchDesigner depth image
## with BlockTracker boxes). MAP and CARRY are HandheldDevice pages; MAP in the
## facility is LivingMap drawing facility.gd's own plan. The handheld's INDEX,
## WIRE, RADIO, RITUAL and FIELD pages are hidden here: they read the surface
## Wire, radio masts, rites and resonance, none of which exist underground, so
## in the facility each was a half-working page (DESIGN/REMASTER_LOG.md).
##
## Possession is the handheld's own record (`WorldHistory` subject
## "handheld", `possessed`). `take()` is the one way the route grants it.

signal raised_changed(raised: bool, page: String)

const HANDHELD := preload("res://systems/handheld_device.gd")
const CAMERA := preload("res://systems/black_mirror_camera.gd")
const RESTRICTED_STORAGE := preload("res://systems/restricted_storage.gd")
const CellOutzType := preload("res://systems/celloutz_type.gd")

const PAGES := ["CAMERA", "MAP", "CARRY"]
## What the handheld keeps in the facility; the rest are listed above.
const HANDHELD_PAGES := ["MAP", "CARRY"]
const HIDDEN_PAGES := ["INDEX", "WIRE", "RADIO", "RITUAL", "FIELD"]
const INK := Color("e6d4ac")
const AMBER := Color("b0552a")
const CASE_EDGE := Color("6d5a44")
## Dial: how much the night lens lifts the facility's own grade before the
## sensor's gain. The Hunt uses 1.05 (noon) to 3.4 (night); underground is
## always night, so one value.
const NIGHT_GRADE := 3.0

var raised := false
var page := "CAMERA"
var handheld: Control
var lens: Control
var rail: Control
var host_camera: Camera3D
var world_environment: Environment
## Returns [Vector3 feet, float yaw] for the carrier, each frame.
var pose_provider: Callable
var _graded: Environment
## The rail is stroke-drawn type too; it is re-recorded only when what it says
## changes (page, device), not every frame.
var _rail_said := ""
## The handheld is thousands of stroke-drawn primitives (chassis, glass, type).
## Drawn straight onto the HUD it cost ~60 fps on Greg's RTX 2060 SUPER (v02-51
## probe). It renders into its own viewport instead, every frame while it moves
## and PAGE_HZ while it is steady, and the HUD draws one texture.
const PAGE_HZ := 15.0
var _page_view: SubViewport
var _page_sprite: TextureRect
var _page_due := 0.0
## The same for the stroke-type readouts (the lens strip and the page rail):
## they change at 10 Hz, so they render into one cached layer at 10 Hz.
const READOUT_HZ := 10.0
var _readout_view: SubViewport
var _readout_sprite: TextureRect
var _readout_due := 0.0


## Picks the phone up for good: the handheld record says possessed, and the
## route remembers where it came from. Idempotent.
static func take(location: String) -> bool:
	if is_held():
		return false
	WorldHistory.begin_ledger_batch()
	RESTRICTED_STORAGE.ensure()
	WorldHistory.update_subject(HANDHELD.DEVICE_ID, {"possessed": true}, "device_changed")
	WorldHistory.record_event("black_mirror_taken", {"location": location})
	WorldHistory.commit_ledger_batch()
	return true


static func is_held() -> bool:
	return bool(WorldHistory.subject(HANDHELD.DEVICE_ID).get("possessed", false))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lens = CAMERA.new()
	lens.name = "BlackMirrorSensor"
	add_child(lens)
	_page_view = SubViewport.new()
	_page_view.name = "HandheldView"
	_page_view.transparent_bg = true
	_page_view.disable_3d = true
	_page_view.gui_disable_input = true
	_page_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_page_view)
	handheld = HANDHELD.new()
	handheld.name = "Handheld"
	_page_view.add_child(handheld)
	_page_sprite = TextureRect.new()
	_page_sprite.name = "HandheldPicture"
	_page_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_sprite.texture = _page_view.get_texture()
	_page_sprite.visible = false
	add_child(_page_sprite)
	handheld.set_available_modes(HANDHELD_PAGES)
	handheld.show_tab_rail = false
	handheld.steady_redraw_hz = 12.0
	# Nothing in the facility can hold a dropped phone (the Hunt spawns one);
	# the handheld's DELETE drop would lose it for good, so it is off here.
	handheld.drop_key_override = false
	_readout_view = SubViewport.new()
	_readout_view.name = "ReadoutView"
	_readout_view.transparent_bg = true
	_readout_view.disable_3d = true
	_readout_view.gui_disable_input = true
	_readout_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_readout_view)
	# The lens strip is drawn by BlackMirrorCamera; it only moves house.
	var strip: Control = lens.get("overlay")
	strip.reparent(_readout_view, false)
	rail = Control.new()
	rail.name = "PageRail"
	rail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.draw.connect(_draw_rail)
	_readout_view.add_child(rail)
	rail.visible = false
	_readout_sprite = TextureRect.new()
	_readout_sprite.name = "ReadoutPicture"
	_readout_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_readout_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout_sprite.texture = _readout_view.get_texture()
	_readout_sprite.visible = false
	add_child(_readout_sprite)


## camera / environment: the carrier's view and the room's own grade.
## plan_source: facility.gd (or anything with `plan_rooms()`), for MAP.
## targets: the depth camera's bodies and objects (see BlackMirrorCamera).
func setup(camera: Camera3D, environment: Environment, plan_source: Node, targets: Callable, pose: Callable) -> void:
	host_camera = camera
	world_environment = environment
	pose_provider = pose
	lens.set("target_provider", targets)
	var map: Control = handheld.get("_map")
	if map != null and plan_source != null:
		map.call("set_plan_source", plan_source)
		# No satellite underground: the plan is the map.
		map.call("set_satellite_available", false, "underground")


## The night lens shows signals the way the Hunt's does (SignalSight). The
## depth image is its own picture; SignalSight's screen pass smeared it.
func signal_lens() -> bool:
	return raised and page == "CAMERA" and str(lens.get("mode")) == "night"


func held() -> bool:
	return is_held()


func toggle() -> bool:
	if raised:
		lower()
		return true
	return raise_phone()


func raise_phone() -> bool:
	if not held():
		return false
	raised = true
	rail.visible = true
	_rail_said = ""
	_show_page()
	raised_changed.emit(true, page)
	return true


func lower() -> void:
	if not raised:
		return
	raised = false
	rail.visible = false
	lens.call("set_active", false)
	if handheld.is_open:
		handheld.close_device()
	raised_changed.emit(false, page)


func step_page(direction: int) -> void:
	if not raised:
		return
	page = PAGES[wrapi(PAGES.find(page) + direction, 0, PAGES.size())]
	_show_page()
	raised_changed.emit(true, page)


func set_page(next: String) -> void:
	if PAGES.has(next):
		page = next
		if raised:
			_show_page()


## D-pad up/down: the page's own verb.
func page_verb(direction: int) -> void:
	if not raised:
		return
	match page:
		"CAMERA":
			lens.call("set_mode", "depth" if str(lens.get("mode")) == "night" else "night")
			raised_changed.emit(true, page)
		"CARRY":
			handheld.step_carry(direction)


## Cross: the CARRY page's head opens the Brain Index.
func page_accept() -> bool:
	if raised and page == "CARRY":
		return handheld.toggle_brain_index()
	return false


func _show_page() -> void:
	if page == "CAMERA":
		if handheld.is_open:
			handheld.close_device()
		_bind_lens()
		lens.call("set_active", true)
		if not bool(lens.get("active")) and host_camera != null:
			# A dead cell still lets you look through the glass, unamplified.
			host_camera.environment = _graded
		return
	lens.call("set_active", false)
	if not handheld.is_open:
		handheld.open_device()
	handheld.set_mode(page)


func _bind_lens() -> void:
	if world_environment == null:
		lens.call("bind", host_camera, null)
		return
	_graded = world_environment.duplicate(true)
	_graded.adjustment_enabled = true
	_graded.adjustment_brightness = NIGHT_GRADE
	lens.call("bind", host_camera, _graded)


## True when the event was the phone's. The raise button is always the
## phone's while it is held; the page controls only while it is up.
func handle_input(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed("device"):
		return toggle() or held()
	if not raised:
		return false
	if event is InputEventJoypadButton and event.is_pressed():
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_LEFT:
				step_page(-1)
				return true
			JOY_BUTTON_DPAD_RIGHT:
				step_page(1)
				return true
			JOY_BUTTON_DPAD_UP:
				page_verb(-1)
				return true
			JOY_BUTTON_DPAD_DOWN:
				page_verb(1)
				return true
			JOY_BUTTON_A:
				return page_accept()
	if event is InputEventKey and event.is_pressed():
		match (event as InputEventKey).keycode:
			KEY_LEFT:
				step_page(-1)
				return true
			KEY_RIGHT:
				step_page(1)
				return true
			KEY_UP:
				page_verb(-1)
				return true
			KEY_DOWN:
				page_verb(1)
				return true
			KEY_ENTER, KEY_KP_ENTER:
				return page_accept()
	return false


func _process(delta: float) -> void:
	_drive_page_view(delta)
	_drive_readout_view(delta)
	if not raised:
		return
	if not held():
		lower()
		return
	if pose_provider.is_valid():
		var pose: Array = pose_provider.call()
		var map: Control = handheld.get("_map")
		if map != null and pose.size() >= 2:
			map.call("observe_interior", pose[0], float(pose[1]))
	var pad := _on_pad()
	var glyphs := _glyphs(pad)
	lens.set("hint_line", "%s / %s NIGHT - DEPTH" % [glyphs.up, glyphs.down])
	handheld.control_hints = {
		"next_page": "%s / %s PAGE" % [glyphs.left, glyphs.right],
		"carry": "%s / %s SELECT     %s BRAIN INDEX" % [glyphs.up, glyphs.down, glyphs.accept],
		"brain_close": "%s CLOSE" % glyphs.accept,
		"action_MAP": "FACILITY PLAN",
		"action_CARRY": "%s BRAIN INDEX" % glyphs.accept,
	}
	var said := "%s|%s" % [page, pad]
	if said != _rail_said:
		_rail_said = said
		rail.queue_redraw()
		_readout_due = 0.0


func _drive_page_view(delta: float) -> void:
	var showing: bool = handheld.visible
	_page_sprite.visible = showing
	if not showing:
		_page_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var want := Vector2i(get_viewport_rect().size)
	if _page_view.size != want:
		_page_view.size = want
		_page_due = 0.0
	var moving: bool = float(handheld.raised) < 0.999 or int(handheld.pending_mode_index) >= 0
	_page_due -= delta
	if moving or _page_due <= 0.0:
		_page_due = 1.0 / PAGE_HZ
		_page_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _drive_readout_view(delta: float) -> void:
	var strip: Control = lens.get("overlay")
	strip.visible = lens.visible
	var showing := rail.visible or strip.visible
	_readout_sprite.visible = showing
	if not showing:
		_readout_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var want := Vector2i(get_viewport_rect().size)
	if _readout_view.size != want:
		_readout_view.size = want
		strip.size = Vector2(want)
		_readout_due = 0.0
	_readout_due -= delta
	if _readout_due <= 0.0:
		_readout_due = 1.0 / READOUT_HZ
		_readout_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _on_pad() -> bool:
	var profile := get_node_or_null("/root/InputProfile")
	return profile != null and bool(profile.get("using_pad"))


func _glyphs(pad: bool) -> Dictionary:
	var profile := get_node_or_null("/root/InputProfile")
	var device := str(profile.call("glyph", "device")) if profile != null else "G"
	if pad:
		return {"left": "D-LEFT", "right": "D-RIGHT", "up": "D-UP", "down": "D-DOWN", "accept": "CROSS", "device": device}
	return {"left": "LEFT", "right": "RIGHT", "up": "UP", "down": "DOWN", "accept": "ENTER", "device": device}


## The one rail every page shares, under the lens and under the handheld:
## where you are on the device, how to move, how to put it away.
func _draw_rail() -> void:
	var glyphs := _glyphs(_on_pad())
	var cap := 10.0
	var words: Array[String] = []
	var total := 0.0
	var gap := 26.0
	for name: String in PAGES:
		words.append(name)
		total += CellOutzType.width(name, cap, 1.0) + gap
	var left_hint := glyphs.left as String
	var right_hint := glyphs.right as String
	var lower_hint := "%s LOWER" % glyphs.device
	var hint_cap := 8.0
	var lw := CellOutzType.width_condensed(left_hint, hint_cap, 0.66)
	var rw := CellOutzType.width_condensed(right_hint, hint_cap, 0.66)
	var dw := CellOutzType.width_condensed(lower_hint, hint_cap, 0.66)
	var width := lw + 22.0 + total + rw + 40.0 + dw + 24.0
	var origin := Vector2(size.x * 0.5 - width * 0.5, size.y - 40.0)
	rail.draw_rect(Rect2(origin - Vector2(12, 8), Vector2(width + 24, 30)), Color(0.012, 0.016, 0.014, 0.88))
	rail.draw_rect(Rect2(origin - Vector2(12, 8), Vector2(width + 24, 30)), CASE_EDGE * Color(1, 1, 1, 0.6), false, 1.0)
	var x := origin.x
	CellOutzType.draw_condensed(rail, Vector2(x, origin.y + 2), left_hint, hint_cap, CASE_EDGE, 0.66)
	x += lw + 22.0
	for name: String in words:
		var active := name == page
		var w := CellOutzType.width(name, cap, 1.0)
		if active:
			rail.draw_rect(Rect2(Vector2(x - 6, origin.y - 4), Vector2(w + 12, cap + 9)), AMBER * Color(1, 1, 1, 0.24))
			rail.draw_line(Vector2(x - 6, origin.y + cap + 6), Vector2(x + w + 6, origin.y + cap + 6), AMBER, 1.4)
		CellOutzType.draw_text(rail, Vector2(x, origin.y), name, cap, INK if active else CASE_EDGE, 1.0)
		x += w + gap
	CellOutzType.draw_condensed(rail, Vector2(x, origin.y + 2), right_hint, hint_cap, CASE_EDGE, 0.66)
	x += rw + 40.0
	CellOutzType.draw_condensed(rail, Vector2(x, origin.y + 2), lower_hint, hint_cap, AMBER, 0.66)


## The depth camera's targets in the v0.1 facility: everyone who has a body
## (guards, the freed subject, the sentinel, the examiner, the subjects still
## in their tanks) and the objects the route turns on (the vats, his door, the
## cleaver, the keycard, story props). Read from the chamber's own fields; the
## phone never searches the scene tree.
static func facility_targets(chamber: Node) -> Array:
	var out: Array = []
	var encounters = chamber.get("encounters")
	if encounters != null and is_instance_valid(encounters):
		for foe in encounters.get("foes"):
			if foe == null or not is_instance_valid(foe) or str(foe.get("state")) == "dead":
				continue
			var tag := str(foe.get("kind")).to_upper().replace("_", " ")
			var big := tag.contains("SENTINEL")
			out.append({"at": (foe as Node3D).global_position + Vector3(0, 1.1 if big else 0.9, 0), "half": Vector3(0.8, 1.2, 0.8) if big else Vector3(0.35, 0.92, 0.35), "tag": tag if tag != "" else "BODY", "kind": "body"})
	var route = chamber.get("doctor_route")
	if route != null and is_instance_valid(route):
		var fight = route.get("fight")
		if fight != null and is_instance_valid(fight):
			var him = fight.get("body")
			if him != null and is_instance_valid(him) and (him as Node3D).is_visible_in_tree():
				out.append({"at": (him as Node3D).global_position + Vector3(0, 0.95, 0), "half": Vector3(0.38, 0.95, 0.38), "tag": "EXAMINER" if str(fight.get("state")) != "dead" else "EXAMINER / DEAD", "kind": "body"})
		var door = route.get("door")
		if door != null and is_instance_valid(door) and not bool(door.get("broken")):
			out.append({"at": DoctorRoute.DOOR_AT + Vector3(0, 1.15, 0), "half": Vector3(0.6, 1.15, 0.1), "tag": "DOOR", "kind": "object"})
		var axe = route.get("axe_model")
		if axe != null and is_instance_valid(axe) and (axe as Node3D).is_visible_in_tree():
			out.append({"at": (axe as Node3D).global_position, "half": Vector3(0.2, 0.4, 0.2), "tag": "CLEAVER", "kind": "object"})
	for subject: Dictionary in chamber.get("horror_subjects"):
		var rig = subject.get("rig")
		if rig != null and is_instance_valid(rig):
			out.append({"at": (rig as Node3D).global_position + Vector3(0, 0.9, 0), "half": Vector3(0.35, 0.9, 0.35), "tag": "SUBJECT", "kind": "body"})
	var tree := chamber.get_tree() if chamber.is_inside_tree() else null
	if tree != null:
		var camera: Camera3D = chamber.get_viewport().get_camera_3d()
		for prop in tree.get_nodes_in_group("facility_story_props"):
			if not (prop is Node3D) or camera == null:
				continue
			var at := (prop as Node3D).global_position
			if at.distance_squared_to(camera.global_position) > 18.0 * 18.0:
				continue
			out.append({"at": at + Vector3(0, 0.5, 0), "half": Vector3(0.4, 0.5, 0.4), "tag": str(prop.get_meta("facility_story_prop", "OBJECT")), "kind": "object"})
	return out
