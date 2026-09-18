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
const PAGE_AUDIO := preload("res://systems/black_mirror_transition_audio.gd")
const FACILITY_TERRITORY := preload("res://systems/facility_territory.gd")
const RITUAL_LEDGER := preload("res://systems/ritual_ledger.gd")
const RESONANCE_READOUT := preload("res://systems/resonance_readout.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

## L2.1. A part in the bag is worth putting on the wall. The handheld does not
## know the board exists — it hands the reference up, the way the index does.
signal pin_requested(ref: String, kind: String, title: String)
signal mode_changed(mode: String)
signal lead_found(station: String)
## C1.7 `v2`. `drop()` itself only closes the device and flips `possessed` —
## this file owns no 3D space to put a dropped unit into (`bone_yard_hunt.gd`
## does). Whoever hosts this device connects to `dropped` and is hand the
## same identity payload `drop()`/`confiscate()` already return, to actually
## spawn something pickable and, later, call `repossess()` on it.
signal dropped(payload: Dictionary)

## TREE and ALLUSIONS are not gone, they are *inside* INDEX — the Tree axis is
## drawn on every dossier and the archive is a page rather than a mode. Listing
## them again here would recreate the six-panel problem inside the fix for it.
const MODES := ["INDEX", "MAP", "WIRE", "RADIO", "CARRY", "RITUAL", "FIELD"]
## I3.1 v3. Apps can keep their own information architecture, but the device
## owns how every one identifies itself and how the hand operates it.
const PAGE_ROLES := {
	"INDEX": "RECORD / DOSSIER",
	"MAP": "SATELLITE / GROUND",
	"WIRE": "NETWORK / SITES",
	"RADIO": "RECEIVER / BAND",
	"CARRY": "CUSTODY / OBJECTS",
	"RITUAL": "EVIDENCE / RITE",
	"FIELD": "RESONANCE / PRACTICE",
}
const PAGE_ACTIONS := {
	"INDEX": "POINT / OPEN RECORD",
	"MAP": "LEAN / SURVEY",
	"WIRE": "POINT / FOLLOW LINK",
	"RADIO": "TUNE / HOLD",
	"CARRY": "STEP / PIN OBJECT",
	"RITUAL": "N / RECORD EVIDENCE",
	"FIELD": "READ / PRACTISE",
}

const CASE := Color("1b1713")
const CASE_EDGE := Color("6d5a44")
const SCREEN_BG := Color("07120f")
const INK := Color("e6d4ac")
const AMBER := Color("b0552a")
const MOSS := Color("8a9a4a")
const ALERT := Color("a8281a")
const HAND_SHADOW := Color("160d0a")
const HAND_SKIN := Color("4a271d")
const SCREEN_SPILL := Color("9bd4b0")
## C10.1 first seam. The authored Index and Map are 16:9 documents. Radio,
## Carry and Ritual used to draw across the mirror's wider physical glass,
## making the content origin and usable height jump when the mode changed.
## The glass stays wide; one centred working aperture now belongs to the device.
const PAGE_ASPECT := 16.0 / 9.0

var mode_index := 0
## I3.2 v3. `mode_index` is where the hand asked to go; this is the page still
## visible behind the sliding shutter. They become equal only under full cover.
var displayed_mode_index := 0
var pending_mode_index := -1
var page_transition := 1.0
var page_transition_direction := 1.0
var page_transition_from := "INDEX"
const PAGE_TRANSITION_SECONDS := 0.52
const PAGE_TRANSITION_STYLES := ["shutter", "corruption", "carousel"]
## The comparison is deliberately non-binding. Production continues to use the
## tested shutter until Greg chooses after seeing all three at equal timing.
var page_transition_style := "shutter"
## Which thing in the bag is under the hand. The CARRY page had no selection at
## all, which was fine when it was a table and is not now that it is objects.
var carry_index := 0
## A radio lead requires a deliberate continuous hold. Page visibility is not
## input: merely looking at RADIO must never finish a lock by itself.
var radio_lock_held := false
var raised := 0.0
var is_open := false
var elapsed := 0.0
## C1.6 `v2`. "Raised at one angle in one hand, every time." `_device_rect`
## used to rise dead-centre — a menu appearing, not an object somebody is
## holding. One fixed offset, eased in with `raised` itself rather than a
## separate timer, so the same hand brings it up to the same place every
## time: no per-raise randomness, no drift.
const HELD_OFFSET_X := 0.045
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
## C1.7 `v2`. "It can be dropped, and it can be taken off you." Reloaded on
## every `open_device()` the same as `condition`/`battery` already are, so a
## device lost in one scene stays lost the next time this one loads — there
## is no second flag anywhere else that could disagree with this one.
var possessed := true

## AS1.3. A real resource, not a torch that never runs out. Full charge is
## about eight real minutes of continuously holding it up — long enough that
## raising it to see is a genuine decision (AS1.2), short enough that a run
## with the device up for most of a fight actually costs something. Recharges
## only while pocketed, and roughly four times slower than it drains, so
## letting go is relief but not an instant refill.
var battery := 1.0
const BATTERY_DRAIN_PER_SECOND := 1.0 / 480.0
const BATTERY_RECHARGE_PER_SECOND := 1.0 / 1800.0
## C7.2. The satellite page drives the panel and world-facing emitter harder
## than the quiet document pages. It buys a wider readable pool at the cost of
## charge and a source that can be picked out from farther away.
const MAP_BATTERY_MULTIPLIER := 2.0
const MAP_LIGHT_MULTIPLIER := 1.3
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
var page_audio: Node

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
## A10.7. Kept so the world can be handed over later than `bind`. A generator
## that is not in the tree yet has no `World3D` to give, and the device is
## built before the region in at least one scene.
var _world_source: Node = null
var _device_rect := Rect2()
var _screen_rect := Rect2()
var _page_rect := Rect2()
var _content_rect := Rect2()

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
## C6.2. Leaning into a hosted page also braces the device for a deliberate
## wave. WASD still moves the body; its direction now carries through the
## wrist and beam as well, which lets the player put the light around an edge
## before their camera follows. A vector override keeps the physical gesture
## testable without synthesising keyboard state.
var wave := Vector2.ZERO
var wave_input_override: Variant = null
const WAVE_SCREEN_FRACTION := Vector2(0.055, 0.035)
const WAVE_RESPONSE := 5.0

## C9.1 `v9`. The rear is not another page. Holding O turns the same object
## through its edge; releasing it returns to the mirror. `turn_override` is the
## test seam used by the other held gestures in this file, not a second control
## path. Keeping the state here also means hosted panels, glass damage and the
## hand all agree about which face is actually toward the player.
var turn := 0.0
var turn_override: Variant = null
const TURN_KEY := KEY_O
var _turned_rect := Rect2()
var _tab_rects: Array[Rect2] = []

## C1.7 `v2`. Deliberately letting go, as its own key rather than folded onto
## G (which raises and lowers) or Escape (which just closes the panel without
## losing the device) — `open_device()`'s own `possessed` check is what makes
## either of those genuinely different verbs, so a drop needs a press of its
## own that survives the device already being closed. Edge-detected against
## `_drop_key_was_down` because `drop()` is a single event, not a state a held
## key should be free to fire every frame. `drop_key_override` follows
## `lean_override`'s own reason: a headless test cannot rely on
## `Input.is_key_pressed`.
const DROP_KEY := KEY_DELETE
const DROP_KEY_LABEL := "DELETE"
var drop_key_override: Variant = null
var _drop_key_was_down := false


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
	# The hosted INDEX is still the same instrument. Bubble its physical pin
	# action through the device so the scene's one Board owns the resulting card
	# whether INDEX was opened full-size or through the Black Mirror aperture.
	_index.pin_requested.connect(func(ref: String, kind: String, title: String):
		pin_requested.emit(ref, kind, title))
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
	page_audio = PAGE_AUDIO.new()
	page_audio.name = "PageTransitionAudio"
	add_child(page_audio)
	set_process(true)


## A10.7. The world the map looks down on, taken from whatever owns the region.
## Guarded rather than assumed: a generator that is not a `Node3D`, or not yet
## in the tree, simply does not produce one and the map stays a chart until it
## does.
func _attach_map_world() -> void:
	if _map == null or not _map.has_method("attach_world"):
		return
	var source := _world_source if _world_source != null else get_parent()
	if source is Node3D and source.is_inside_tree():
		_map.call("attach_world", (source as Node3D).get_world_3d())


## Handed the live world so the hosted panels and the radio read real state.
func bind(generator: Node, director: Node, contacts: Callable) -> void:
	_world_source = generator
	if _map.has_method("bind"):
		_map.bind(generator, director, contacts)
	# A10.7. The MAP page is the satellite, not a second drawing of the same
	# region. `LivingMap.attach_world` is what builds the downward camera, and
	# it is deliberately never called by the map itself — "the map never goes
	# looking for one". Nothing called it on this path, so reaching the map
	# through the device left `satellite` null, `_satellite_ready()` false, and
	# the black mirror showing the drawn chart on a dark plate while the
	# satellite worked perfectly well anywhere a scene wired it directly.
	_attach_map_world()
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
		# The first useful fact this device knows is where its owner just escaped
		# from. Start on MAP only for that real opening route; isolated UI tests
		# and old worlds with no facility record retain the historic INDEX start.
		if not WorldHistory.subject(FACILITY_TERRITORY.SUBJECT).is_empty():
			mode_index = MODES.find("MAP")
			displayed_mode_index = mode_index
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
	# C1.7 `v2`. A save from before this existed opens possessed — the honest
	# read of "nobody has ever lost this yet".
	possessed = bool(record.get("possessed", true))
	var remembered_mode := MODES.find(str(record.get("preferred_mode", current_mode())).to_upper())
	if remembered_mode >= 0:
		mode_index = remembered_mode
		displayed_mode_index = remembered_mode


func save_device() -> void:
	WorldHistory.update_subject(DEVICE_ID, {
		"serial": serial,
		"condition": snappedf(condition, 0.001),
		"battery": snappedf(battery, 0.001),
		"wear_log": wear_log.duplicate(),
		"impacts": impacts.duplicate(true),
		"possessed": possessed,
		"preferred_mode": current_mode(),
		"kind": "object",
	}, "device_changed")


## C1.7 `v2`. Losing the device is one real transition, not two — voluntarily
## setting it down and having it taken both end in the identical state
## (unraisable, closed, `possessed` false), so `drop()` and `confiscate()`
## are two names for whoever is calling this, not two mechanisms. Splitting
## the event type rather than the effect: the world should be able to tell a
## deliberate drop from a robbery apart later even though the player cannot
## use the device either way in the meantime. Returns the device's own
## identity (serial, condition, wear) — what a caller elsewhere (the world
## scene owns 3D space, not this file) needs to actually place a dropped
## unit in the world rather than just deleting the player's access to it.
func _lose_possession(event_type: String, details: Dictionary, player_act := false) -> Dictionary:
	if not possessed:
		return {"ok": false, "reason": "ALREADY NOT IN HAND"}
	# `drop()` already owns a wider wear transaction; confiscation enters here
	# directly. A nested batch makes both paths atomic without duplicating them.
	WorldHistory.begin_ledger_batch()
	close_device()
	possessed = false
	save_device()
	var payload := details.duplicate(true)
	payload["serial"] = serial
	if player_act:
		PLAYER_ACTION_LEDGER.record(event_type, payload)
	else:
		WorldHistory.record_event(event_type, payload)
	WorldHistory.commit_ledger_batch()
	return {"ok": true, "serial": serial, "condition": condition, "battery": battery, "wear_log": wear_log.duplicate(), "impacts": impacts.duplicate(true)}


func drop() -> Dictionary:
	# C10.8. A deliberate drop is not a free inventory toggle. The lower glass
	# takes the small, repeatable impact before possession leaves, so the exact
	# same persisted object is the one that lands damaged in the world.
	if not possessed:
		return {"ok": false, "reason": "ALREADY NOT IN HAND"}
	# Wear, possession, device persistence and the one player receipt are one
	# deliberate gesture even though condition and ownership both change.
	WorldHistory.begin_ledger_batch()
	take_wear(0.025, "deliberate drop", Vector2(0.52, 0.88))
	var result := _lose_possession("device_dropped", {}, true)
	WorldHistory.commit_ledger_batch()
	if bool(result.get("ok", false)):
		dropped.emit(result)
	return result


func confiscate(reason := "") -> Dictionary:
	return _lose_possession("device_taken", {"reason": reason})


## The other half — found again, bought back, or handed back by whoever took
## it. Wear travels with it either way: this is the same physical object
## coming back, not a fresh one replacing it.
func repossess(details: Dictionary = {}) -> void:
	if possessed:
		return
	WorldHistory.begin_ledger_batch()
	possessed = true
	save_device()
	var payload := details.duplicate(true)
	payload["serial"] = serial
	PLAYER_ACTION_LEDGER.record("device_repossessed", payload)
	WorldHistory.commit_ledger_batch()


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
	# C1.7 `v2`. A device that has been dropped or taken cannot be raised —
	# `load_device()` runs first specifically so this reads the real, current
	# answer rather than a stale one from before whatever took it happened.
	if not possessed:
		return
	is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_mode(current_mode())


func close_device() -> void:
	is_open = false
	radio_lock_held = false
	radio.release_lock()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# AS1.3. The natural checkpoint for a number that otherwise only changes a
	# little every frame — saving on every tick it drains would mean writing
	# the whole history file to disk sixty times a second for nothing.
	save_device()


## The labels painted along the phone's bottom edge are controls, not a legend.
## Hosted pages keep their own pointer handling inside the aperture; this only
## owns the physical tab rail around them.
func _gui_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if button.button_index == MOUSE_BUTTON_LEFT:
		var tab := tab_index_at(button.position)
		if button.pressed and tab >= 0:
			jump_to_mode(tab)
			accept_event()
		elif _content_rect.has_point(button.position) and displayed_mode() == "RADIO":
			radio_lock_held = button.pressed
			if not radio_lock_held:
				radio.release_lock()
			accept_event()
		elif button.pressed and _content_rect.has_point(button.position) and displayed_mode() == "CARRY":
			pin_selected_part()
			accept_event()
	elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var direction := -1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		match displayed_mode():
			"RADIO": radio.tune(float(direction) * 0.2)
			"CARRY": step_carry(direction)
			_: cycle_mode(direction)
		accept_event()


## Native phone pages own their own keys before the Hunt can interpret the
## same P as BOARD or the same Space as DODGE. Hosted pages keep handling their
## own events; this route exists only for controls drawn directly by this node.
func handle_input(event: InputEvent) -> bool:
	if not is_open or not (event is InputEventKey) or event.echo:
		return false
	var key := event as InputEventKey
	match displayed_mode():
		"RADIO":
			if key.keycode in [KEY_LEFT, KEY_RIGHT] and key.pressed:
				radio.tune(-0.2 if key.keycode == KEY_LEFT else 0.2)
				queue_redraw()
				return true
			if key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				radio_lock_held = key.pressed
				if not radio_lock_held:
					radio.release_lock()
				return true
		"CARRY":
			if key.pressed and key.keycode in [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN]:
				step_carry(-1 if key.keycode in [KEY_LEFT, KEY_UP] else 1)
				return true
			if key.pressed and key.keycode in [KEY_P, KEY_ENTER, KEY_KP_ENTER]:
				pin_selected_part()
				return true
	return false


func tab_index_at(local_position: Vector2) -> int:
	for index in _tab_rects.size():
		if _tab_rects[index].has_point(local_position):
			return index
	return -1


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


func displayed_mode() -> String:
	return MODES[displayed_mode_index]


func set_page_transition_style(style: String) -> bool:
	var candidate := style.to_lower()
	if not PAGE_TRANSITION_STYLES.has(candidate):
		return false
	page_transition_style = candidate
	return true


func page_transition_contract() -> Dictionary:
	return {
		"style": page_transition_style,
		"duration": PAGE_TRANSITION_SECONDS,
		"swap_at": 0.5,
		"keeps_fallback": page_transition_style == "shutter",
		"fully_occludes": true,
	}


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
	# Opening the page already physically present is reconciliation, not a page
	# change. This keeps loading and repossession immediate while every actual
	# app change travels through the shutter below.
	if found == displayed_mode_index and pending_mode_index < 0:
		_activate_mode(found)
		return
	page_transition_from = displayed_mode()
	pending_mode_index = found
	page_transition = 0.0
	var forward := posmod(found - displayed_mode_index, MODES.size())
	var backward := posmod(displayed_mode_index - found, MODES.size())
	page_transition_direction = 1.0 if forward <= backward else -1.0
	if page_audio != null and page_audio.has_method("play_transition"):
		page_audio.call("play_transition", page_transition_style)
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


func _activate_mode(index: int) -> void:
	if displayed_mode() == "RADIO" and MODES[clampi(index, 0, MODES.size() - 1)] != "RADIO":
		radio_lock_held = false
		radio.release_lock()
	displayed_mode_index = clampi(index, 0, MODES.size() - 1)
	var mode := displayed_mode()
	# WIRE is not a separate surface — it is the index already open on its own
	# page. Duplicating it would be the six-panel problem again in miniature.
	if mode == "WIRE" and "page" in _index:
		_index.set("page", 2)
	elif mode == "INDEX" and "page" in _index and int(_index.get("page")) == 2:
		_index.set("page", 0)
	# Both hosted panels gate their own drawing on an open flag, so entering a
	# mode has to open the panel as well as show it.
	if mode == "MAP" and _map.has_method("open_map"):
		# Cheap and idempotent: `attach_world` returns immediately once the
		# camera exists, so this is the retry for a device built before the
		# region it looks down on.
		_attach_map_world()
		_map.open_map()
	elif _map.has_method("close_map"):
		# A10.8. Nothing renders while the map is shut — which was true of the
		# map and not of the device, because leaving the page only ever set
		# `visible`. The satellite kept rendering behind the WIRE page.
		_map.close_map()
	if mode in ["INDEX", "WIRE"] and _index.has_method("open"):
		_index.open()
	if mode == "RITUAL":
		# A camera frame can outlive the version that first asked for it. Reconcile
		# here rather than in `_draw`, so opening a page cannot award evidence more
		# than once merely because it redraws at sixty frames per second.
		RITUAL_LEDGER.reconcile_album()
	mode_changed.emit(mode)


func _advance_page_transition(delta: float) -> void:
	if pending_mode_index < 0:
		page_transition = 1.0
		return
	var before := page_transition
	page_transition = minf(1.0, page_transition + maxf(delta, 0.0) / PAGE_TRANSITION_SECONDS)
	if before < 0.5 and page_transition >= 0.5:
		_activate_mode(pending_mode_index)
	if page_transition >= 1.0:
		pending_mode_index = -1


func page_transition_coverage() -> float:
	if pending_mode_index < 0:
		return 0.0
	if page_transition <= 0.5:
		return Motion.ease_out(page_transition * 2.0)
	return 1.0 - Motion.ease_out((page_transition - 0.5) * 2.0)


func page_contract(mode: String) -> Dictionary:
	var id := mode.to_upper()
	return {
		"mode": id,
		"role": str(PAGE_ROLES.get(id, "UNREGISTERED PAGE")),
		"action": str(PAGE_ACTIONS.get(id, "OPERATE")),
		"index": MODES.find(id) + 1,
		"count": MODES.size(),
	}


## Where the character is standing. Reception, coverage and which parts of the
## Wire exist are all read off this, per C5: connectivity is a property of place.
func stand_at(world_position: Vector2) -> void:
	radio.stand_at(world_position)
	signal_field.stand_at(world_position)
	var signal_reading: Dictionary = signal_field.reading()
	if "signal_grade" in _index:
		_index.set("signal_grade", int(signal_reading.get("grade", SignalField.NONE)))
	# I3.2. Which BrokenWeb sites are reachable is a property of exactly where
	# the player is standing, the same as signal itself.
	if "current_emitter_id" in _index:
		_index.set("current_emitter_id", str(signal_reading.get("id", "")))
	if _map != null and _map.has_method("set_satellite_available"):
		_map.call("set_satellite_available", int(signal_reading.get("grade", SignalField.NONE)) != SignalField.NONE, str(signal_reading.get("source", "")))


func _process(delta: float) -> void:
	elapsed += delta
	_advance_page_transition(delta)
	# C1.7 `v2`. Checked against `possessed` rather than `is_open` — a device
	# in your pocket is still yours to drop, the same as one in your hand.
	# Edge-detected so holding the key down cannot fire `drop()` every frame.
	var drop_key_down: bool = drop_key_override if drop_key_override != null else Input.is_key_pressed(DROP_KEY)
	if drop_key_down and not _drop_key_was_down and possessed:
		drop()
	_drop_key_was_down = drop_key_down
	# A6.6 v2. The panel keeps failing whether or not you are looking at it,
	# so a fault does not restart its cycle every time the device comes up.
	panel_clock += delta
	_drive_backlight(delta)
	var turn_key_held: bool = turn_override if turn_override != null else Input.is_key_pressed(TURN_KEY)
	turn = Motion.blend(turn, delta, Motion.PANEL, is_open and turn_key_held)
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
	var leanable := is_open and displayed_mode() in ["INDEX", "MAP", "WIRE"]
	var lean_key_held: bool = lean_override if lean_override != null else Input.is_key_pressed(LEAN_KEY)
	lean = Motion.blend(lean, delta, Motion.PANEL, leanable and lean_key_held)
	var wave_input := Vector2.ZERO
	if leanable and lean_key_held:
		wave_input = wave_input_override if wave_input_override != null else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wave_input = wave_input.limit_length(1.0)
	wave = wave.move_toward(wave_input, delta * WAVE_RESPONSE)
	var leaned_size := base_size * lerpf(1.0, LEAN_SCALE, lean)
	var device_size := Vector2(minf(leaned_size.x, size.x * 0.98), minf(leaned_size.y, size.y * 0.98))
	var resting := Vector2((size.x - device_size.x) * 0.5, size.y + 60.0)
	# C1.6 `v2`. Off-centre rather than dead middle — held to one side, the way
	# an arm actually brings a phone up in front of you rather than floating it
	# on the camera's own axis. A visual tilt (`HANDHELD_TILT`, unused for now)
	# was tried and reverted: `radial` — the selection wheel — is a child of
	# this same Control, added before this rect existed, and rotating `self`
	# would have dragged the wheel's own fixed screen-centre geometry along
	# with the phone's tilt. The offset alone needs none of that, since every
	# consumer (`_screen_rect`, `_clip`, `_overlay`) is positioned from this
	# rect explicitly rather than through the node's transform.
	var lifted := Vector2((size.x - device_size.x) * 0.5 + size.x * HELD_OFFSET_X, (size.y - device_size.y) * 0.5)
	lifted += Vector2(wave.x * size.x * WAVE_SCREEN_FRACTION.x, wave.y * size.y * WAVE_SCREEN_FRACTION.y)
	_device_rect = Rect2(resting.lerp(lifted, Motion.ease_out(raised)), device_size)
	# A horizontal turn preserves the object's centre while its visible width
	# collapses to an edge and opens on the other face. The tiny floor avoids a
	# zero-area draw at the exact halfway frame without pretending it vanished.
	var turned_width := _device_rect.size.x * maxf(0.035, absf(cos(turn * PI)))
	_turned_rect = Rect2(
		Vector2(_device_rect.get_center().x - turned_width * 0.5, _device_rect.position.y),
		Vector2(turned_width, _device_rect.size.y)
	)
	_screen_rect = Rect2(_turned_rect.position + Vector2(26, 62), _turned_rect.size - Vector2(52, 104))
	_page_rect = _aspect_fit(_screen_rect, PAGE_ASPECT)
	var chrome_top := clampf(_page_rect.size.y * 0.055, 24.0, 34.0)
	var chrome_bottom := clampf(_page_rect.size.y * 0.043, 20.0, 29.0)
	var chrome_side := clampf(_page_rect.size.x * 0.011, 8.0, 13.0)
	_content_rect = Rect2(
		_page_rect.position + Vector2(chrome_side, chrome_top),
		_page_rect.size - Vector2(chrome_side * 2.0, chrome_top + chrome_bottom)
	)
	_clip.position = _page_rect.position
	_clip.size = Vector2(maxf(_page_rect.size.x, 1.0), maxf(_page_rect.size.y, 1.0))
	var front_visible := not showing_back() and _screen_rect.size.x > 2.0
	_clip.visible = front_visible
	_overlay.position = Vector2.ZERO
	_overlay.size = size
	_overlay.visible = front_visible

	var mode := displayed_mode()
	var showing_index := mode == "INDEX" or mode == "WIRE"
	_index.visible = showing_index and front_visible
	_map.visible = mode == "MAP" and front_visible
	if showing_index and front_visible:
		_fit_into_aperture(_index)
		# The index normally owns the screen and draws its own cursor; inside the
		# device the chassis is the frame, so it is told not to chase the mouse.
		if "cursor_follows_mouse" in _index:
			_index.set("cursor_follows_mouse", false)
		if "show_cursor" in _index:
			_index.set("show_cursor", false)
	if _map.visible:
		_fit_into_aperture(_map)

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
	if mode == "RADIO" and radio_lock_held:
		var found := radio.hold(delta)
		if found != "":
			lead_found.emit(found)
	elif mode == "RADIO":
		radio.release_lock()
	_overlay.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if raised <= 0.001:
		return
	var alpha := clampf(raised, 0.0, 1.0)
	# C4.2 `v4`. The hand belongs to the held object, not to a camera lamp in
	# the world scene. Drawn behind the chassis so it grips something with
	# weight, and shaded from `screen_luminance()` so a dead or pocketed screen
	# cannot leave a mysteriously lit hand behind.
	_draw_holding_hand(_device_rect, alpha)
	if showing_back():
		_draw_back(_turned_rect, alpha)
		return
	_draw_chassis(_turned_rect, alpha)
	# I0.5. The screen is glass, not a lit panel. Painting SCREEN_BG opaque put
	# a green surface over the mirror and left the black showing only in the
	# bezel, which is a case with a screen in it — the thing this is not. The
	# tint is thin enough that the glass and the reader are still in there.
	BlackMirror.draw_glass(self, _screen_rect, alpha, elapsed)
	draw_rect(_screen_rect, SCREEN_BG * Color(1, 1, 1, 0.55 * alpha))
	BlackMirror.draw_reflection(self, _screen_rect, alpha, elapsed, 0.42)
	# C10.2. One night-reading surface for every app. It is deliberately scoped
	# to the shared aperture rather than the whole mirror: the black side
	# gutters keep reflecting the holder while information rises out of its own
	# dim phosphor bed. Hosted and device-native pages both land above this.
	BlackMirror.draw_reading_bed(self, _page_rect, alpha, screen_luminance())
	# The modes with no hosted panel draw straight onto the screen.
	var mode := displayed_mode()
	if mode == "RADIO":
		_draw_radio(_content_rect, alpha)
	elif mode == "CARRY":
		_draw_carry(_content_rect, alpha)
	elif mode == "RITUAL":
		_draw_ritual(_content_rect, alpha)
	elif mode == "FIELD":
		_draw_resonance(_content_rect, alpha)


## C4.2 `v4`. One answer for how much light the glass itself is giving off.
## This is intentionally distinct from the world beam's energy: the hand is
## inches from the screen and reads its backlight directly, including panel
## sag, while the distant beam is a world-space approximation owned by its
## host scene.
func screen_luminance() -> float:
	# The glass stops lighting the palm as it rotates away. This is deliberately
	# a face angle, not a binary back/front switch, so the light leaves with the
	# physical movement instead of popping off at the halfway frame.
	var front_exposure := maxf(cos(turn * PI), 0.0)
	return clampf(raised * battery * backlight * front_exposure, 0.0, 1.0)


## Public, read-only answers for hosts/tests. Neither exposes a second state:
## `turn` remains the one physical transition underneath both.
func showing_back() -> bool:
	return turn >= 0.5


func shell_wear() -> float:
	return 1.0 - clampf(condition, 0.0, 1.0)


func _draw_holding_hand(rect: Rect2, alpha: float) -> void:
	var scale := clampf(rect.size.x / 1128.0, 0.72, 1.36)
	var grip := Vector2(rect.position.x + 24.0 * scale, rect.end.y - 2.0 * scale)
	var light := screen_luminance()
	var skin := HAND_SKIN.lerp(SCREEN_SPILL, 0.16 * light)

	# A soft spill below the lower-left corner. It begins at the screen edge,
	# widens over the knuckles and dies before the wrist; layered translucent
	# shapes read as emitted light without turning the hand into a flat tint.
	for layer in range(4, 0, -1):
		var spread := float(layer) * 14.0 * scale
		var spill := PackedVector2Array([
			Vector2(_screen_rect.position.x + 7.0 * scale, _screen_rect.end.y - 18.0 * scale),
			Vector2(_screen_rect.position.x + 72.0 * scale, _screen_rect.end.y - 4.0 * scale),
			grip + Vector2(70.0 * scale + spread, 38.0 * scale + spread * 0.25),
			grip + Vector2(-52.0 * scale - spread, 28.0 * scale + spread * 0.35),
		])
		draw_colored_polygon(spill, SCREEN_SPILL * Color(1, 1, 1, light * alpha * (0.012 + 0.009 * float(5 - layer))))

	# Wrist and palm enter from below rather than materialising at the bezel.
	draw_colored_polygon(PackedVector2Array([
		grip + Vector2(-35, 8) * scale,
		grip + Vector2(59, 3) * scale,
		grip + Vector2(73, 82) * scale,
		grip + Vector2(-48, 82) * scale,
	]), HAND_SHADOW.lerp(skin, 0.62) * Color(1, 1, 1, alpha))
	draw_colored_polygon(_ellipse_points(grip, 67.0 * scale, 47.0 * scale, 20), skin * Color(1, 1, 1, alpha))
	draw_arc(grip + Vector2(-4, 4) * scale, 31.0 * scale, 0.1, 2.0, 12, HAND_SHADOW * Color(1, 1, 1, 0.5 * alpha), maxf(1.0, 1.5 * scale))
	draw_arc(grip + Vector2(-3, 0) * scale, 34.0 * scale, 0.1, 1.2, 10, SCREEN_SPILL * Color(1, 1, 1, light * 0.34 * alpha), maxf(1.0, 1.2 * scale))

	# Four curled fingertips just outside the chassis edge. Their screen-facing
	# rims carry more green than the palm, which locates the source at the glass
	# above them rather than at an invisible lamp in front of the player.
	for finger in 4:
		var centre := Vector2(rect.position.x - (25.0 + float(finger % 2) * 3.0) * scale, rect.end.y - (43.0 + float(finger) * 29.0) * scale)
		var radius := (13.5 - float(finger) * 0.65) * scale
		var root_x := rect.position.x + (18.0 - float(finger) * 2.0) * scale
		var finger_shape := PackedVector2Array([
			centre + Vector2(0, -radius), Vector2(root_x, centre.y - radius * 0.72),
			Vector2(root_x, centre.y + radius * 0.68), centre + Vector2(0, radius),
		])
		draw_colored_polygon(finger_shape, skin.darkened(0.08) * Color(1, 1, 1, alpha))
		draw_circle(centre, radius, HAND_SHADOW * Color(1, 1, 1, alpha))
		draw_circle(centre + Vector2(2.5, -1.0) * scale, radius * 0.79, skin * Color(1, 1, 1, alpha))
		draw_line(centre + Vector2(5.0, -radius * 0.48) * scale, Vector2(rect.position.x + 7.0 * scale, centre.y - radius * 0.3), SCREEN_SPILL * Color(1, 1, 1, light * 0.55 * alpha), maxf(1.0, 1.3 * scale))
		draw_line(centre + Vector2(-4.0, radius * 0.2) * scale, centre + Vector2(6.0, radius * 0.27) * scale, HAND_SHADOW * Color(1, 1, 1, 0.7 * alpha), maxf(1.0, scale))

	# Thumb laid across the lower corner, still behind the case; only the part
	# beyond the silhouette remains visible, which makes the overlap do the
	# holding instead of drawing an outline around it.
	var thumb := PackedVector2Array([
		grip + Vector2(-31, -30) * scale,
		grip + Vector2(72, -9) * scale,
		grip + Vector2(77, 9) * scale,
		grip + Vector2(-41, 0) * scale,
	])
	draw_colored_polygon(thumb, skin.lightened(0.04) * Color(1, 1, 1, alpha))
	draw_line(grip + Vector2(-18, -22) * scale, grip + Vector2(51, -8) * scale, SCREEN_SPILL * Color(1, 1, 1, light * 0.58 * alpha), maxf(1.0, 1.4 * scale))


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
	CellOutzType.draw_condensed(self, rect.position + Vector2(26, 46), "HOLD O: TURN OVER", 8.0, CASE_EDGE * Color(1, 1, 1, 0.72 * alpha), 0.7)
	# The jester, pressed small into the bezel. It is on the back of the case;
	# this is the edge of it showing round the side.
	BlackMirror.draw_jester(self, Vector2(rect.end.x - 40, rect.position.y + 34), 26.0, 0.5 * alpha, elapsed)
	_draw_tabs(rect, alpha)
	_draw_status(rect, alpha)
	# C1.9 `v3`. Cracks used to end here, drawn across the whole chassis rect —
	# which meant the case and bezel wore too, and "the device in your hand
	# looks new from the outside" was never true. They are drawn in
	# `_draw_damage()` now, scoped to `_screen_rect` alone and on `_overlay`
	# (the topmost layer, over hosted panels and all), so wear is legible only
	# on the glass you are actually reading through — never on the case itself.


## C9.1/C9.2 `v9`. The physical reverse of the mirror. This is intentionally
## not a UI page: no hosted Control, no glass, no status strip. What can be read
## here is stamped, wired or damaged into the casing itself.
func _draw_back(rect: Rect2, alpha: float) -> void:
	if rect.size.x < 90.0:
		# At the midpoint of the turn the device is its edge: ridges, battery lip,
		# and nothing readable. This keeps the transition physical at its thinnest.
		draw_rect(rect, Color("100c09") * Color(1, 1, 1, alpha))
		draw_line(Vector2(rect.position.x + rect.size.x * 0.25, rect.position.y + 18), Vector2(rect.position.x + rect.size.x * 0.25, rect.end.y - 18), CASE_EDGE * Color(1, 1, 1, alpha), 2.0)
		draw_line(Vector2(rect.end.x - rect.size.x * 0.22, rect.position.y + 70), Vector2(rect.end.x - rect.size.x * 0.22, rect.end.y - 70), Color("271d15") * Color(1, 1, 1, alpha), 5.0)
		return

	var wear := shell_wear()
	var corner_bite := 12.0 + 24.0 * smoothstep(0.48, 0.9, wear)
	var shell := PackedVector2Array([
		rect.position + Vector2(13, 0),
		rect.position + Vector2(rect.size.x - corner_bite, 0),
		rect.position + Vector2(rect.size.x, corner_bite),
		rect.end - Vector2(0, 16),
		rect.end - Vector2(16, 0),
		rect.position + Vector2(14, rect.size.y),
		rect.position + Vector2(0, rect.size.y - 14),
		rect.position + Vector2(0, 13),
	])
	draw_colored_polygon(shell, CASE * Color(1, 1, 1, alpha))
	var outline := shell.duplicate()
	outline.append(shell[0])
	draw_polyline(outline, CASE_EDGE * Color(1, 1, 1, (0.78 - wear * 0.22) * alpha), 2.5)

	# A recessed service plate and the seam around it make the rear a made thing,
	# not a second black rectangle. Gaps spread along that seam as condition falls.
	var plate := rect.grow(-22.0)
	draw_rect(plate, Color("15110e") * Color(1, 1, 1, alpha))
	draw_rect(plate, CASE_EDGE * Color(1, 1, 1, 0.48 * alpha), false, 2.0)
	for gap in int(1.0 + wear * 7.0):
		var t := fposmod(float(serial % 97) * 0.013 + float(gap) * 0.173, 1.0)
		var gap_x := lerpf(plate.position.x + 16.0, plate.end.x - 52.0, t)
		draw_line(Vector2(gap_x, plate.position.y), Vector2(gap_x + 30.0 + wear * 22.0, plate.position.y), Color("050403") * Color(1, 1, 1, wear * alpha), 4.0)

	# The replacement cell protrudes from the back under three actual lashings.
	var pack := Rect2(rect.position + Vector2(rect.size.x * 0.73, 72), Vector2(rect.size.x * 0.18, rect.size.y - 144))
	draw_rect(pack.grow(5), Color("090706") * Color(1, 1, 1, 0.8 * alpha))
	draw_rect(pack, Color("2a2118") * Color(1, 1, 1, alpha))
	draw_rect(pack, CASE_EDGE * Color(1, 1, 1, 0.7 * alpha), false, 2.0)
	for tie in 3:
		var tie_y := pack.position.y + pack.size.y * (0.22 + float(tie) * 0.29)
		var failed := wear > 0.42 + float(tie) * 0.19
		if failed:
			draw_line(Vector2(pack.position.x - 18, tie_y), Vector2(pack.get_center().x - 8, tie_y + 9), Color("0b0806") * Color(1, 1, 1, alpha), 5.0)
			draw_line(Vector2(pack.get_center().x + 12, tie_y - 8), Vector2(pack.end.x + 14, tie_y), Color("0b0806") * Color(1, 1, 1, alpha), 5.0)
		else:
			draw_line(Vector2(pack.position.x - 18, tie_y), Vector2(pack.end.x + 14, tie_y), Color("0b0806") * Color(1, 1, 1, alpha), 5.0)

	# The mark Greg specified, large enough to own the rear. It is printed into
	# the shell, so unlike the reflection it does not sway when the device moves.
	var jester_at := Vector2(rect.position.x + rect.size.x * 0.39, rect.get_center().y - 16.0)
	BlackMirror.draw_jester(self, jester_at, minf(rect.size.x, rect.size.y) * 0.48, alpha, 0.0)
	CellOutzType.draw_stamped(self, Vector2(rect.position.x + 42, rect.end.y - 76), "WIZARDS ONLY FOOLZ", 17.0, AMBER * Color(1, 1, 1, alpha), ALERT * Color(1, 1, 1, 0.28 * alpha), 1.3)
	CellOutzType.draw_condensed(self, Vector2(rect.position.x + 44, rect.end.y - 43), "UNIT %06d // RELEASE O: MIRROR" % serial, 9.0, CASE_EDGE * Color(1, 1, 1, 0.82 * alpha), 0.8)

	# Condition is material here: abrasions take finish off, impact dents crease
	# the plate, the upper corner delaminates, and cable ties fail in thresholds.
	# No percentage is printed — the shell itself is the gauge.
	var rng := RandomNumberGenerator.new()
	rng.seed = serial * 31 + 9001
	for scratch in int(round(wear * 34.0)):
		var from := Vector2(rng.randf_range(plate.position.x, plate.end.x), rng.randf_range(plate.position.y, plate.end.y))
		var length := rng.randf_range(12.0, 54.0) * (0.55 + wear)
		var heading := rng.randf_range(-0.35, 0.35)
		draw_line(from, from + Vector2.from_angle(heading) * length, Color("a58b68") * Color(1, 1, 1, (0.12 + wear * 0.38) * alpha), rng.randf_range(0.7, 1.8))
	var dents := mini(impacts.size(), 4)
	if dents == 0:
		dents = int(floor(wear * 4.0))
	for dent in dents:
		var hit := Vector2(rng.randf_range(0.14, 0.66), rng.randf_range(0.16, 0.78))
		if dent < impacts.size():
			var recorded: Vector2 = impacts[dent].get("at", hit)
			hit = Vector2(1.0 - recorded.x, recorded.y)
		var at := rect.position + rect.size * hit
		var radius := 8.0 + wear * 18.0 + float(dent) * 2.0
		draw_arc(at, radius, 0.18, PI * 1.72, 18, Color("070504") * Color(1, 1, 1, (0.35 + wear * 0.4) * alpha), 3.0)
		draw_arc(at + Vector2(-2, -2), radius * 0.72, 0.35, PI * 1.45, 14, CASE_EDGE * Color(1, 1, 1, 0.3 * wear * alpha), 1.0)
	if wear > 0.55:
		var split := rect.position + Vector2(rect.size.x - corner_bite, 1)
		draw_polyline(PackedVector2Array([split, split + Vector2(-18, 19), split + Vector2(-7, 43), split + Vector2(-26, 61)]), Color("080504") * Color(1, 1, 1, alpha), 4.0)


func _draw_tabs(rect: Rect2, alpha: float) -> void:
	_tab_rects = tab_layout(rect)
	for index in MODES.size():
		var label: String = MODES[index]
		var tab_rect := _tab_rects[index]
		var x := tab_rect.position.x
		var y := tab_rect.position.y
		var width := tab_rect.size.x
		var active := index == displayed_mode_index
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


## Pure geometry companion to `_draw_tabs`, shared with hit-testing and tests.
## Keeping the painted rail and clickable rail derived from one calculation
## prevents the interaction from drifting away when a label changes width.
func tab_layout(rect: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var x := rect.position.x + 26.0
	var y := rect.position.y + rect.size.y - 34.0
	for label: String in MODES:
		var width := CellOutzType.width(label, 11.0, 1.0) + 26.0
		result.append(Rect2(Vector2(x, y), Vector2(width, 22.0)))
		x += width + 8.0
	return result


func _draw_status(rect: Rect2, alpha: float) -> void:
	# The date is device-owned registration, not content authored seven times.
	# It therefore remains in exactly the same place while every app changes
	# beneath it — the second narrow seam toward C10.1's one coherent GUI.
	CellOutzType.draw_condensed(self, rect.position + Vector2(190, 47), _calendar_header_text(), 8.0,
		MOSS * Color(1, 1, 1, 0.82 * alpha), 0.72)
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
	if displayed_mode() == "MAP":
		CellOutzType.draw_condensed(self, Vector2(rect.position.x + rect.size.x - 250, rect.position.y + rect.size.y - 30), "SAT DRAW x%.1f" % MAP_BATTERY_MULTIPLIER, 8.0, AMBER * Color(1, 1, 1, 0.9 * alpha), 0.72)
	for cell in 8:
		var lit := float(cell) / 8.0 < charge
		var bar := Rect2(Vector2(rect.position.x + rect.size.x - 150 + cell * 9.0, rect.position.y + rect.size.y - 30), Vector2(6, 11))
		draw_rect(bar, (tint if lit else CASE_EDGE * Color(1, 1, 1, 0.3)) * Color(1, 1, 1, alpha))


func _calendar_header_text() -> String:
	return "%s // %s" % [WorldClock.calendar_stamp(), WorldClock.stamp()]


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
		battery = clampf(battery - BATTERY_DRAIN_PER_SECOND * battery_draw_multiplier() * delta, 0.0, 1.0)
	else:
		battery = clampf(battery + BATTERY_RECHARGE_PER_SECOND * delta, 0.0, 1.0)


func battery_draw_multiplier() -> float:
	return MAP_BATTERY_MULTIPLIER if displayed_mode() == "MAP" else 1.0


func emitted_light_multiplier() -> float:
	return MAP_LIGHT_MULTIPLIER if displayed_mode() == "MAP" else 1.0


func wave_vector() -> Vector2:
	return wave


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
	return LAMP_RANGE * emitted_light_multiplier() if is_lit() else 0.0


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
	_draw_page_registration(alpha)
	_draw_page_chrome(alpha)
	_draw_page_transition(alpha)
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
	# C1.9 `v3`. The real crack system (C5.5/C5.6 — seeded from this device's
	# own `serial`, one fork cluster per recorded impact rather than the fixed
	# three lines above), moved here from `_draw_chassis` and rescoped to
	# `rect` — `_screen_rect`, not the whole device — so a battered handheld
	# still looks like an intact piece of hardware in your hand and only
	# gives up the damage once you are actually reading its screen. Drawn on
	# `_overlay`, the topmost layer, so it is genuinely over the hosted panel
	# in INDEX/MAP/WIRE too, not just over RADIO/CARRY/RITUAL's own content.
	var overall := clampf(1.0 - condition, 0.0, 1.0)
	if impacts.is_empty():
		if overall > 0.0:
			BlackMirror.draw_cracks(_overlay, rect, alpha, serial, overall)
	else:
		for index in impacts.size():
			var impact: Dictionary = impacts[index]
			var severity := clampf(overall * (0.5 + float(impact.get("severity", 0.05)) * 4.0), 0.0, 1.0)
			BlackMirror.draw_cracks(_overlay, rect, alpha, serial + index * 101, severity, impact.get("at", Vector2(0.74, 0.22)))
	# The glass itself, over everything.
	_overlay.draw_rect(rect, Color(0.55, 0.72, 0.62, 0.035 * alpha))


## The same calibration edge survives every app. It is deliberately lighter
## than the internal frames authored by Index and Map: this marks the device's
## aperture, while those marks still describe the document or chart inside it.
func _draw_page_registration(alpha: float) -> void:
	if _page_rect.size.x <= 2.0 or _page_rect.size.y <= 2.0:
		return
	var edge := CASE_EDGE * Color(1, 1, 1, 0.42 * alpha)
	_overlay.draw_rect(_page_rect, edge, false, 1.0)
	var corner := 13.0
	for at in [
		_page_rect.position,
		Vector2(_page_rect.end.x, _page_rect.position.y),
		_page_rect.end,
		Vector2(_page_rect.position.x, _page_rect.end.y),
	]:
		var inward_x := 1.0 if at.x == _page_rect.position.x else -1.0
		var inward_y := 1.0 if at.y == _page_rect.position.y else -1.0
		_overlay.draw_line(at, at + Vector2(corner * inward_x, 0), AMBER * Color(1, 1, 1, 0.62 * alpha), 1.4)
		_overlay.draw_line(at, at + Vector2(0, corner * inward_y), AMBER * Color(1, 1, 1, 0.62 * alpha), 1.4)


## I3.1 v3. One registration language around all seven apps. The content can
## remain a dossier, a satellite picture or an instrument; identity, position,
## navigation and the primary verb never move or change type treatment.
func _draw_page_chrome(alpha: float) -> void:
	if _page_rect.size.x <= 2.0 or _content_rect.size.x <= 2.0:
		return
	var contract := page_contract(displayed_mode())
	var top := Rect2(_page_rect.position, Vector2(_page_rect.size.x, _content_rect.position.y - _page_rect.position.y))
	var bottom := Rect2(Vector2(_page_rect.position.x, _content_rect.end.y), Vector2(_page_rect.size.x, _page_rect.end.y - _content_rect.end.y))
	_overlay.draw_rect(top, Color(0.012, 0.020, 0.017, 0.91 * alpha))
	_overlay.draw_rect(bottom, Color(0.010, 0.016, 0.014, 0.92 * alpha))
	_overlay.draw_line(Vector2(_page_rect.position.x, top.end.y), Vector2(_page_rect.end.x, top.end.y), MOSS * Color(1, 1, 1, 0.42 * alpha), 1.0)
	_overlay.draw_line(Vector2(_page_rect.position.x, bottom.position.y), Vector2(_page_rect.end.x, bottom.position.y), CASE_EDGE * Color(1, 1, 1, 0.52 * alpha), 1.0)
	var page_code := "%02d/%02d" % [int(contract.index), int(contract.count)]
	CellOutzType.draw_text(_overlay, top.position + Vector2(12, 7), str(contract.mode), 12.0, INK * Color(1, 1, 1, alpha), 1.0)
	CellOutzType.draw_condensed(_overlay, top.position + Vector2(118, 9), str(contract.role), 9.0, MOSS * Color(1, 1, 1, 0.82 * alpha), 0.72)
	var code_width := CellOutzType.width_condensed(page_code, 9.0, 0.72)
	CellOutzType.draw_condensed(_overlay, Vector2(top.end.x - code_width - 12, top.position.y + 9), page_code, 9.0, AMBER * Color(1, 1, 1, alpha), 0.72)
	CellOutzType.draw_condensed(_overlay, bottom.position + Vector2(12, 6), "TAB / NEXT PAGE", 8.0, CASE_EDGE * Color(1, 1, 1, 0.86 * alpha), 0.66)
	var action := str(contract.action)
	var action_width := CellOutzType.width_condensed(action, 8.0, 0.66)
	CellOutzType.draw_condensed(_overlay, Vector2(bottom.end.x - action_width - 12, bottom.position.y + 6), action, 8.0, AMBER * Color(1, 1, 1, 0.88 * alpha), 0.66)


## I3.2 v3. The old page changes only while the work surface is physically
## occluded. The shutter crosses in the direction of travel, closes fully,
## swaps the page behind itself, then leaves by the opposite edge.
func _draw_page_transition(alpha: float) -> void:
	match page_transition_style:
		"corruption":
			_draw_page_corruption(alpha)
		"carousel":
			_draw_page_carousel(alpha)
		_:
			_draw_page_shutter(alpha)


func _draw_page_shutter(alpha: float) -> void:
	var coverage := page_transition_coverage()
	if coverage <= 0.001 or _content_rect.size.x <= 2.0:
		return
	var width := _content_rect.size.x * coverage
	var entering := page_transition <= 0.5
	var from_right := page_transition_direction > 0.0
	var x := _content_rect.position.x
	if entering == from_right:
		x = _content_rect.end.x - width
	var shutter := Rect2(Vector2(x, _content_rect.position.y), Vector2(width, _content_rect.size.y))
	_overlay.draw_rect(shutter, Color(0.012, 0.009, 0.011, 0.985 * alpha))
	for rib in 7:
		var rib_x := shutter.position.x + shutter.size.x * float(rib + 1) / 8.0
		_overlay.draw_line(Vector2(rib_x, shutter.position.y), Vector2(rib_x, shutter.end.y), CASE_EDGE * Color(1, 1, 1, 0.18 * alpha), 1.0)
	var leading_x := shutter.position.x if entering == from_right else shutter.end.x
	_overlay.draw_line(Vector2(leading_x, shutter.position.y), Vector2(leading_x, shutter.end.y), AMBER * Color(1, 1, 1, 0.85 * alpha), 2.0)
	if coverage > 0.46:
		var destination: String = MODES[pending_mode_index] if pending_mode_index >= 0 else displayed_mode()
		var transit := "%s  >  %s" % [page_transition_from, destination]
		var transit_width := CellOutzType.width_condensed(transit, 10.0, 0.8)
		CellOutzType.draw_condensed(_overlay, shutter.get_center() + Vector2(-transit_width * 0.5, -4), transit, 10.0, AMBER * Color(1, 1, 1, coverage * alpha), 0.8)


## Comparison candidate 2. The page is lost in a bad decode that travels along
## the existing glass fractures. Rectangular packets are deliberately opaque at
## the midpoint: this remains physical concealment, not a cross-fade in costume.
func _draw_page_corruption(alpha: float) -> void:
	var coverage := page_transition_coverage()
	if coverage <= 0.001 or _content_rect.size.x <= 2.0:
		return
	var bands := 14
	for band in bands:
		var band_height := _content_rect.size.y / float(bands)
		var stagger := fmod(float((band * 7) % bands) / float(bands) * 0.19, 0.19)
		var local_coverage := clampf((coverage - stagger) / 0.81, 0.0, 1.0)
		var width := _content_rect.size.x * local_coverage
		var from_right := (band % 2 == 0) == (page_transition_direction > 0.0)
		var x := _content_rect.end.x - width if from_right else _content_rect.position.x
		var packet := Rect2(Vector2(x, _content_rect.position.y + band_height * band), Vector2(width, band_height + 1.0))
		_overlay.draw_rect(packet, Color(0.008, 0.014, 0.012, 0.99 * alpha))
		if width > 8.0:
			var tear_x := packet.position.x if from_right else packet.end.x
			_overlay.draw_line(Vector2(tear_x, packet.position.y), Vector2(tear_x, packet.end.y), (MOSS if band % 3 else ALERT) * Color(1, 1, 1, 0.75 * alpha), 1.0)
	# Fractures do the indexing; their intersections carry brief corrupt packets.
	for index in 7:
		var seed := float(index + 1)
		var origin := _content_rect.position + Vector2(_content_rect.size.x * fmod(seed * 0.173, 0.94), _content_rect.size.y * fmod(seed * 0.311, 0.92))
		var reach := _content_rect.size.x * coverage * (0.06 + fmod(seed * 0.07, 0.08))
		_overlay.draw_line(origin - Vector2(reach, reach * 0.22), origin + Vector2(reach, -reach * 0.31), INK * Color(1, 1, 1, 0.30 * coverage * alpha), 1.0)
	if coverage > 0.54:
		_draw_transition_label("DECODE FAILURE", coverage, alpha)


## Comparison candidate 3. A wheel of dark leaves rotates through the mirror.
## It is an occult mechanism rather than a menu flourish: indexed teeth, a
## centre bearing and a full physical cover before the page underneath changes.
func _draw_page_carousel(alpha: float) -> void:
	var coverage := page_transition_coverage()
	if coverage <= 0.001 or _content_rect.size.x <= 2.0:
		return
	var centre := _content_rect.get_center()
	var rotation := page_transition_direction * page_transition * TAU * 0.32
	# Eight leaves terminate on the aperture perimeter. At coverage 1 their fan
	# tiles the rectangle exactly, so the mechanism never spills over the glass
	# and never leaves a corner exposing the page during its midpoint swap.
	var rim := PackedVector2Array([
		_content_rect.position,
		Vector2(centre.x, _content_rect.position.y),
		Vector2(_content_rect.end.x, _content_rect.position.y),
		Vector2(_content_rect.end.x, centre.y),
		_content_rect.end,
		Vector2(centre.x, _content_rect.end.y),
		Vector2(_content_rect.position.x, _content_rect.end.y),
		Vector2(_content_rect.position.x, centre.y),
		_content_rect.position,
	])
	for leaf in 8:
		var outer_a := centre.lerp(rim[leaf], coverage)
		var outer_b := centre.lerp(rim[leaf + 1], coverage)
		_overlay.draw_colored_polygon(PackedVector2Array([centre, outer_a, outer_b]), Color(0.012, 0.009, 0.012, 0.99 * alpha))
		_overlay.draw_line(centre, outer_a, CASE_EDGE * Color(1, 1, 1, 0.40 * alpha), 1.4)
	for tooth in 12:
		var angle := -rotation + TAU * float(tooth) / 12.0
		var ellipse := Vector2(cos(angle) * _content_rect.size.x * 0.30, sin(angle) * _content_rect.size.y * 0.30) * coverage
		var at := centre + ellipse
		_overlay.draw_circle(at, maxf(1.0, _content_rect.size.y * coverage * 0.007), AMBER * Color(1, 1, 1, 0.68 * alpha))
	var hub_radius := maxf(3.0, _content_rect.size.y * coverage * 0.09)
	_overlay.draw_circle(centre, hub_radius, CASE * Color(1, 1, 1, alpha))
	_overlay.draw_arc(centre, maxf(4.0, hub_radius * 1.35), 0.0, TAU, 32, MOSS * Color(1, 1, 1, 0.72 * alpha), 1.4)
	if coverage > 0.54:
		_draw_transition_label("INDEXING MIRROR", coverage, alpha)


func _draw_transition_label(label: String, coverage: float, alpha: float) -> void:
	var destination: String = MODES[pending_mode_index] if pending_mode_index >= 0 else displayed_mode()
	var transit := "%s  //  %s  //  %s" % [page_transition_from, label, destination]
	var width := CellOutzType.width_condensed(transit, 10.0, 0.8)
	CellOutzType.draw_condensed(_overlay, _content_rect.get_center() + Vector2(-width * 0.5, -4), transit, 10.0, AMBER * Color(1, 1, 1, coverage * alpha), 0.8)


# --- the three modes that have no hosted panel ----------------------------

## E3. The ritual page is a camera assignment, not a menu of powers. The five
## positions around the aperture are real distinct bodies the current best
## photograph has proved; taking a photograph is the only way they fill.
func _draw_ritual(rect: Rect2, alpha: float) -> void:
	CellOutzType.draw_stamped(self, rect.position + Vector2(24, 22), "EVIDENCE RITE", 18.0, AMBER * Color(1, 1, 1, alpha), ALERT * Color(1, 1, 1, 0.3 * alpha), 1.4)
	var pending: Array[Dictionary] = RITUAL_LEDGER.outstanding()
	if pending.is_empty():
		var filed_at := rect.get_center() + Vector2(0, -8)
		draw_circle(filed_at, 58.0, MOSS * Color(1, 1, 1, 0.09 * alpha))
		draw_arc(filed_at, 58.0, 0.0, TAU, 40, MOSS * Color(1, 1, 1, alpha), 2.0)
		for tooth in 8:
			var tooth_angle := TAU * float(tooth) / 8.0
			var from := filed_at + Vector2.from_angle(tooth_angle) * 46.0
			var to := filed_at + Vector2.from_angle(tooth_angle) * 66.0
			draw_line(from, to, MOSS * Color(1, 1, 1, alpha), 2.0)
		var filed_label := "ALL FILED"
		var filed_width := CellOutzType.width(filed_label, 16.0, 1.0)
		CellOutzType.draw_text(self, filed_at + Vector2(-filed_width * 0.5, 86.0), filed_label, 16.0, MOSS * Color(1, 1, 1, alpha), 1.0)
		return

	var ritual: Dictionary = pending[0]
	var report: Dictionary = RITUAL_LEDGER.best_evidence(str(ritual.get("id", "")))
	var reports: Array = report.get("requirements", []) as Array
	var requirement_report: Dictionary = {}
	if not reports.is_empty() and reports[0] is Dictionary:
		requirement_report = reports[0]
	var requirement: Dictionary = requirement_report.get("requirement", {}) as Dictionary
	var matched: Array = requirement_report.get("matched", []) as Array
	var needed := maxi(1, int(requirement_report.get("needed", requirement.get("count", 1))))

	var title := str(ritual.get("label", "EVIDENCE"))
	CellOutzType.draw_text(self, rect.position + Vector2(24, 64), title, 22.0, INK * Color(1, 1, 1, alpha), 1.0)
	CellOutzType.draw_condensed(self, rect.position + Vector2(25, 96), str(ritual.get("instruction", "")), 11.0, CASE_EDGE * Color(1, 1, 1, alpha), 0.8)

	# A camera iris, then five head-shaped proof sockets. They are intentionally
	# a composition rather than a row: the page reads as a thing you bring proof
	# to, not as a checklist table.
	var centre := rect.get_center() + Vector2(-rect.size.x * 0.17, 24.0)
	var iris_radius := minf(86.0, rect.size.y * 0.21)
	draw_circle(centre, iris_radius, Color(0, 0, 0, 0.35 * alpha))
	draw_arc(centre, iris_radius, 0.0, TAU, 48, CASE_EDGE * Color(1, 1, 1, 0.65 * alpha), 2.0)
	draw_arc(centre, iris_radius * 0.54, 0.0, TAU, 40, AMBER * Color(1, 1, 1, 0.35 * alpha), 1.3)
	draw_circle(centre, iris_radius * 0.20, Color("030403") * Color(1, 1, 1, alpha))
	for slot in needed:
		var angle := -PI * 0.5 + TAU * float(slot) / float(needed)
		var at := centre + Vector2.from_angle(angle) * iris_radius * 1.46
		var filled := slot < matched.size()
		var tint: Color = ALERT if filled else CASE_EDGE
		draw_circle(at, 14.0, tint * Color(1, 1, 1, (0.42 if filled else 0.13) * alpha))
		draw_arc(at, 14.0, 0.0, TAU, 14, tint * Color(1, 1, 1, alpha), 1.5)
		# A skull-like proof marker, crossed out only once actual evidence has
		# satisfied the same-body camera check.
		draw_circle(at + Vector2(0, -2), 5.2, INK * Color(1, 1, 1, (0.65 if filled else 0.20) * alpha))
		draw_line(at + Vector2(-5, 7), at + Vector2(5, 7), INK * Color(1, 1, 1, (0.65 if filled else 0.20) * alpha), 2.0)
		if filled:
			draw_line(at + Vector2(-7, -7), at + Vector2(7, 7), ALERT * Color(1, 1, 1, alpha), 1.6)
			draw_line(at + Vector2(7, -7), at + Vector2(-7, 7), ALERT * Color(1, 1, 1, alpha), 1.6)

	var counter := "%02d / %02d" % [matched.size(), needed]
	var counter_width := CellOutzType.width(counter, 24.0, 1.0)
	CellOutzType.draw_text(self, centre + Vector2(-counter_width * 0.5, 8.0), counter, 24.0, (ALERT if matched.size() < needed else MOSS) * Color(1, 1, 1, alpha), 1.0)
	var proof_label := RITUAL_LEDGER.requirement_label(requirement)
	var proof_width := CellOutzType.width_condensed(proof_label, 10.0, 0.7)
	CellOutzType.draw_condensed(self, centre + Vector2(-proof_width * 0.5, iris_radius + 84.0), proof_label, 10.0, INK * Color(1, 1, 1, 0.72 * alpha), 0.7)
	CellOutzType.draw_condensed(self, Vector2(rect.position.x + 24, rect.end.y - 42), "N / RECORD EVIDENCE", 10.0, AMBER * Color(1, 1, 1, alpha), 0.8)


## AT0. The field page does not claim revelation.  It draws the one state
## payload that already joins practice, temporary access, provenance and harm,
## so a player can see what the device knows without a new occult currency.
func _draw_resonance(rect: Rect2, alpha: float) -> void:
	var readout := RESONANCE_READOUT.snapshot("player", "yesod")
	CellOutzType.draw_stamped(self, rect.position + Vector2(24, 22), "RESONANCE READOUT", 18.0, AMBER * Color(1, 1, 1, alpha), ALERT * Color(1, 1, 1, 0.3 * alpha), 1.4)
	if not bool(readout.get("ok", false)):
		CellOutzType.draw_text(self, rect.get_center() + Vector2(-94, 4), "NO SIGNAL", 16.0, ALERT * Color(1, 1, 1, alpha), 1.0)
		return

	var centre := rect.position + Vector2(rect.size.x * 0.31, rect.size.y * 0.53)
	var radius := minf(92.0, rect.size.y * 0.22)
	# The wheel is a readout, not an objective compass: four nested arcs only
	# light when the action is actually available at the current altitude.
	for ring in 4:
		var floor: Dictionary = (readout.get("floors", [])[ring] as Dictionary)
		var lit := bool(floor.get("available", false))
		var tint: Color = MOSS if lit else CASE_EDGE
		var ring_radius := radius - float(ring) * 17.0
		draw_arc(centre, ring_radius, -PI * 0.84, PI * 0.84, 36, tint * Color(1, 1, 1, (0.88 if lit else 0.36) * alpha), 2.4)
		var label := str(floor.get("action", "")).to_upper()
		CellOutzType.draw_condensed(self, centre + Vector2(-ring_radius - 28.0, -ring_radius * 0.55), label, 9.0, tint * Color(1, 1, 1, alpha), 0.7)
	draw_circle(centre, 14.0, Color("020503") * Color(1, 1, 1, alpha))
	draw_arc(centre, 14.0, 0.0, TAU, 20, AMBER * Color(1, 1, 1, alpha), 1.6)
	CellOutzType.draw_condensed(self, centre + Vector2(-22, 4), str(readout.get("plane_name", "YESOD")).to_upper(), 8.0, INK * Color(1, 1, 1, alpha), 0.55)

	var meditating := bool(readout.get("meditating", false))
	var state_label := "SITTING / STABLE" if meditating else "NO PRACTICE ACTIVE"
	CellOutzType.draw_text(self, rect.position + Vector2(rect.size.x * 0.56, 78), state_label, 13.0, (MOSS if meditating else CASE_EDGE) * Color(1, 1, 1, alpha), 1.0)
	var provenance: Dictionary = readout.get("provenance", {})
	var observed := int(provenance.get("OBSERVED", 0))
	var attributed := int(provenance.get("ATTRIBUTED", 0))
	CellOutzType.draw_condensed(self, rect.position + Vector2(rect.size.x * 0.56, 112), "OBSERVED  %02d" % observed, 11.0, MOSS * Color(1, 1, 1, alpha), 0.8)
	CellOutzType.draw_condensed(self, rect.position + Vector2(rect.size.x * 0.56, 134), "ATTRIBUTED %02d" % attributed, 11.0, AMBER * Color(1, 1, 1, alpha), 0.8)
	CellOutzType.draw_condensed(self, rect.position + Vector2(rect.size.x * 0.56, 156), "REPEATS ARE NOT PROOF", 9.0, CASE_EDGE * Color(1, 1, 1, alpha), 0.7)

	var consequence: Dictionary = readout.get("consequence", {})
	var posture := str(consequence.get("posture", "MIXED"))
	var posture_tint: Color = ALERT if posture == "HARM OUTRUNS REPAIR" else (MOSS if posture == "REPAIR HAS A TRACE" else AMBER)
	var box := Rect2(rect.position + Vector2(rect.size.x * 0.54, rect.size.y - 116), Vector2(rect.size.x * 0.40, 62))
	draw_rect(box, Color(0, 0, 0, 0.30 * alpha))
	draw_rect(box, posture_tint * Color(1, 1, 1, 0.7 * alpha), false, 1.2)
	CellOutzType.draw_condensed(self, box.position + Vector2(12, 14), posture, 10.0, posture_tint * Color(1, 1, 1, alpha), 0.75)
	CellOutzType.draw_condensed(self, box.position + Vector2(12, 36), str(consequence.get("question", "")), 8.0, INK * Color(1, 1, 1, alpha), 0.62)

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
	_draw_radio_spectrum(rect, alpha)
	CellOutzType.draw_condensed(self, rect.position + Vector2(24, 202), "WHEEL / LEFT RIGHT: TUNE    HOLD CLICK / SPACE: LOCK", 8.0, CASE_EDGE * Color(1, 1, 1, 0.72 * alpha), 0.62)

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


## Greg's own reference for this: pwnisher's "audio-reactive art" technique —
## a real spectrum reading driving a visual, not a fake pulse keyed to
## `strength` alone. Three bars, not one: a low, throat-heavy bed and a thin,
## noisy static reach this at completely different bands, and averaging them
## into a single number would read as the same flat pulse regardless of what
## is actually coming out of the set.
func _draw_radio_spectrum(rect: Rect2, alpha: float) -> void:
	var bands: Vector3 = radio_audio.spectrum_bands() if radio_audio != null and radio_audio.has_method("spectrum_bands") else Vector3.ZERO
	var origin := rect.position + Vector2(rect.size.x - 90, 26)
	var labels := ["LO", "MID", "HI"]
	var values := [bands.x, bands.y, bands.z]
	for index in 3:
		var x := origin.x + float(index) * 16.0
		var height := 26.0 * float(values[index])
		draw_rect(Rect2(Vector2(x, origin.y + 26.0 - height), Vector2(10, height)), MOSS * Color(1, 1, 1, (0.4 + 0.6 * float(values[index])) * alpha))
		draw_rect(Rect2(Vector2(x, origin.y), Vector2(10, 26.0)), CASE_EDGE * Color(1, 1, 1, 0.25 * alpha), false, 1.0)
		CellOutzType.draw_condensed(self, Vector2(x - 1, origin.y + 36.0), str(labels[index]), 7.0, INK * Color(1, 1, 1, 0.4 * alpha), 0.6)


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
	CellOutzType.draw_condensed(self, rect.position + Vector2(24, 70), "WHEEL / ARROWS: SELECT    CLICK / P: PIN TO BOARD", 8.0, CASE_EDGE * Color(1, 1, 1, 0.72 * alpha), 0.62)

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
			var existing_index: int = seen[key]
			var existing_group: Dictionary = groups[existing_index]
			existing_group["count"] = int(existing_group["count"]) + 1
			existing_group["mass"] = float(existing_group["mass"]) + float(item.get("mass", 0.5))
			# The group is as stale as its freshest member is not.
			existing_group["fresh"] = minf(float(existing_group["fresh"]), carry.freshness(item))
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
		@warning_ignore("integer_division")
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


## Sized and scaled, not squashed.
##
## Both hosted panels were being handed `_clip.size` as their own size, which
## meant the World Index laid itself out for a 1074x515 letterbox using
## measurements authored against a 1280x720 screen. Widths mostly survived that;
## heights did not, which is why the file page's body text ran straight through
## the footer strip and the bottom of the plate was cut off by the aperture.
##
## The panel is given the size it was designed for — the viewport's, so the
## hosted panel and the fullscreen one are the *same* layout rather than two
## that have to be kept in agreement — and then scaled down to fit inside the
## aperture, letterboxed on whichever axis has room left over. A screen you are
## holding at arm's length should read as the same document, smaller. It should
## not read as the same document with its margins eaten.
func _fit_into_aperture(panel: Control) -> void:
	var design := get_viewport_rect().size
	if design.x <= 1.0 or design.y <= 1.0:
		design = Vector2(1280, 720)
	# Hosted pages are explicitly sized and scaled below. Their own fullscreen
	# ready paths leave stretch anchors behind, which made every assignment emit
	# a layout warning even though the final pixels happened to fit.
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = design
	# I3.1 v3. The header/footer are device-owned. Hosted pages receive the same
	# remaining work surface as native ones instead of painting underneath the
	# common registration and becoming seven subtly different layouts again.
	var available := _content_rect.size
	var local_origin := _content_rect.position - _page_rect.position
	var fit := minf(available.x / design.x, available.y / design.y)
	panel.scale = Vector2(fit, fit)
	panel.position = local_origin + (available - design * fit) * 0.5


static func _aspect_fit(outer: Rect2, aspect: float) -> Rect2:
	if outer.size.x <= 0.0 or outer.size.y <= 0.0 or aspect <= 0.0:
		return Rect2(outer.position, Vector2.ZERO)
	var fitted := outer.size
	if fitted.x / fitted.y > aspect:
		fitted.x = fitted.y * aspect
	else:
		fitted.y = fitted.x / aspect
	return Rect2(outer.position + (outer.size - fitted) * 0.5, fitted)
