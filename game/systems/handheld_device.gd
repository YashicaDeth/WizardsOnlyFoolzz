class_name HandheldDevice
extends Control

## The one object the interface lives inside.
##
## C1. `DESIGN/IN_GAME_INTERNET.md` opens by naming the problem this solves:
## *"The World Index (Tab), Living Map (M), Character Tree (T) and Allusions
## artwork (J) are four unrelated fullscreen panels bound to four keys. Nothing
## connects them."* Four keys, four looks, four ways of navigating, and no
## reason for any of them to know about the others.
##
## The earlier version of this file was the shell without the substance: it drew
## a convincing piece of junk hardware and then filled its screen with
## `_mode_lines()` — arrays of strings, one per mode, summarising panels that
## already existed and were far better. That is the "boxes of text" failure
## `DESIGN/INTERFACE_DIRECTION.md` now forbids outright, and it meant the device
## was a *fifth* interface rather than the replacement for the other four.
##
## So the device now **hosts the real panels**. The World Index and the Living
## Map are child controls sized into the screen aperture; the chassis draws
## under them and the damage draws over them. Nothing is summarised and nothing
## is duplicated.
##
## What the hardware adds, and why it is not just a frame:
##
## - **Raising it is a physical action and the world does not stop.** Nothing
##   here pauses the tree. You are holding a lit screen in a dark place.
## - **Condition is legible.** Dead pixels, cracks and scanlines sit *over* the
##   hosted panel, so a damaged device genuinely costs you information rather
##   than being decoration around a clean readout.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const Grunge := preload("res://systems/celloutz_grunge.gd")
const Motion := preload("res://systems/celloutz_motion.gd")
const WORLD_INDEX := preload("res://systems/world_index.gd")
const LIVING_MAP := preload("res://systems/living_map.gd")
const WIRE_RADIO := preload("res://systems/wire_radio.gd")
const CARRY := preload("res://systems/carry.gd")
const SIGNAL_FIELD := preload("res://systems/signal_field.gd")
const RADIAL := preload("res://systems/radial_menu.gd")
const RADIO_AUDIO := preload("res://systems/radio_audio.gd")

## L2.1. A part in the bag is worth putting on the wall. The handheld does not
## know the board exists — it hands the reference up, the way the index does.
signal pin_requested(ref: String, kind: String, title: String)
signal mode_changed(mode: String)
signal lead_found(station: String)

## TREE and ALLUSIONS are not gone, they are *inside* INDEX — the Tree axis is
## drawn on every dossier and the archive is a page rather than a mode. Listing
## them again here would recreate the six-panel problem inside the fix for it.
const MODES := ["INDEX", "MAP", "WIRE", "RADIO", "CARRY"]

const CASE := Color("1b1713")
const CASE_EDGE := Color("6d5a44")
const SCREEN_BG := Color("07120f")
const INK := Color("e6d4ac")
const AMBER := Color("b0552a")
const MOSS := Color("8a9a4a")
const ALERT := Color("a8281a")

var mode_index := 0
## Which thing in the bag is under the hand. The CARRY page had no selection at
## all, which was fine when it was a table and is not now that it is objects.
var carry_index := 0
var raised := 0.0
var is_open := false
var elapsed := 0.0
## C1.8 / C5.5 `v2`. The device was a screen with a fixed condition and one
## hardcoded crack seed, so every handheld in the game cracked in exactly the
## same places and arrived at the same wear no matter what its owner had been
## through. It is one object that belongs to one person, and it should carry
## what happened to it.
##
## `serial` is the device's own identity: the cracks are drawn from it, so two
## devices are never broken the same way. `condition` still says how bad it is;
## it now comes back from `WorldHistory` rather than starting at 0.78 forever.
const DEVICE_ID := "handheld"
var serial := 0
var condition := 0.78

## AS1.3. A real resource, not a torch that never runs out. Full charge is
## about eight real minutes of continuously holding it up — long enough that
## raising it to see is a genuine decision (AS1.2), short enough that a run
## with the device up for most of a fight actually costs something. Recharges
## only while pocketed, and roughly four times slower than it drains, so
## letting go is relief but not an instant refill.
var battery := 1.0
const BATTERY_DRAIN_PER_SECOND := 1.0 / 480.0
const BATTERY_RECHARGE_PER_SECOND := 1.0 / 1800.0
## AS1.1/AS1.5. How far the lamp throws light when it is lit. One constant
## shared by the light `bone_yard_hunt.gd` actually places in the world and by
## `light_radius()` below, so the two can never quietly disagree.
const LAMP_RANGE := 14.0
## Where the wear came from, in the device's own words. Kept so the status page
## can say "quarry impact" rather than showing a percentage.
var wear_log: Array = []
## C5.6 v3. Every impact used to crack the glass from the exact same
## authored point (0.74, 0.22 into the rect) no matter what actually hit it
## or where. Each entry is `{"at": Vector2, "severity": float}`, normalised
## within the screen — a real record of where a real impact landed, capped
## at the most recent few so the case does not accumulate an unreadable
## spiderweb over a long run.
var impacts: Array = []
const MAX_IMPACTS := 5
var radio: WireRadio
var carry: Carry
var signal_field: SignalField
var radial: Control
var radio_audio: Node

## A6.6 v2. The faults, with their character.
##
## Greg: *"dead pixels and scanlines are static; a failing panel flickers"*.
##
## The first pass was right about the thing it was arguing against — damage that
## reshuffles every frame reads as a noise effect rather than as a broken screen,
## and that is why these were nailed down. But it over-corrected into the other
## error: a panel with nothing but permanent faults is not failing, it has
## already failed and settled. What a dying screen actually does is fail
## *intermittently* — the same row, the same pixel, coming back and going again
## on its own schedule.
##
## So the positions stay exactly as fixed as they were. What varies is whether
## each fault is currently expressing itself, and every fault carries its own
## period and duty cycle, seeded from the device. Two handhelds fail differently
## and each one fails the same way every time you raise it.
var dead_pixels: Array[Dictionary] = []
var dead_rows: Array[Dictionary] = []
var crack_lines: Array[PackedVector2Array] = []
## Wall clock for the panel's faults. Runs whether or not the device is raised,
## so a fault does not restart its cycle every time you look at it.
var panel_clock := 0.0
## The backlight, 0..1. Sags and dips on a failing panel and sits at 1 on a
## healthy one — which is the difference between "this device is old" and "this
## device is dying", and the player should be able to see which.
var backlight := 1.0

var _clip: Control
var _overlay: Control
var _index: Control
var _map: Control
var _device_rect := Rect2()
var _screen_rect := Rect2()

