extends CanvasLayer

## Escape, from anywhere. The game had no pause at all — Escape released the
## mouse and closed a panel if one was open, and that was the whole of it, so
## there was no way to stop, change anything or leave without killing the
## process.
##
## Autoloaded, so it works in the vat, the derby, the Hunt Grounds and the menu
## without any of them knowing about it. It runs on `_unhandled_input`, which
## reaches an autoload only after the current scene has declined the key — so a
## panel still closes on Escape first and the second press pauses. Nothing had
## to be rewired to get that ordering; it falls out of the tree order.
##
## Seamless per rule 3: the plate eases in over the frozen frame and eases out
## again. The world stays visible behind it. Nothing cuts.

const SETTINGS_ID := "settings"
const Grunge := preload("res://systems/celloutz_grunge.gd")
const Motion := preload("res://systems/celloutz_motion.gd")
const BOOT_SPLASH := preload("res://boot_splash.gd")

const VOID := Color("060b09")
const SMOKE := Color(0.03, 0.045, 0.038, 0.86)
const INK := Color("dce6ba")
const ACID := Color("b4da48")
const COPPER := Color("c1642c")
const ARTERIAL := Color("c81f16")
const BILE := Color("b8a12a")

const DESIGN := Vector2(560, 470)
## Named so the mixer and the settings page cannot disagree about them.
const BUSES := ["Master", "Music", "SFX", "Ambience"]

## Y1.1. The only actions actually read by name elsewhere — `bone_yard_hunt.gd`,
## `rift_derby.gd` and `vat_chamber.gd` all call `Input.get_vector`/`get_axis`
## with these four, plus the two held modifiers. Jump and the rest of combat
## are still hardcoded keys in Lane 1's files and are not rebindable from here.
const CONTROL_ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch"]
const CONTROL_LABELS := {
	"move_forward": "FORWARD",
	"move_back": "BACK",
	"move_left": "LEFT",
	"move_right": "RIGHT",
	"sprint": "SPRINT",
	"crouch": "CROUCH",
}

var open := false
var blend := 0.0
var page := "root"
var highlighted := 0
var clock := 0.0
var screen: Control
## Set to an action name while waiting for the next key press; empty otherwise.
var rebinding_action := ""
## project.godot's own bindings, captured once before any stored rebind is
## applied — what RESET TO DEFAULT puts back.
var _default_binds: Dictionary = {}

var _rows: Array[Dictionary] = []
## Greg, 24 September: the menus match the re-animated logo. The row you're on
## gets blood poured under it with drips; opening or changing page tears the
## rows sideways for a moment; the live seal sits in the corner; moving ticks.
const LOGO_FX := preload("res://shaders/logo_fx.gdshader")
const LOGO_AUDIO := preload("res://systems/logo_audio.gd")
const SEAL_PATH := "res://art/brand/wof_seal.png"
const POUR_SECONDS := 0.2
const TEAR_SECONDS := 0.18
var pour := 0.0
var tear := 0.0
var seal: TextureRect
var sounds: Node
var _poured_row := -1
var _poured_page := ""
var _factor := 1.0
var _origin := Vector2.ZERO


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen = Control.new()
	screen.name = "Plate"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.draw.connect(_draw_plate)
	add_child(screen)
	screen.visible = false
	seal = TextureRect.new()
	seal.name = "Seal"
	seal.texture = load(SEAL_PATH) as Texture2D
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var seal_fx := ShaderMaterial.new()
	seal_fx.shader = LOGO_FX
	seal_fx.set_shader_parameter("is_seal", true)
	seal_fx.set_shader_parameter("drips_on", 0.0)
	seal_fx.set_shader_parameter("calm", 0.8)
	seal.material = seal_fx
	screen.add_child(seal)
	sounds = LOGO_AUDIO.new()
	sounds.name = "PauseSounds"
	add_child(sounds)
	WorldHistory.register_subject(SETTINGS_ID, {
		"hud_opacity": 0.9,
		"hud_style": "rails",
		"reduced_glitch": false,
	})
	_ensure_buses()
	_restore_screen()
	_capture_default_binds()
	_restore_keybinds()
	_apply_mix()
	set_process(true)


## G5.1 groundwork. The project mixed everything into Master with no structure,
## so there was nothing to turn down. These exist whether or not anything is
## routed to them yet; a player can turn the music off before a single stream
## has been authored.
func _ensure_buses() -> void:
	# G5.1. Repairs the graph as well as building it: systems that create their
	# own effect chains used to point them straight at Master, around the mixer.
	AudioBus.ensure()
	for bus_name in BUSES:
		if bus_name == "Master":
			continue
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


