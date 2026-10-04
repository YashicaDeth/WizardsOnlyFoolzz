class_name BrainScreen
extends Control

## The brain screen (Job 4, BUILD_PLAN v0.1 "Escape": "Brain screen: pick 2
## of 2 working disciplines"). After the intake, before the hack: the chip in
## your head shows what it can run, and you slot both. Third person switches
## on with it (the disciplines own a third-person camera; see
## `bone_yard_hunt.third_person_unlocked`).
##
## v0.1 has two disciplines, Brawler and Marksman (BUILD_PLAN.html). Greg has
## said the names are working titles (greg_direction_2026-10-04, "Names"), so
## they live in `DISCIPLINES` as data and nothing else spells them out.
##
## Pad first: stick or d-pad picks a card, Cross slots it, Circle takes the
## last one out, Cross again (or Options) locks the pair in once both slots
## are full. Keys and mouse do the same. Every hint is drawn from InputProfile
## so it names the device used last.
##
## OPEN (Greg): whether a mismatched pair means anything. Only two exist, so
## `PAIR_RULES` is empty by default: any pair is allowed and nothing changes.

signal finished(disciplines: Array)

const CellOutzType := preload("res://systems/celloutz_type.gd")

const BONE := Color("e6d4ac")
const BLOOD := Color("a8281a")
const COPPER := Color("b0552a")
const BLACK := Color("030504")

## Working titles (Greg may rename). `id` is what history records.
const DISCIPLINES := [
	{"id": "brawler", "name": "BRAWLER", "kit": "HEATED CLEAVER  //  SHOCK STAFF", "line": "HEAVY DIRECTIONAL SWINGS"},
	{"id": "marksman", "name": "MARKSMAN", "kit": "PISTOL  //  AIM DOWN SIGHTS", "line": "SLOW TIME AND TAKE THEM APART"},
]
const SLOTS := 2
## OPEN dial: {"brawler+marksman": {...}} once Greg decides pairs matter.
const PAIR_RULES := {}

## The headless route suites predate the screen; they skip it unless a test
## opts in, as with `BrainHack` and `TortureLoadIn`.
static var force_in_tests := false

var focus := 0
var slotted: Array[String] = []
var done := false
var clock := 0.0
var _hit_cards: Array[Rect2] = []
var _hit_lock := Rect2()


static func wanted() -> bool:
	return force_in_tests or OS.get_environment("ATG_TEST_MODE") != "1"


func _ready() -> void:
	name = "BrainScreen"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var profile := get_node_or_null("/root/InputProfile")
	if profile != null:
		profile.connect("device_changed", func(_family: String) -> void: queue_redraw())


func _process(delta: float) -> void:
	clock += delta
	queue_redraw()


func ready_to_lock() -> bool:
	return slotted.size() >= SLOTS


## Slot the focused card (or lock in when both slots are full).
func confirm() -> void:
	if done:
		return
	if ready_to_lock():
		lock_in()
		return
	var id := str(DISCIPLINES[focus].id)
	if not slotted.has(id):
		slotted.append(id)
		_cue(0.9)
	# The next empty card, so Cross Cross Cross is the whole screen.
	for index in DISCIPLINES.size():
		if not slotted.has(str(DISCIPLINES[index].id)):
			focus = index
			break


func back() -> void:
	if done or slotted.is_empty():
		return
	slotted.pop_back()
	_cue(0.6)


func move(step: int) -> void:
	focus = wrapi(focus + step, 0, DISCIPLINES.size())


func lock_in() -> void:
	if done or not ready_to_lock():
		return
	done = true
	var pair := "+".join(slotted)
	WorldHistory.amend_subject("player", {"disciplines": slotted.duplicate(), "camera": "third_person"})
	WorldHistory.record_event("brain_disciplines_slotted", {"disciplines": slotted.duplicate(), "pair": pair, "rule": PAIR_RULES.get(pair, {})})
	finished.emit(slotted.duplicate())
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_A:
				confirm()
			JOY_BUTTON_START:
				lock_in()
			JOY_BUTTON_B:
				back()
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER:
				move(-1)
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER:
				move(1)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_X and absf(motion.axis_value) > 0.6 and not _stick_held:
			_stick_held = true
			move(1 if motion.axis_value > 0.0 else -1)
		elif motion.axis == JOY_AXIS_LEFT_X and absf(motion.axis_value) < 0.3:
			_stick_held = false
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				confirm()
			KEY_F:
				lock_in()
			KEY_BACKSPACE, KEY_ESCAPE:
				back()
			KEY_LEFT, KEY_A:
				move(-1)
			KEY_RIGHT, KEY_D:
				move(1)
		get_viewport().set_input_as_handled()

var _stick_held := false