## I0.10 v2. "Panels are hosted at one fixed size inside the handheld; a map
## you cannot lean into is a picture of a map." `device_size` used to be a
## single clamp with nothing that ever moved it — the World Index and the
## Living Map, however much detail either one has to show, always rendered
## into the same aperture. Held rather than toggled, because leaning in is
## a posture, not a mode: letting go puts the device back exactly where it
## was without a second keypress.
##
## `lean_override` exists for the same reason `bone_yard_hunt.gd`'s
## `grapple_pushing_override` does — `Input.is_key_pressed` does not update
## reliably in a headless test run, so a test sets this directly and
## production code only falls back to the real key when it is null.
var lean := 0.0
var lean_override: Variant = null
const LEAN_KEY := KEY_L
const LEAN_SCALE := 1.32


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	radio = WIRE_RADIO.new()
	carry = CARRY.new()
	signal_field = SIGNAL_FIELD.new()

	# Damage is fixed per device, not per frame: the same dead pixels and the
	# same cracks every time you raise it, the way a real broken screen behaves.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for index in 14:
		dead_pixels.append({
			"at": Vector2(rng.randf(), rng.randf()),
			# Most dead pixels are dead. A couple are stuck *on*, which is the
			# more annoying failure and the one people actually notice.
			"stuck_on": rng.randf() < 0.18,
			# And a few are not committed either way yet.
			"period": rng.randf_range(1.7, 11.0) if rng.randf() < 0.3 else 0.0,
			"duty": rng.randf_range(0.35, 0.85),
			"phase": rng.randf() * 40.0,
		})
	# The rows, seeded here rather than rebuilt inside `_draw_damage` from a
	# fresh RandomNumberGenerator every frame — which is what the old code did,
	# and why nothing about them could ever vary without varying everything.
	for index in 9:
		dead_rows.append({
			"y": rng.randf(),
			"weight": rng.randf_range(1.0, 3.0),
			# Two thirds are simply gone. The rest come and go, and those are
			# the ones that make the panel read as still failing.
			"period": 0.0 if rng.randf() < 0.62 else rng.randf_range(0.8, 6.5),
			"duty": rng.randf_range(0.3, 0.8),
			"phase": rng.randf() * 30.0,
			# A failing row often shears before it drops out entirely.
			"shear": rng.randf_range(0.0, 0.05) if rng.randf() < 0.4 else 0.0,
		})
	for index in 3:
		var start := Vector2(rng.randf(), rng.randf())
		var line := PackedVector2Array([start])
		var cursor := start
		for segment in 4:
			cursor += Vector2(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.2, 0.2))
			line.append(cursor)
		crack_lines.append(line)

	# The aperture. Children are clipped to it, which is what lets a full panel
	# be hosted inside a hole in a piece of hardware without spilling out of it.
	_clip = Control.new()
	_clip.name = "Aperture"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)

	_index = WORLD_INDEX.new()
	_index.name = "IndexPanel"
	_clip.add_child(_index)
	_map = LIVING_MAP.new()
	_map.name = "MapPanel"
	_clip.add_child(_map)

	# Added last so it draws over the hosted panels. A Control's own `_draw`
	# runs before its children, so damage could not be painted from here.
	_overlay = Control.new()
	_overlay.name = "Damage"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_damage)
	add_child(_overlay)
	# C2. The wheel lives outside the aperture: it is held in front of you, not
	# displayed on the device, so it must not be clipped by the screen.
	radial = RADIAL.new()
	radial.name = "Radial"
	add_child(radial)
	# A9.5. The receiver's own bus. Kept on the device rather than in the scene
	# because the radio is a property of the thing you are holding.
	radio_audio = RADIO_AUDIO.new()
	radio_audio.name = "RadioAudio"
	add_child(radio_audio)
	set_process(true)


## Handed the live world so the hosted panels and the radio read real state.
func bind(generator: Node, director: Node, contacts: Callable) -> void:
	if _map.has_method("bind"):
		_map.bind(generator, director, contacts)
	# A9.2. The town's footprints already exist on the generator; the radio
	# borrows them rather than keeping a second copy that can drift.
	if generator != null and "lots" in generator:
		radio.set_occluders(generator.get("lots"))


## C1.8 `v2`. The device remembers. Wear accumulates across the run instead of
## resetting to 0.78 every time the scene loads, and the serial is stable so the
## same handheld is always broken in the same places — just more of them.
func load_device() -> void:
	var record: Dictionary = WorldHistory.subject(DEVICE_ID)
	if record.is_empty():
		# A new device is nearly intact and gets its own identity. Not random per
		# session: written down, so it is this device from now on.
		serial = randi() % 900000 + 100000
		condition = 0.94
		battery = 1.0
		wear_log = []
		battery = 1.0
		save_device()
		return
	serial = int(record.get("serial", 90211))
	condition = clampf(float(record.get("condition", 0.78)), 0.0, 1.0)
	# AS1.3. A save from before the battery existed opens full rather than
	# empty — the honest read of "nobody has ever drained this yet".
	battery = clampf(float(record.get("battery", 1.0)), 0.0, 1.0)
	wear_log = (record.get("wear_log", []) as Array).duplicate()
	impacts = (record.get("impacts", []) as Array).duplicate(true)
	battery = clampf(float(record.get("battery", 1.0)), 0.0, 1.0)


func save_device() -> void:
	WorldHistory.register_subject(DEVICE_ID, {})
	WorldHistory.update_subject(DEVICE_ID, {
		"serial": serial,
		"condition": snappedf(condition, 0.001),
		"battery": snappedf(battery, 0.001),
		"wear_log": wear_log.duplicate(),
		"impacts": impacts.duplicate(true),
		"kind": "object",
	}, "device_changed")


## Something happened to it. Wear only ever goes one way — a cracked screen does
## not heal, and this is the one number in the game that is allowed to be a
## ratchet.
##
## C5.6 v3. `impact_at`, normalised 0..1 within the screen, is where it
## actually landed. A caller that genuinely has no location (an accumulated
## wear tick rather than a single blow) can leave it unset — it still gets a
## real, varied point instead of the one authored spot every crack used to
## share, derived from the device and how many impacts it has already taken
## rather than from `Vector2(-1,-1)` meaning "nowhere in particular".
func take_wear(amount: float, cause := "", impact_at := Vector2(-1, -1)) -> void:
	if amount <= 0.0:
		return
	var before := condition
	condition = clampf(condition - amount, 0.0, 1.0)
	if cause != "":
		wear_log.append(cause)
		while wear_log.size() > 8:
			wear_log.pop_front()
	var at := impact_at
	if at.x < 0.0 or at.y < 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = (serial + impacts.size() * 7919 + hash(cause)) & 0x7fffffff
		at = Vector2(rng.randf_range(0.2, 0.85), rng.randf_range(0.12, 0.7))
	impacts.append({"at": at, "severity": amount})
	while impacts.size() > MAX_IMPACTS:
		impacts.pop_front()
	if int(before * 10.0) != int(condition * 10.0):
		# Crossing a tenth is worth writing down; every scratch is not.
		WorldHistory.record_event("device_damaged", {"cause": cause, "condition": snappedf(condition, 0.01)})
	save_device()
	queue_redraw()


func open_device() -> void:
	load_device()
	is_open = true
	visible = true
	set_mode(current_mode())


func close_device() -> void:
	is_open = false
	# AS1.3. The natural checkpoint for a number that otherwise only changes a
	# little every frame — saving on every tick it drains would mean writing
	# the whole history file to disk sixty times a second for nothing.
	save_device()


func toggle_device() -> void:
	if is_open:
		close_device()
	else:
		open_device()