func _volume(bus_name: String) -> float:
	var stored: Dictionary = WorldHistory.subject(SETTINGS_ID)
	return clampf(float(stored.get("volume_%s" % bus_name.to_lower(), 0.8)), 0.0, 1.0)


func _apply_mix() -> void:
	for bus_name in BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		if index == -1:
			continue
		var level := _volume(bus_name)
		AudioServer.set_bus_mute(index, level <= 0.001)
		# Linear slider, decibel bus. A 0-1 slider mapped straight onto dB is
		# the reason volume controls usually do nothing until the last tenth.
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))


func _set_volume(bus_name: String, level: float) -> void:
	WorldHistory.update_subject(SETTINGS_ID, {"volume_%s" % bus_name.to_lower(): clampf(level, 0.0, 1.0)}, "audio_setting_changed")
	_apply_mix()


func _gore_mode() -> String:
	return str(WorldHistory.subject(SETTINGS_ID).get("gore", "FULL"))


func _cycle_gore() -> void:
	const ORDER := ["FULL", "REDUCED", "OFF"]
	var next: String = ORDER[(maxi(0, ORDER.find(_gore_mode())) + 1) % ORDER.size()]
	WorldHistory.update_subject(SETTINGS_ID, {"gore": next}, "gore_setting_chosen")
	BaselineHuman.apply_gore_setting()


## AG1.4. Whether the window is filling the screen. Read from the window rather
## than from the saved value, so the row tells the truth even if something else
## changed it — a settings screen that disagrees with the window is worse than
## none.
func _fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func _set_fullscreen(on: bool, persist := true) -> void:
	# Headless verification has no window to resize; the preference still needs
	# to be testable and persist without asking the dummy display server to wait.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if persist:
		WorldHistory.update_subject(SETTINGS_ID, {"fullscreen": on}, "screen_setting_changed")


## Applied once at startup, because a setting that is saved and never reapplied
## is a setting that does not work.
func _restore_screen() -> void:
	var stored: Dictionary = WorldHistory.subject(SETTINGS_ID)
	if not stored.has("fullscreen"):
		return
	# Applying a preference is not the player changing it again.
	_set_fullscreen(bool(stored["fullscreen"]), false)


func _hud_opacity() -> float:
	return clampf(float(WorldHistory.subject(SETTINGS_ID).get("hud_opacity", 0.9)), 0.25, 1.0)


func _hud_style() -> String:
	return "arcs" if str(WorldHistory.subject(SETTINGS_ID).get("hud_style", "rails")) == "arcs" else "rails"


func _reduced_glitch() -> bool:
	return bool(WorldHistory.subject(SETTINGS_ID).get("reduced_glitch", false))


func _set_hud_opacity(value: float) -> void:
	WorldHistory.update_subject(SETTINGS_ID, {"hud_opacity": clampf(value, 0.25, 1.0)}, "hud_setting_changed")


func _cycle_hud_style() -> void:
	WorldHistory.update_subject(SETTINGS_ID, {"hud_style": "arcs" if _hud_style() == "rails" else "rails"}, "hud_setting_changed")


func _toggle_reduced_glitch() -> void:
	WorldHistory.update_subject(SETTINGS_ID, {"reduced_glitch": not _reduced_glitch()}, "hud_setting_changed")


func _capture_default_binds() -> void:
	for action in CONTROL_ACTIONS:
		var events := InputMap.action_get_events(action)
		if not events.is_empty() and events[0] is InputEventKey:
			_default_binds[action] = (events[0] as InputEventKey).physical_keycode


## Applied once at startup, same as the screen mode above — read from
## `project.godot`'s own defaults until a player has actually changed one.
func _restore_keybinds() -> void:
	var stored: Dictionary = WorldHistory.subject(SETTINGS_ID)
	for action in CONTROL_ACTIONS:
		var key := "keybind_%s" % action
		if stored.has(key):
			_bind_action(action, int(stored[key]))


func _bind_action(action: String, physical_keycode: int) -> void:
	InputMap.action_erase_events(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key_event)


## The physical key, not the localised keycode — matches how `project.godot`
## already stores its own defaults, and keeps working if the OS layout changes
## underneath a saved rebind.
func _apply_rebind(action: String, event: InputEventKey) -> void:
	_bind_action(action, event.physical_keycode)
	WorldHistory.register_subject(SETTINGS_ID, {})
	WorldHistory.update_subject(SETTINGS_ID, {"keybind_%s" % action: event.physical_keycode}, "keybind_changed")