func _gui_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventMouseMotion:
		for index in _hit_cards.size():
			if _hit_cards[index].has_point(event.position):
				focus = index
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hit_lock.has_point(event.position):
			lock_in()
		else:
			for index in _hit_cards.size():
				if _hit_cards[index].has_point(event.position):
					focus = index
					confirm()
		accept_event()


func _glyph(action: String) -> String:
	var profile := get_node_or_null("/root/InputProfile")
	return str(profile.call("glyph", action)) if profile != null else action.to_upper()


## A short click from the chip, made here (no asset).
func _cue(pitch: float) -> void:
	var player := AudioStreamPlayer.new()
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_8_BITS
	wave.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(1400)
	for index in data.size():
		var t := float(index) / 22050.0
		data[index] = int(clampf(sin(t * TAU * 520.0 * pitch) * exp(-t * 40.0) * 90.0, -127, 127)) & 0xff
	wave.data = data
	player.stream = wave
	player.volume_db = -12.0
	if AudioServer.get_bus_index("SFX") != -1:
		player.bus = "SFX"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _draw() -> void:
	var view := size
	draw_rect(Rect2(Vector2.ZERO, view), Color(BLACK, 0.93))
	# Scanlines: it is a screen in your head, not a menu.
	for y in range(0, int(view.y), 4):
		draw_rect(Rect2(0, y, view.x, 1), Color(BLOOD, 0.05))
	var unit := minf(view.x / 1280.0, view.y / 720.0)
	var title_h := 34.0 * unit
	var title := "WETWIRE  //  DISCIPLINES"
	CellOutzType.draw_text(self, Vector2((view.x - CellOutzType.width(title, title_h, 2.0)) * 0.5, 70.0 * unit), title, title_h, BONE, 2.0)
	var sub := "SLOT %d OF %d" % [slotted.size(), SLOTS]
	var sub_h := 16.0 * unit
	CellOutzType.draw_condensed(self, Vector2((view.x - CellOutzType.width_condensed(sub, sub_h, 1.0)) * 0.5, 120.0 * unit), sub, sub_h, COPPER, 1.0)
	# Two big cards side by side.
	_hit_cards.clear()
	var card := Vector2(420.0, 300.0) * unit
	var gap := 60.0 * unit
	var left := (view.x - card.x * DISCIPLINES.size() - gap * (DISCIPLINES.size() - 1)) * 0.5
	var top := 180.0 * unit
	for index in DISCIPLINES.size():
		var entry: Dictionary = DISCIPLINES[index]
		var rect := Rect2(Vector2(left + index * (card.x + gap), top), card)
		_hit_cards.append(rect)
		var is_in := slotted.has(str(entry.id))
		var lit := index == focus
		var pulse := 0.5 + 0.5 * sin(clock * 5.0)
		draw_rect(rect, Color(BLOOD, 0.28 if is_in else 0.1))
		draw_rect(rect, Color(BONE if lit else COPPER, 0.6 + 0.4 * pulse if lit else 0.5), false, 6.0 * unit if lit else 2.0)
		var name_h := 42.0 * unit
		CellOutzType.draw_text(self, rect.position + Vector2(28, 40) * unit, str(entry.name), name_h, BONE if is_in or lit else Color(BONE, 0.6), 2.0)
		var kit_h := 14.0 * unit
		CellOutzType.draw_condensed(self, rect.position + Vector2(28, 130) * unit, str(entry.kit), kit_h, COPPER, 0.8)
		CellOutzType.draw_condensed(self, rect.position + Vector2(28, 170) * unit, str(entry.line), kit_h, Color(BONE, 0.8), 0.8)
		var state := "SLOTTED  %d" % (slotted.find(str(entry.id)) + 1) if is_in else "EMPTY"
		CellOutzType.draw_condensed(self, rect.position + Vector2(28, card.y / unit - 44) * unit, state, kit_h, BLOOD if is_in else Color(BONE, 0.4), 1.0)
	# The lock-in bar, big, under the cards.
	var bar := Rect2(Vector2(view.x * 0.5 - 260.0 * unit, top + card.y + 50.0 * unit), Vector2(520.0, 70.0) * unit)
	_hit_lock = bar
	var armed := ready_to_lock()
	draw_rect(bar, Color(BLOOD, 0.55 if armed else 0.12))
	draw_rect(bar, Color(BONE, 0.9 if armed else 0.3), false, 3.0)
	var lock_text := ("%s  LOCK IN  //  THIRD PERSON ON" % _glyph("ui_accept")) if armed else ("%s  SLOT   %s  TAKE OUT" % [_glyph("ui_accept"), _glyph("ui_cancel")])
	var lock_h := 18.0 * unit
	CellOutzType.draw_condensed(self, bar.position + Vector2((bar.size.x - CellOutzType.width_condensed(lock_text, lock_h, 1.0)) * 0.5, (bar.size.y - lock_h) * 0.5), lock_text, lock_h, BONE, 1.0)