## C2. The wheel the player actually holds. The X-ray is a permanent segment
## because `xray_cursor.gd` was deliberately built as one seat of a ring that
## would grow, and this is that ring.
func open_radial() -> void:
	var wheel: Array = [
		{"id": "xray", "label": "X-RAY", "kind": "xray", "note": "see through what you are looking at"},
		{"id": "blade", "label": "BLADE", "kind": "blade", "note": "close, slow, opens people"},
		{"id": "sidearm", "label": "SIDEARM", "kind": "gun", "note": "loud, and everyone hears it"},
		{"id": "implant", "label": "IMPLANT", "kind": "implant", "note": "what is bolted into you"},
		{"id": "seal", "label": "SEAL", "kind": "seal", "note": "nothing is free"},
		{"id": "device", "label": "DEVICE", "kind": "mode", "note": "raise the handheld"},
	]
	radial.xray_on = bool(_index.get("xray")) if "xray" in _index else false
	radial.open_wheel(wheel)


func close_radial() -> void:
	radial.close_wheel()


func current_mode() -> String:
	return MODES[mode_index]


func cycle_mode(step: int) -> void:
	if not is_open:
		return
	set_mode(MODES[wrapi(mode_index + step, 0, MODES.size())])


## C2.6 `v2`. Cycling is how you learn the device; it is not how you use one you
## already know. A player who has had this thing in their hands for an hour
## should be able to reach the map without walking past the radio to get there.
func jump_to_mode(index: int) -> bool:
	if not is_open or index < 0 or index >= MODES.size():
		return false
	set_mode(MODES[index])
	return true


## Moves the hand through the bag. Host-driven, like every other control on
## this device.
func step_carry(by: int) -> void:
	if carry.items.is_empty():
		return
	carry_index = posmod(carry_index + by, carry.items.size())
	queue_redraw()


## Offers the selected part to whoever owns the wall, with its provenance
## attached, because a part on a conspiracy board is only evidence if it still
## says whose it was.
func pin_selected_part() -> bool:
	if carry_index < 0 or carry_index >= carry.items.size():
		return false
	var item: Dictionary = carry.items[carry_index]
	var label := str(item.get("label", "PART"))
	var from := str(item.get("from", ""))
	pin_requested.emit("part:%s@%s" % [label, from], "cutting", label)
	return true


func set_mode(mode: String) -> void:
	var found := MODES.find(mode.to_upper())
	if found < 0:
		return
	mode_index = found
	# WIRE is not a separate surface — it is the index already open on its own
	# page. Duplicating it would be the six-panel problem again in miniature.
	if current_mode() == "WIRE" and "page" in _index:
		_index.set("page", 2)
	elif current_mode() == "INDEX" and "page" in _index and int(_index.get("page")) == 2:
		_index.set("page", 0)
	# Both hosted panels gate their own drawing on an open flag, so entering a
	# mode has to open the panel as well as show it.
	if current_mode() == "MAP" and _map.has_method("open_map"):
		_map.open_map()
	if current_mode() in ["INDEX", "WIRE"] and _index.has_method("open"):
		_index.open()
	mode_changed.emit(current_mode())


## Where the character is standing. Reception, coverage and which parts of the
## Wire exist are all read off this, per C5: connectivity is a property of place.
func stand_at(world_position: Vector2) -> void:
	radio.stand_at(world_position)
	signal_field.stand_at(world_position)
	if "signal_grade" in _index:
		_index.set("signal_grade", signal_field.grade())
	# I3.2. Which BrokenWeb sites are reachable is a property of exactly where
	# the player is standing, the same as signal itself.
	if "current_emitter_id" in _index:
		_index.set("current_emitter_id", str(signal_field.reading().get("id", "")))


func _process(delta: float) -> void:
	elapsed += delta
	# A6.6 v2. The panel keeps failing whether or not you are looking at it,
	# so a fault does not restart its cycle every time the device comes up.
	panel_clock += delta
	_drive_backlight(delta)
	# AS1.2/AS1.3. The cost of holding it up to see: the torch and the screen
	# both burn charge while actually raised, not while pocketed, and it
	# recharges — slower — while left alone. See `_drive_battery()`.
	_drive_battery(delta)
	raised = Motion.blend(raised, delta, Motion.PANEL, is_open)
	if raised <= 0.001 and not is_open:
		# C2 / playtest. The radial is a child of this device, so hiding the
		# device hid the wheel with it — holding B dilated time and drew
		# nothing, which is exactly what the first playtester reported. The
		# wheel is reachable without raising the handheld, so the device stays
		# visible (though not raised) for as long as the wheel is up.
		if radial != null and is_instance_valid(radial) and radial.is_open:
			visible = true
			_clip.visible = false
			return
		visible = false
		_clip.visible = false
		return

	# The aperture is laid out here rather than in `_draw`, because the hosted
	# panels are real children and have to know their size before they render.
	var base_size := Vector2(minf(size.x * 0.88, 1140.0), minf(size.y * 0.86, 640.0))
	# I0.10 v2. Only worth doing while there is something to lean into — the
	# radio and CARRY have no hosted panel to gain detail from, and leaning
	# in on a fixed readout would just be a camera trick.
	var leanable := is_open and current_mode() in ["INDEX", "MAP", "WIRE"]
	var lean_key_held: bool = lean_override if lean_override != null else Input.is_key_pressed(LEAN_KEY)
	lean = Motion.blend(lean, delta, Motion.PANEL, leanable and lean_key_held)
	var leaned_size := base_size * lerpf(1.0, LEAN_SCALE, lean)
	var device_size := Vector2(minf(leaned_size.x, size.x * 0.98), minf(leaned_size.y, size.y * 0.98))
	var resting := Vector2((size.x - device_size.x) * 0.5, size.y + 60.0)
	var lifted := Vector2((size.x - device_size.x) * 0.5, (size.y - device_size.y) * 0.5)
	_device_rect = Rect2(resting.lerp(lifted, Motion.ease_out(raised)), device_size)
	_screen_rect = Rect2(_device_rect.position + Vector2(26, 62), _device_rect.size - Vector2(52, 104))
	_clip.position = _screen_rect.position
	_clip.size = _screen_rect.size
	_clip.visible = true
	_overlay.position = Vector2.ZERO
	_overlay.size = size

	var mode := current_mode()
	var showing_index := mode == "INDEX" or mode == "WIRE"
	_index.visible = showing_index
	_map.visible = mode == "MAP"
	if showing_index:
		_index.size = _clip.size
		_index.position = Vector2.ZERO
		# The index normally owns the screen and draws its own cursor; inside the
		# device the chassis is the frame, so it is told not to chase the mouse.
		if "cursor_follows_mouse" in _index:
			_index.set("cursor_follows_mouse", false)
		if "show_cursor" in _index:
			_index.set("show_cursor", false)
	if _map.visible:
		_map.size = _clip.size
		_map.position = Vector2.ZERO

	carry.age(delta)
	# You hear the receiver when you are holding it up and it is the thing you
	# are looking at. This used to pass strength 0.0 for "off", which is not
	# silence — it is a dead band, which is the loudest hiss the set makes — so
	# the radio played flat out in every scene that owned a handheld, and kept
	# playing after the player got out of the car.
	if mode == "RADIO" and raised > 0.001:
		var heard: Dictionary = radio.transmission()
		radio_audio.tune_to(str(heard.get("kind", "static")), float(heard.get("strength", 0.0)))
	else:
		radio_audio.silence()
	if mode == "RADIO":
		var found := radio.hold(delta)
		if found != "":
			lead_found.emit(found)
	_overlay.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if raised <= 0.001:
		return
	var alpha := clampf(raised, 0.0, 1.0)
	_draw_chassis(_device_rect, alpha)
	# I0.5. The screen is glass, not a lit panel. Painting SCREEN_BG opaque put
	# a green surface over the mirror and left the black showing only in the
	# bezel, which is a case with a screen in it — the thing this is not. The
	# tint is thin enough that the glass and the reader are still in there.
	BlackMirror.draw_glass(self, _screen_rect, alpha, elapsed)
	draw_rect(_screen_rect, SCREEN_BG * Color(1, 1, 1, 0.55 * alpha))
	BlackMirror.draw_reflection(self, _screen_rect, alpha, elapsed, 0.42)
	# The modes with no hosted panel draw straight onto the screen.
	var mode := current_mode()
	if mode == "RADIO":
		_draw_radio(_screen_rect, alpha)
	elif mode == "CARRY":
		_draw_carry(_screen_rect, alpha)