func _reset_keybinds() -> void:
	WorldHistory.register_subject(SETTINGS_ID, {})
	for action in CONTROL_ACTIONS:
		var default_keycode: int = int(_default_binds.get(action, 0))
		if default_keycode != 0:
			_bind_action(action, default_keycode)
		WorldHistory.update_subject(SETTINGS_ID, {"keybind_%s" % action: default_keycode}, "keybind_reset")


func _key_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty() or not (events[0] is InputEventKey):
		return "—"
	return (events[0] as InputEventKey).as_text_physical_keycode()


## Rows are rebuilt each frame the plate is open, because their labels carry
## live values. The row list is the menu — there is no scene to keep in sync.
func _build_rows() -> void:
	_rows.clear()
	if page == "root":
		_rows.append({"id": "resume", "label": "RESUME", "value": ""})
		_rows.append({"id": "settings", "label": "SETTINGS", "value": ""})
		_rows.append({"id": "menu", "label": "LEAVE TO THE FRONT DOOR", "value": ""})
		return
	if page == "hud":
		_rows.append({"id": "hud_opacity", "label": "HUD OPACITY", "value": "%03d" % roundi(_hud_opacity() * 100.0), "slider": true})
		_rows.append({"id": "hud_style", "label": "HUD STYLE", "value": _hud_style().to_upper()})
		_rows.append({"id": "reduced_glitch", "label": "REDUCED GLITCH", "value": "ON" if _reduced_glitch() else "OFF"})
		_rows.append({"id": "settings_back", "label": "BACK", "value": ""})
		return
	if page == "controls":
		for action in CONTROL_ACTIONS:
			var label: String = str(CONTROL_LABELS.get(action, action.to_upper()))
			var value := "PRESS KEY" if rebinding_action == action else _key_label(action)
			_rows.append({"id": "bind_%s" % action, "label": label, "value": value})
		_rows.append({"id": "ctrl_reset", "label": "RESET TO DEFAULT", "value": ""})
		_rows.append({"id": "ctrl_back", "label": "BACK", "value": ""})
		return
	for bus_name in BUSES:
		_rows.append({"id": "vol_%s" % bus_name, "label": bus_name.to_upper(), "value": "%03d" % roundi(_volume(bus_name) * 100.0), "slider": true})
	_rows.append({"id": "gore", "label": "VIOLENCE", "value": _gore_mode()})
	# AG1.4, from the first playtest: "idk if there's a full screen option." There
	# was not. It belongs beside the other settings rather than in a key nobody
	# is told about, and it persists like everything else here.
	_rows.append({"id": "screen", "label": "SCREEN", "value": "FULL" if _fullscreen() else "WINDOWED"})
	_rows.append({"id": "hud", "label": "DISPLAY / HUD", "value": ">"})
	# Y1.1. Controls had no door on them anywhere in the project.
	_rows.append({"id": "controls", "label": "CONTROLS", "value": ""})
	_rows.append({"id": "back", "label": "BACK", "value": ""})


## F11 is the key every player already tries before looking for a setting.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11:
		_set_fullscreen(not _fullscreen())
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if open:
		close()
	else:
		open_gate()