func _draw_chassis(rect: Rect2, alpha: float) -> void:
	draw_rect(rect.grow(5), Color("0a0806") * Color(1, 1, 1, 0.6 * alpha))
	# I0.5. Black glass first, not a case with a screen in it. Everything else
	# on this device is depth added to the dark rather than ink printed on a
	# panel — the difference between a thing you read and a thing you look into.
	BlackMirror.draw_glass(self, rect, alpha, elapsed)
	# The reader shows through most strongly where there is least to read, which
	# is true of real glass and means the mirror asserts itself in the silences.
	BlackMirror.draw_reflection(self, rect, alpha, elapsed, 0.55)
	draw_rect(rect, CASE_EDGE * Color(1, 1, 1, 0.55 * alpha), false, 2)
	Grunge.stain(self, rect.position + rect.size * Vector2(0.12, 0.9), 120.0, 4409, Grunge.RUST, 0.10 * alpha)
	Grunge.scratches(self, rect, 4411, 20)
	# Cable-tied battery clamped to the side, because nothing here is stock.
	var pack := Rect2(Vector2(rect.position.x + rect.size.x - 22, rect.position.y + 92), Vector2(16, rect.size.y - 180))
	draw_rect(pack, Color("241c16") * Color(1, 1, 1, alpha))
	draw_rect(pack, CASE_EDGE * Color(1, 1, 1, 0.5 * alpha), false, 1)
	for tie in 3:
		var y := pack.position.y + 22 + tie * (pack.size.y * 0.4)
		draw_line(Vector2(rect.position.x + rect.size.x - 30, y), Vector2(pack.end.x + 3, y), Color("100c0a") * Color(1, 1, 1, alpha), 3)
	CellOutzType.draw_stamped(self, rect.position + Vector2(26, 20), "CELLOUTZ", 19.0, AMBER * Color(1, 1, 1, alpha), ALERT * Color(1, 1, 1, 0.3 * alpha), 1.6)
	CellOutzType.draw_condensed(self, rect.position + Vector2(190, 26), "FIELD WIRE MK-II // SALVAGED // NOT SERVICEABLE", 9.0, CASE_EDGE * Color(1, 1, 1, 0.8 * alpha), 0.8)
	# The jester, pressed small into the bezel. It is on the back of the case;
	# this is the edge of it showing round the side.
	BlackMirror.draw_jester(self, Vector2(rect.end.x - 40, rect.position.y + 34), 26.0, 0.5 * alpha, elapsed)
	_draw_tabs(rect, alpha)
	_draw_status(rect, alpha)
	# Cracks last, over the content: the damage is in front of what you are
	# reading, because it is damage to the surface you are reading through.
	# C5.5 `v2`. Seeded from this device rather than from 90211, and the severity
	# is how broken it actually is rather than a constant. A pristine handheld
	# has almost no cracks; one that has been through a derby is a mess.
	# C5.6 `v3`. One fork cluster per recorded impact, each radiating from
	# where that particular hit actually landed rather than every crack in
	# the game sharing one authored point. A device with no recorded impacts
	# yet (an old save from before `impacts` existed, still carrying wear
	# from the previous system) falls back to the one legacy cluster so it
	# does not suddenly read as undamaged.
	var overall := clampf(1.0 - condition, 0.0, 1.0)
	if impacts.is_empty():
		if overall > 0.0:
			BlackMirror.draw_cracks(self, rect, alpha, serial, overall)
	else:
		for index in impacts.size():
			var impact: Dictionary = impacts[index]
			var severity := clampf(overall * (0.5 + float(impact.get("severity", 0.05)) * 4.0), 0.0, 1.0)
			BlackMirror.draw_cracks(self, rect, alpha, serial + index * 101, severity, impact.get("at", Vector2(0.74, 0.22)))


func _draw_tabs(rect: Rect2, alpha: float) -> void:
	var x := rect.position.x + 26.0
	var y := rect.position.y + rect.size.y - 34.0
	for index in MODES.size():
		var label: String = MODES[index]
		var width := CellOutzType.width(label, 11.0, 1.0) + 26.0
		var active := index == mode_index
		var tint: Color = AMBER if active else CASE_EDGE
		var shape := PackedVector2Array([
			Vector2(x, y), Vector2(x + width, y),
			Vector2(x + width - 6, y + 22), Vector2(x + 6, y + 22),
		])
		if active:
			draw_colored_polygon(shape, AMBER * Color(1, 1, 1, 0.22 * alpha))
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge, tint * Color(1, 1, 1, alpha), 1.4)
		CellOutzType.draw_text(self, Vector2(x + 13, y + 6), label, 11.0, (INK if active else tint) * Color(1, 1, 1, alpha), 1.0)
		# C2.7 v3. jump_to_mode() has reached a page directly since C2.6 v2
		# and nothing on the device itself ever said so — a control nobody
		# discovers is a control nobody has. Printed on the tab it actually
		# jumps to, the same register a real handheld prints a function key
		# legend in.
		CellOutzType.draw_condensed(self, Vector2(x + 6, y - 10), "F%d" % (index + 1), 8.0, tint * Color(1, 1, 1, 0.7 * alpha), 0.6)
		x += width + 8.0


func _draw_status(rect: Rect2, alpha: float) -> void:
	# C5. Signal first, because it is the thing that decides whether half the
	# device works, and "no signal" is useless without saying what would fix it.
	var reading: Dictionary = signal_field.reading()
	var grade := int(reading.get("grade", 0))
	var bars := clampf(float(reading.get("strength", 0.0)), 0.0, 1.0)
	var signal_tint: Color = ALERT if grade == SignalField.NONE else (MOSS if grade == SignalField.SURFACE else AMBER)
	# On the header row, not the footer: the footer is the mode rail and the
	# first placement printed the carrier name straight through the tabs.
	var strip_x := rect.position.x + rect.size.x - 330.0
	var strip_y := rect.position.y + 38.0
	for bar in 4:
		var lit := float(bar) / 4.0 < bars
		var height := 4.0 + float(bar) * 3.0
		draw_rect(Rect2(Vector2(strip_x + bar * 7.0, strip_y - height), Vector2(5, height)), (signal_tint if lit else CASE_EDGE * Color(1, 1, 1, 0.3)) * Color(1, 1, 1, alpha))
	var label := str(reading.get("source", ""))
	if grade == SignalField.UNDERBELLY:
		label += "  //  DEEP"
	elif grade == SignalField.NONE:
		var carrier: Dictionary = signal_field.nearest_carrier()
		if not carrier.is_empty():
			label = "NO CARRIER \u2014 NEAREST %s, %dM" % [str(carrier.get("name", "")), int(carrier.get("distance", 0.0))]
	CellOutzType.draw_condensed(self, Vector2(strip_x + 36.0, strip_y - 9.0), label, 9.0, signal_tint * Color(1, 1, 1, 0.85 * alpha), 0.7)

	# Named apart from the signal label above: both live in this function now and
	# GDScript will not take the same `var` twice in one scope.
	# AS1.3. This readout is labelled "CELL" and drawn as a battery gauge, but
	# read `condition` — the screen's own physical wear, already shown through
	# cracks and backlight sag — until there was a real charge to show instead.
	var charge := clampf(battery, 0.0, 1.0)
	var tint: Color = ALERT if charge < 0.35 else MOSS
	var cell_label := "CELL %02d%%" % roundi(charge * 100.0)
	var cell_width := CellOutzType.width_condensed(cell_label, 10.0, 0.9)
	CellOutzType.draw_condensed(self, Vector2(rect.position.x + rect.size.x - 30 - cell_width, rect.position.y + rect.size.y - 30), cell_label, 10.0, tint * Color(1, 1, 1, alpha), 0.9)
	for cell in 8:
		var lit := float(cell) / 8.0 < charge
		var bar := Rect2(Vector2(rect.position.x + rect.size.x - 150 + cell * 9.0, rect.position.y + rect.size.y - 30), Vector2(6, 11))
		draw_rect(bar, (tint if lit else CASE_EDGE * Color(1, 1, 1, 0.3)) * Color(1, 1, 1, alpha))


## C1.5. Drawn by the overlay child so it lands on top of whatever panel is
## hosted. A damaged device has to actually cost you information; damage painted
## underneath the readout is a frame, not a fault.
## A6.6 v2. What the backlight is doing. A sound panel holds at full and this
## is a no-op; a failing one sags, breathes, and now and then drops hard for
## a moment before coming back. Driven off `condition` so it is a symptom of
## the device being wrecked rather than an effect somebody turned on.
func _drive_backlight(delta: float) -> void:
	var wear := 1.0 - clampf(condition, 0.0, 1.0)
	if wear <= 0.02:
		backlight = 1.0
		return
	# The steady state: a worn panel is simply dimmer.
	var want := 1.0 - wear * 0.22
	# A slow breath on top, too slow to read as an animation.
	want -= absf(sin(panel_clock * 0.37)) * wear * 0.08
	# And the dropouts. Rare, brief, and more frequent the worse it is.
	var cycle: float = fmod(panel_clock, 9.0 - wear * 5.0)
	if cycle < 0.09:
		want -= wear * 0.55
	# Recovery is quicker than the drop, which is what makes a dropout read
	# as a fault rather than as a fade.
	var rate: float = 9.0 if want > backlight else 34.0
	backlight = move_toward(backlight, clampf(want, 0.05, 1.0), delta * rate)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_redraw()


## AS1.3. Runs down only while actually held up; trickles back only while
## pocketed, and far slower than it drains. `raised` rather than `is_open` on
## purpose — the blend already models the device settling into your hand, and
## the light should not snap on at full draw the instant the key is pressed.
func _drive_battery(delta: float) -> void:
	if raised > 0.5:
		battery = clampf(battery - BATTERY_DRAIN_PER_SECOND * delta, 0.0, 1.0)
	else:
		battery = clampf(battery + BATTERY_RECHARGE_PER_SECOND * delta, 0.0, 1.0)


## AS1.1. Whether the lamp is actually throwing light right now — raised
## enough to count as held up, and with something left to give it.
func is_lit() -> bool:
	return raised > 0.5 and battery > 0.0


## Same question, same answer — kept as a second name because
## `bone_yard_hunt.gd`'s own light-driving function was already written
## against it. One condition (`is_lit()`) underneath either name, so the two
## can never quietly disagree about whether the torch is on.
func torch_active() -> bool:
	return is_lit()


func battery_percent() -> float:
	return battery


## AS1.5. How far the light reaches, for anything that wants to know whether
## it can see this device from where it stands — the hook AS1.5 ("its light is
## what gives you away at night") asks for. There is no perception/stealth
## system in the project yet to wire this into; it exists so one can read it
## the day it does, rather than that system inventing its own answer to
## "is the player lit right now".
func light_radius() -> float:
	return LAMP_RANGE if is_lit() else 0.0


## A6.6 v2. Whether a fault is currently expressing itself. A fault with no
## period is permanent and always answers true; one with a period is on for
## `duty` of each cycle. Square rather than smooth on purpose — a scanline does
## not fade in, it is there or it is not.
func _fault_live(fault: Dictionary) -> bool:
	var period := float(fault.get("period", 0.0))
	if period <= 0.0:
		return true
	var through: float = fmod(panel_clock + float(fault.get("phase", 0.0)), period) / period
	return through < float(fault.get("duty", 0.6))


func _draw_damage() -> void:
	if raised <= 0.001:
		return
	var alpha := clampf(raised, 0.0, 1.0)
	var rect := _screen_rect
	var wear := 1.0 - clampf(condition, 0.0, 1.0)
	for scan in range(0, int(rect.size.y), 3):
		_overlay.draw_line(Vector2(rect.position.x, rect.position.y + scan), Vector2(rect.end.x, rect.position.y + scan), Color(0, 0, 0, 0.12 * alpha), 1.0)

	# A6.6 v2. The backlight, before anything drawn on it. A sound panel sits at
	# full and this does nothing; a failing one sags and occasionally drops
	# further, which is the single most recognisable symptom of a screen on its
	# way out and costs one rectangle.
	if backlight < 0.999:
		_overlay.draw_rect(rect, Color(0, 0, 0, (1.0 - backlight) * 0.5 * alpha))

	# Dead rows: whole scanlines that never light. The positions are fixed for
	# the life of the device; which of them are currently out is not.
	var rows := int(wear * float(dead_rows.size()))
	for index in mini(rows, dead_rows.size()):
		var row: Dictionary = dead_rows[index]
		if not _fault_live(row):
			continue
		var y: float = rect.position.y + float(row["y"]) * rect.size.y
		var shear: float = float(row.get("shear", 0.0)) * rect.size.x
		if shear > 0.0:
			# A row on the way out tears sideways before it drops. Quantised, so
			# it snaps between two offsets rather than sliding, which is what a
			# failing ribbon connector actually looks like.
			shear *= 1.0 if fmod(panel_clock * 7.0 + float(row["phase"]), 2.0) < 1.0 else -1.0
		_overlay.draw_line(
			Vector2(rect.position.x + shear, y),
			Vector2(rect.end.x + shear, y),
			Color(0, 0, 0, 0.75 * alpha),
			float(row["weight"])
		)

	for pixel: Dictionary in dead_pixels:
		if not _fault_live(pixel):
			continue
		var point: Vector2 = pixel["at"]
		var cell := Rect2(rect.position + Vector2(point.x * rect.size.x, point.y * rect.size.y), Vector2(2, 2))
		if bool(pixel.get("stuck_on", false)):
			# Stuck on, not dead: a lit sub-pixel, which is brighter than
			# anything the panel is meant to be showing.
			_overlay.draw_rect(cell, Color(0.72, 0.86, 0.74, 0.9 * alpha))
		else:
			_overlay.draw_rect(cell, Color(0, 0, 0, 0.8 * alpha))
	for line in crack_lines:
		var run := PackedVector2Array()
		for point in line:
			run.append(rect.position + Vector2(point.x * rect.size.x, point.y * rect.size.y))
		_overlay.draw_polyline(run, Color(0, 0, 0, 0.66 * alpha), 2.4)
		_overlay.draw_polyline(run, INK * Color(1, 1, 1, 0.10 * alpha), 1.0)
	# The glass itself, over everything.
	_overlay.draw_rect(rect, Color(0.55, 0.72, 0.62, 0.035 * alpha))