func open_gate() -> void:
	if open:
		return
	open = true
	page = "root"
	highlighted = 0
	clock = 0.0
	rebinding_action = ""
	screen.visible = true
	tear = TEAR_SECONDS
	if sounds != null:
		sounds.cue("tear")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func close() -> void:
	if not open:
		return
	open = false
	rebinding_action = ""
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if rebinding_action != "":
		# Escape cancels rather than binding itself — it is the one key every
		# other menu in the game already uses to back out.
		if event.keycode != KEY_ESCAPE:
			_apply_rebind(rebinding_action, event as InputEventKey)
		rebinding_action = ""
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not open:
		return
	_build_rows()
	match event.keycode:
		KEY_UP, KEY_W:
			highlighted = (highlighted + _rows.size() - 1) % _rows.size()
		KEY_DOWN, KEY_S:
			highlighted = (highlighted + 1) % _rows.size()
		KEY_LEFT, KEY_A:
			_nudge(-1)
		KEY_RIGHT, KEY_D:
			_nudge(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_activate()
		_:
			return
	get_viewport().set_input_as_handled()


func _nudge(direction: int) -> void:
	var row: Dictionary = _rows[highlighted]
	var id := str(row.id)
	if id.begins_with("vol_"):
		var bus_name := id.trim_prefix("vol_")
		_set_volume(bus_name, _volume(bus_name) + 0.1 * float(direction))
	elif id == "gore":
		_cycle_gore()
	elif id == "screen":
		_set_fullscreen(not _fullscreen())
	elif id == "hud_opacity":
		_set_hud_opacity(_hud_opacity() + 0.05 * float(direction))
	elif id == "hud_style":
		_cycle_hud_style()
	elif id == "reduced_glitch":
		_toggle_reduced_glitch()


func _activate() -> void:
	var id := str(_rows[highlighted].id)
	match id:
		"resume":
			close()
		"settings", "settings_back":
			page = "settings"
			highlighted = 0
		"hud":
			page = "hud"
			highlighted = 0
		"back":
			page = "root"
			highlighted = 0
		"gore", "screen", "hud_opacity", "hud_style", "reduced_glitch":
			_nudge(1)
		"controls":
			page = "controls"
			highlighted = 0
		"ctrl_back":
			page = "settings"
			highlighted = 0
		"ctrl_reset":
			_reset_keybinds()
		"menu":
			close()
			Interstitial.travel("res://country_town_menu.tscn", "standing down")
		_:
			if id.begins_with("vol_"):
				_nudge(1)
			elif id.begins_with("bind_"):
				rebinding_action = id.trim_prefix("bind_")


func _process(delta: float) -> void:
	clock += delta
	# A new row (or a new page) starts a fresh pour; a new page also tears.
	if highlighted != _poured_row or page != _poured_page:
		if page != _poured_page and not _poured_page.is_empty():
			tear = TEAR_SECONDS
		elif _poured_row >= 0 and open and sounds != null:
			sounds.cue("drip")
		_poured_row = highlighted
		_poured_page = page
		pour = 0.0
	pour = minf(1.0, pour + delta / POUR_SECONDS)
	tear = maxf(0.0, tear - delta)
	blend = float(Motion.blend(blend, delta, 7.0, open))
	if blend <= 0.001 and not open:
		screen.visible = false
		return
	screen.visible = true
	_build_rows()
	screen.queue_redraw()


func _draw_plate() -> void:
	var viewport := screen.size
	if viewport.x < 200.0:
		viewport = screen.get_viewport_rect().size
	var eased: float = Motion.ease_out(blend)
	if eased <= 0.01:
		return
	_factor = clampf(minf(viewport.x / (DESIGN.x + 220.0), viewport.y / (DESIGN.y + 160.0)), 0.6, 1.5)
	_origin = (viewport - DESIGN * _factor) * 0.5

	# The world stays visible. A pause that blacks out what you were looking at
	# is a scene change wearing a menu's clothes.
	screen.draw_rect(Rect2(Vector2.ZERO, viewport), VOID * Color(1, 1, 1, 0.55 * eased))
	screen.draw_set_transform(_origin + Vector2(0, (1.0 - eased) * 26.0), 0.0, Vector2(_factor, _factor))

	var notch := 20.0
	var body := PackedVector2Array([
		Vector2(notch, 0), Vector2(DESIGN.x, 0), Vector2(DESIGN.x, DESIGN.y - notch),
		Vector2(DESIGN.x - notch, DESIGN.y), Vector2(0, DESIGN.y), Vector2(0, notch),
	])
	screen.draw_colored_polygon(body, SMOKE * Color(1, 1, 1, eased))
	Grunge.art_substrate(screen, Rect2(0, 0, DESIGN.x, DESIGN.y), 13, 0.09 * eased)
	Grunge.scratches(screen, Rect2(0, 0, DESIGN.x, DESIGN.y), 29, 14)
	var outline := body.duplicate()
	outline.append(body[0])
	screen.draw_polyline(outline, COPPER * Color(1, 1, 1, 0.62 * eased), 2.0)

	CellOutzType.draw_stamped(screen, Vector2(30, 26), "STOPPED", 30.0, ACID * Color(1, 1, 1, eased), ARTERIAL * Color(1, 1, 1, 0.3 * eased), 4.0)
	var subtitle := "DISPLAY / HUD" if page == "hud" else "SETTINGS" if page == "settings" else "CELLOUTZ / THE YARD IS STILL THERE"
	CellOutzType.draw_text(screen, Vector2(30, 68), subtitle, 10.0, INK * Color(1, 1, 1, 0.45 * eased), 1.4)
	screen.draw_line(Vector2(30, 84), Vector2(DESIGN.x - 30, 84), COPPER * Color(1, 1, 1, 0.4 * eased), 1.0)

	var row_pitch := minf(52.0, (DESIGN.y - 190.0) / maxf(1.0, float(_rows.size() - 1)))
	for index in _rows.size():
		var row: Dictionary = _rows[index]
		var top := 112.0 + index * row_pitch
		var lit := index == highlighted
		var accent := ACID if lit else INK
		# The tear: rows jump sideways for a moment on opening or a new page.
		var shove := 0.0
		if tear > 0.0:
			shove = (fmod(float(index) * 37.7 + clock * 91.0, 1.0) - 0.5) * 40.0 * (tear / TEAR_SECONDS)
		screen.draw_set_transform(_origin + Vector2(shove * _factor, (1.0 - eased) * 26.0), 0.0, Vector2(_factor, _factor))
		if lit:
			screen.draw_rect(Rect2(24, top - 12, DESIGN.x - 48, minf(40.0, row_pitch - 4.0)), accent * Color(1, 1, 1, 0.08 * eased))
			_draw_blood_under(top + minf(22.0, row_pitch * 0.62), eased, maxf(3.0, row_pitch * 0.28))
			var slide := 4.0 + sin(clock * 6.0) * 2.0
			screen.draw_colored_polygon(PackedVector2Array([
				Vector2(14 - slide, top - 2), Vector2(24 - slide, top + 7), Vector2(14 - slide, top + 16),
			]), accent * Color(1, 1, 1, eased))
		CellOutzType.draw_text(screen, Vector2(34, top), str(row.label), 17.0, accent * Color(1, 1, 1, (1.0 if lit else 0.7) * eased), 2.2)
		if bool(row.get("slider", false)):
			var level := _hud_opacity() if str(row.id) == "hud_opacity" else _volume(str(row.id).trim_prefix("vol_"))
			var bar := Rect2(DESIGN.x - 210, top + 4, 130, 8)
			screen.draw_rect(bar, Color(0, 0, 0, 0.5 * eased))
			screen.draw_rect(Rect2(bar.position, Vector2(bar.size.x * level, bar.size.y)), accent * Color(1, 1, 1, 0.75 * eased))
			screen.draw_rect(bar, INK * Color(1, 1, 1, 0.2 * eased), false, 1.0)
		if not str(row.value).is_empty():
			var value_x := DESIGN.x - 34.0 - CellOutzType.width(str(row.value), 15.0, 1.6)
			CellOutzType.draw_text(screen, Vector2(value_x, top), str(row.value), 15.0, accent * Color(1, 1, 1, 0.9 * eased), 1.6)

	screen.draw_set_transform(_origin + Vector2(0, (1.0 - eased) * 26.0), 0.0, Vector2(_factor, _factor))
	if page == "hud":
		CellOutzType.draw_text(screen, Vector2(34, 348), "OPACITY 25-100% / SAVED AUTOMATICALLY", 10.0, INK * Color(1, 1, 1, 0.5 * eased), 1.0)
		CellOutzType.draw_text(screen, Vector2(34, 374), "REDUCED GLITCH CALMS CAMERA GRAIN", 10.0, INK * Color(1, 1, 1, 0.5 * eased), 1.0)
	CellOutzType.draw_text(screen, Vector2(30, DESIGN.y - 28), "ESC RESUME  UP/DOWN MOVE  L/R ADJUST  ENTER SELECT", 9.0, INK * Color(1, 1, 1, 0.4 * eased), 1.0)
	screen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The live seal in the plate's corner, sized with it.
	if seal != null:
		var side := 78.0 * _factor
		seal.size = Vector2(side, side)
		seal.position = _origin + Vector2((DESIGN.x - 96.0) * _factor, 10.0 * _factor + (1.0 - eased) * 26.0)
		seal.modulate.a = eased
		(seal.material as ShaderMaterial).set_shader_parameter("beat", BOOT_SPLASH.heartbeat(clock) * 0.5)


## Blood poured under the row you're on, left to right, with three drips.
func _draw_blood_under(y: float, eased: float, drip_room := 14.0) -> void:
	var width := (DESIGN.x - 48.0) * ease(pour, 0.4)
	var blood := ARTERIAL * Color(1, 1, 1, 0.9 * eased)
	screen.draw_rect(Rect2(24, y, width, 3.0), blood)
	for drip in 3:
		var x := 24.0 + (DESIGN.x - 48.0) * (0.2 + 0.3 * float(drip))
		if x > 24.0 + width:
			continue
		# Never long enough to run into the row below.
		var length := minf(drip_room, (pour - (0.2 + 0.3 * float(drip))) * 60.0 + sin(clock * 2.0 + float(drip)) * 1.5 + drip_room * 0.4)
		screen.draw_line(Vector2(x, y + 2.0), Vector2(x, y + 2.0 + length), blood, 2.0)
		screen.draw_circle(Vector2(x, y + 3.0 + length), 2.2, blood)