# --- the two modes that have no hosted panel ------------------------------

## A9.1. The dial: a real sweep with the band drawn under it, stations as ticks
## whose height is how well they are actually coming in from where you stand.
func _draw_radio(rect: Rect2, alpha: float) -> void:
	var signal_state: Dictionary = radio.transmission()
	CellOutzType.draw_stamped(self, rect.position + Vector2(24, 22), "FIELD RECEIVER", 18.0, AMBER * Color(1, 1, 1, alpha), ALERT * Color(1, 1, 1, 0.3 * alpha), 1.4)
	var dial := Rect2(rect.position + Vector2(24, 76), Vector2(rect.size.x - 48, 76))
	draw_rect(dial, Color(0, 0, 0, 0.34 * alpha))
	draw_rect(dial, CASE_EDGE * Color(1, 1, 1, 0.5 * alpha), false, 1.0)
	# Band ticks every megahertz, taller every five.
	var span := WireRadio.BAND_HIGH - WireRadio.BAND_LOW
	var mark := WireRadio.BAND_LOW
	while mark <= WireRadio.BAND_HIGH:
		var x := dial.position.x + (mark - WireRadio.BAND_LOW) / span * dial.size.x
		var tall := fmod(mark, 5.0) < 0.01
		draw_line(Vector2(x, dial.end.y), Vector2(x, dial.end.y - (12.0 if tall else 6.0)), INK * Color(1, 1, 1, 0.25 * alpha), 1.0)
		if tall:
			CellOutzType.draw_condensed(self, Vector2(x - 9, dial.end.y + 4), "%d" % int(mark), 8.0, INK * Color(1, 1, 1, 0.35 * alpha), 0.6)
		mark += 1.0
	for station in radio.band():
		var x := dial.position.x + (float(station.khz) - WireRadio.BAND_LOW) / span * dial.size.x
		var reach := bool(station.in_reach)
		var power := float(station.strength)
		var tint: Color = MOSS if reach else CASE_EDGE
		draw_line(Vector2(x, dial.end.y - 14), Vector2(x, dial.end.y - 14 - 40.0 * maxf(power, 0.12)), tint * Color(1, 1, 1, (0.35 + power * 0.65) * alpha), 3.0)
		if power > 0.25:
			CellOutzType.draw_condensed(self, Vector2(x - 40, dial.position.y + 6), str(station.name), 8.0, tint * Color(1, 1, 1, alpha), 0.6)
	# The needle.
	var needle_x := dial.position.x + (radio.khz - WireRadio.BAND_LOW) / span * dial.size.x
	draw_line(Vector2(needle_x, dial.position.y - 6), Vector2(needle_x, dial.end.y + 2), ALERT * Color(1, 1, 1, alpha), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(needle_x, dial.position.y - 6), Vector2(needle_x + 6, dial.position.y - 14), Vector2(needle_x - 6, dial.position.y - 14),
	]), ALERT * Color(1, 1, 1, alpha))
	CellOutzType.draw_text(self, rect.position + Vector2(24, 168), "%06.2f" % radio.khz, 26.0, INK * Color(1, 1, 1, alpha), 1.4)
	# Measured off the readout rather than guessed: "088.60" at cap 26 runs to
	# about 166px and the name was starting at 150.
	var dial_width := CellOutzType.width("%06.2f" % radio.khz, 26.0, 1.4)
	CellOutzType.draw_condensed(self, rect.position + Vector2(24 + dial_width + 22, 178), str(signal_state.get("name", "CARRIER")), 11.0, MOSS * Color(1, 1, 1, alpha), 0.9)

	# What is coming out of it. Worn type, scaled by how badly it is coming in -
	# a weak signal is heard *wrongly*, not quietly.
	var clarity := float(signal_state.get("strength", 0.0))
	var body := str(signal_state.get("text", ""))
	var wrapped := _wrap(body, 62)
	var y := rect.position.y + 216.0
	for line in wrapped:
		CellOutzType.draw_worn(self, Vector2(rect.position.x + 24, y), str(line), 12.0, INK * Color(1, 1, 1, alpha), (1.0 - clarity) * 0.8, 0.9)
		y += 22.0
		if y > rect.end.y - 60.0:
			break
	# A9.3. The lock, when a hook station is being held.
	var progress: float = radio.lock_progress()
	if progress > 0.01:
		var bar := Rect2(Vector2(rect.position.x + 24, rect.end.y - 44), Vector2(rect.size.x - 48, 12))
		draw_rect(bar, INK * Color(1, 1, 1, 0.10 * alpha))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), MOSS * Color(1, 1, 1, alpha))
		CellOutzType.draw_condensed(self, Vector2(rect.position.x + 24, rect.end.y - 62), "HOLDING A LOCK", 9.0, MOSS * Color(1, 1, 1, alpha), 0.8)


## C4. The inventory that has existed in `WorldHistory` since the Hunt Grounds
## were built and has never once been on screen. Drawn as objects with a mass, a
## condition and a provenance, because B4 already produces parts that know which
## person they came off and throwing that away at the point of carrying it would
## break B5, the ritual camera and the organ trade all at once.
func _draw_carry(rect: Rect2, alpha: float) -> void:
	CellOutzType.draw_stamped(self, rect.position + Vector2(24, 22), "CARRIED", 18.0, AMBER * Color(1, 1, 1, alpha), ALERT * Color(1, 1, 1, 0.3 * alpha), 1.4)
	var burden: float = carry.burden()
	var tone: Color = ALERT if burden > 1.0 else MOSS
	var load_text := "%0.1f / %0.0f KG" % [carry.total_mass(), Carry.CAPACITY]
	var load_width := CellOutzType.width_condensed(load_text, 12.0, 0.9)
	CellOutzType.draw_condensed(self, Vector2(rect.end.x - 26 - load_width, rect.position.y + 26), load_text, 12.0, tone * Color(1, 1, 1, alpha), 0.9)
	var track := Rect2(rect.position + Vector2(24, 52), Vector2(rect.size.x - 48, 8))
	draw_rect(track, INK * Color(1, 1, 1, 0.10 * alpha))
	draw_rect(Rect2(track.position, Vector2(track.size.x * minf(burden, 1.0), track.size.y)), tone * Color(1, 1, 1, alpha))
	if burden > 1.0:
		draw_rect(Rect2(track.position + Vector2(0, -3), Vector2(track.size.x * clampf(burden - 1.0, 0.0, 1.0), 3)), ALERT * Color(1, 1, 1, alpha))

	if carry.items.is_empty():
		CellOutzType.draw_condensed(self, rect.position + Vector2(24, 88), "NOTHING ON YOU WORTH LISTING.", 12.0, INK * Color(1, 1, 1, 0.4 * alpha), 0.9)
		return

	# I0.4. This was a spreadsheet: name, condition and weight in aligned
	# columns with half the page blank. You are carrying pieces of people, and a
	# packing manifest is the one presentation that makes that ordinary. They are
	# drawn as objects in a bag now — sized by their real mass, shaped by what
	# they are, tinted by how fresh they are, and tagged with whose they were.
	# Playtest, 12 Sep: the first player filled the bag and the page became a
	# wall of overlapping labels. A bag with fourteen skin chunks in it is not
	# fourteen things to a person carrying it — it is "skin, fourteen of them".
	# Grouped by what they are and whose they were, so a full bag reads.
	var groups: Array = []
	var seen: Dictionary = {}
	for item: Dictionary in carry.items:
		var key := "%s|%s|%s" % [str(item.get("label", "")), str(item.get("from", "")), str(item.get("kind", ""))]
		if seen.has(key):
			var at: int = seen[key]
			var group: Dictionary = groups[at]
			group["count"] = int(group["count"]) + 1
			group["mass"] = float(group["mass"]) + float(item.get("mass", 0.5))
			# The group is as stale as its freshest member is not.
			group["fresh"] = minf(float(group["fresh"]), carry.freshness(item))
			continue
		seen[key] = groups.size()
		groups.append({
			"item": item,
			"count": 1,
			"mass": float(item.get("mass", 0.5)),
			"fresh": carry.freshness(item),
		})
	var columns := 3
	var rows := maxi(int(ceil(float(groups.size()) / float(columns))), 1)
	var row_height := 108.0
	var bag_bottom := rect.end.y - 42.0
	var bag_top := maxf(rect.position.y + 72.0, bag_bottom - 96.0 - float(rows) * row_height)
	var bag := Rect2(Vector2(rect.position.x + 24.0, bag_top), Vector2(rect.size.x - 48.0, bag_bottom - bag_top))
	draw_rect(bag, Color(0, 0, 0, 0.22 * alpha))
	draw_rect(bag, INK * Color(1, 1, 1, 0.10 * alpha), false, 1.0)
	# A slack line across the top: the mouth of the bag, sagging under the load.
	var sag := 6.0 + burden * 16.0
	var mouth := PackedVector2Array()
	for step in 13:
		var t := float(step) / 12.0
		mouth.append(bag.position + Vector2(bag.size.x * t, sin(t * PI) * sag))
	draw_polyline(mouth, INK * Color(1, 1, 1, 0.22 * alpha), 1.5)
	# Things settle to the bottom of a bag. Rows fill upward from the floor, so
	# the empty space is under the slack mouth rather than below the contents
	# like unused rows of a table.
	var floor_y := bag.end.y - 58.0
	var ceiling := bag.position.y + 40.0
	if rows > 1:
		row_height = minf(row_height, (floor_y - ceiling) / float(rows - 1))
	var top_row := floor_y - float(rows - 1) * row_height
	var spread := (bag.size.x - 120.0) / float(columns - 1)
	var cell_width := spread - 14.0
	for index in groups.size():
		var group: Dictionary = groups[index]
		var item: Dictionary = group["item"]
		var count: int = int(group["count"])
		var fresh: float = float(group["fresh"])
		# A pile of ten reads bigger than one, but not ten times bigger.
		var mass := clampf(float(group["mass"]) / maxf(sqrt(float(count)), 1.0), 0.1, 4.0)
		# Carry files layer names as kinds, so a severed arm arrives as "muscle"
		# with whole_limb set. Shape follows what the thing actually is.
		var kind := str(item.get("kind", "goods"))
		if bool(item.get("whole_limb", false)):
			kind = "limb"
		# Each object takes the room its mass earns rather than a fixed line.
		var radius := 19.0 + mass * 13.0
		if kind != "organ" and kind != "cybernetic" and kind != "bone" and kind != "limb":
			radius = maxf(radius, 23.0)
		var column := index % columns
		var row := index / columns
		var at := Vector2(bag.position.x + 60.0 + float(column) * spread, top_row + float(row) * row_height)
		# Nothing in a bag sits on a grid. Nudged off it, deterministically.
		at += Vector2(sin(float(index) * 2.7) * 13.0, cos(float(index) * 1.9) * 9.0)
		at.y = clampf(at.y, ceiling, floor_y)
		if index == posmod(carry_index, maxi(carry.items.size(), 1)):
			# Under the hand. A ring of pencil round the thing, not a highlight
			# box — this page has no boxes left in it.
			draw_arc(at, radius + 11.0, 0.0, TAU, 26, AMBER * Color(1, 1, 1, (0.5 + 0.25 * sin(elapsed * 3.0)) * alpha), 1.4)
			CellOutzType.draw_condensed(self, at + Vector2(-radius, -radius - 17.0), "P TO PIN", 7.0, AMBER * Color(1, 1, 1, 0.7 * alpha), 0.6)
		# A shadow underneath, so the thing is resting on something.
		draw_colored_polygon(_ellipse_points(at + Vector2(0, radius * 0.92), radius * 0.95, radius * 0.22, 14), Color(0, 0, 0, 0.35 * alpha))
		if count > 1:
			for behind in mini(count - 1, 3):
				var shove := Vector2(-4.0 - float(behind) * 3.0, -3.0 - float(behind) * 2.5)
				_draw_carried(at + shove, radius * (0.94 - float(behind) * 0.05), kind, fresh, "", alpha * 0.45)
		_draw_carried(at, radius, kind, fresh, str(item.get("lien", "")), alpha)
		var shown := str(item.get("label", "")).to_upper()
		if count > 1:
			shown += "  x%d" % count
		var label := _fit(shown, cell_width, 9.0, 0.7)
		var label_width := CellOutzType.width_condensed(label, 9.0, 0.7)
		CellOutzType.draw_condensed(self, at + Vector2(-label_width * 0.5, radius + 12.0), label, 9.0, INK * Color(1, 1, 1, 0.85 * alpha), 0.7)
		var from := str(item.get("from", ""))
		if from != "":
			# A tag on a short string, low and to the right of the thing it is
			# tied to. Somebody's name on your property is a label somebody else
			# tied on, and it has to read as belonging to that object.
			var origin := _fit(str(WorldHistory.subject(from).get("name", from)).to_upper(), cell_width * 0.8, 7.0, 0.6)
			var tag_width := CellOutzType.width_condensed(origin, 7.0, 0.6)
			var tag := Rect2(at + Vector2(radius * 0.86, radius * 0.46), Vector2(tag_width + 11.0, 13.0))
			var knot := at + Vector2(radius * 0.42, radius * 0.18)
			if tag.end.x > bag.end.x - 8.0:
				tag.position.x = at.x - radius * 0.86 - tag.size.x
				knot = at + Vector2(-radius * 0.42, radius * 0.18)
			draw_line(knot, tag.position + Vector2(tag.size.x * 0.5, 3), INK * Color(1, 1, 1, 0.3 * alpha), 1.0)
			draw_rect(tag, Color("d9c49a") * Color(1, 1, 1, 0.13 * alpha))
			draw_rect(tag, INK * Color(1, 1, 1, 0.22 * alpha), false, 1.0)
			CellOutzType.draw_condensed(self, tag.position + Vector2(5, 3), origin, 7.0, Color("d9c49a") * Color(1, 1, 1, 0.7 * alpha), 0.6)


## Trims a label to the room its own cell has. Nothing on this page is allowed
## to run into its neighbour, which is what made the old columns necessary.
static func _fit(text: String, width: float, cap_height: float, tracking: float) -> String:
	if CellOutzType.width_condensed(text, cap_height, tracking) <= width:
		return text
	var trimmed := text
	while trimmed.length() > 1 and CellOutzType.width_condensed(trimmed + ".", cap_height, tracking) > width:
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	return trimmed.strip_edges() + "."


static func _ellipse_points(centre: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		var angle := TAU * float(index) / float(segments)
		points.append(centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


## Each kind of thing is a different shape, so a bag of parts can be read at a
## glance without any of it being named.
func _draw_carried(at: Vector2, radius: float, kind: String, fresh: float, lien: String, alpha: float) -> void:
	var wet: Color = Color("7a1a16").lerp(Color("46402c"), 1.0 - fresh)
	match kind:
		"organ":
			# Lobed and glistening while it is fresh, dull and shrunken when not.
			for lobe in 3:
				var offset := Vector2(cos(float(lobe) * 2.2) * radius * 0.28, sin(float(lobe) * 2.2) * radius * 0.22)
				draw_circle(at + offset, radius * (0.72 - float(lobe) * 0.08), wet * Color(1, 1, 1, (0.55 + fresh * 0.35) * alpha))
			draw_circle(at + Vector2(-radius * 0.22, -radius * 0.26), radius * 0.16, Color(1, 1, 1, 0.16 * fresh * alpha))
		"limb":
			# A tapered mass with bone showing at the cut.
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(-radius * 0.38, -radius), at + Vector2(radius * 0.38, -radius * 0.86),
				at + Vector2(radius * 0.26, radius), at + Vector2(-radius * 0.3, radius * 0.9),
			]), wet * Color(1, 1, 1, (0.6 + fresh * 0.3) * alpha))
			draw_circle(at + Vector2(0, -radius * 0.92), radius * 0.2, Color("cfc2a4") * Color(1, 1, 1, 0.8 * alpha))
		"bone":
			# Pale, hard, and the only thing in the bag that does not rot.
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(-radius * 0.26, -radius), at + Vector2(radius * 0.26, -radius),
				at + Vector2(radius * 0.2, radius * 0.9), at + Vector2(-radius * 0.2, radius * 0.9),
			]), Color("cfc2a4") * Color(1, 1, 1, 0.72 * alpha))
			for knuckle in [-1.0, 1.0]:
				draw_circle(at + Vector2(-radius * 0.2, knuckle * radius * 0.94), radius * 0.22, Color("cfc2a4") * Color(1, 1, 1, 0.8 * alpha))
				draw_circle(at + Vector2(radius * 0.2, knuckle * radius * 0.94), radius * 0.22, Color("cfc2a4") * Color(1, 1, 1, 0.8 * alpha))
		"cybernetic":
			# Machined: flat faces, a seam, a mounting lug.
			draw_rect(Rect2(at - Vector2(radius * 0.62, radius * 0.5), Vector2(radius * 1.24, radius)), Color("8d9299") * Color(1, 1, 1, 0.62 * alpha))
			draw_rect(Rect2(at - Vector2(radius * 0.62, radius * 0.5), Vector2(radius * 1.24, radius)), Color("c1642c") * Color(1, 1, 1, 0.5 * alpha), false, 1.0)
			draw_line(at - Vector2(radius * 0.62, 0), at + Vector2(radius * 0.62, 0), Color("c1642c") * Color(1, 1, 1, 0.35 * alpha), 1.0)
			draw_circle(at + Vector2(radius * 0.48, -radius * 0.34), radius * 0.1, Color("c1642c") * Color(1, 1, 1, 0.7 * alpha))
		_:
			# Anything else is a sack: heavy at the bottom, gathered and tied at
			# the neck. A small tied rectangle read as a checkerboard, which is
			# the one thing a bag of loot must not look like.
			var body := PackedVector2Array()
			for step in 15:
				var angle := PI * (0.12 + 0.76 * float(step) / 14.0)
				body.append(at + Vector2(cos(angle) * -radius * 0.86, radius * 0.34 + sin(angle) * radius * 0.7))
			body.append(at + Vector2(radius * 0.2, -radius * 0.42))
			body.append(at + Vector2(-radius * 0.2, -radius * 0.42))
			draw_colored_polygon(body, Color("46402c") * Color(1, 1, 1, 0.62 * alpha))
			# The neck, pinched by a tie, with the cloth flaring above it.
			draw_line(at + Vector2(-radius * 0.26, -radius * 0.4), at + Vector2(radius * 0.26, -radius * 0.4), Color("6e6248") * Color(1, 1, 1, 0.6 * alpha), 3.0)
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(-radius * 0.22, -radius * 0.42), at + Vector2(radius * 0.22, -radius * 0.42),
				at + Vector2(radius * 0.4, -radius * 0.78), at + Vector2(-radius * 0.38, -radius * 0.74),
			]), Color("3b3626") * Color(1, 1, 1, 0.55 * alpha))
			# Two creases, so the cloth has weight in it.
			draw_line(at + Vector2(-radius * 0.3, -radius * 0.1), at + Vector2(-radius * 0.16, radius * 0.6), INK * Color(1, 1, 1, 0.16 * alpha), 1.0)
			draw_line(at + Vector2(radius * 0.22, -radius * 0.08), at + Vector2(radius * 0.3, radius * 0.52), INK * Color(1, 1, 1, 0.16 * alpha), 1.0)

	# Spoilage reads as a stain under the thing rather than as a number.
	if fresh < 0.7:
		Grunge.stain(self, at + Vector2(0, radius * 0.7), radius * (1.4 - fresh), int(at.x), Grunge.DRIED, (0.7 - fresh) * 0.35 * alpha)
	# A lien is somebody's claim on it, and it should be visible on the object.
	if lien != "":
		draw_arc(at, radius + 5.0, 0.0, TAU, 22, Color("b8a12a") * Color(1, 1, 1, 0.5 * alpha), 1.0)
		CellOutzType.draw_condensed(self, at + Vector2(-radius, -radius - 16.0), "OWED", 7.0, Color("b8a12a") * Color(1, 1, 1, 0.75 * alpha), 0.6)


func _wrap(text: String, width: int) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var candidate: String = word if line == "" else line + " " + word
		if candidate.length() > width and line != "":
			out.append(line)
			line = word
		else:
			line = candidate
	if line != "":
		out.append(line)
	return out
