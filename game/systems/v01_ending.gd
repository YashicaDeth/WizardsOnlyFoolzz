extends CanvasLayer

## The v0.1 ending (Greg, 5 October: "blinding daylight, silence then wind,
## WIZARDS ONLY FOOLS title drop over the first view, then a 'to be continued'
## card"). Played once the heat elevator has brought you up and you walk out
## of the Surface Gate on the one facility map (facility.gd `_leave`).
##
## Lives on the tree root, not in a scene, so it survives the swap from the
## facility into the world: the gate whites out, the Hunt loads under the
## white, your eyes adjust out of it onto the first view of the world, the
## real logo (art/brand/wof_stacked.png through shaders/logo_fx.gdshader)
## burns in over it, then TO BE CONTINUED with the run card and back to the
## title menu. The Hunt's own Surfacing stands down while this runs
## (`ACTIVE_META`).
##
## Skipping: the first time on a save it plays through to the card; after
## that (or once the card is up) a confirm/cancel press goes to the menu.
##
## No class_name on purpose: facility.gd preloads it.

const SIGHT_AUDIO := preload("res://systems/sight_audio.gd")
const RUN_TIMER := preload("res://systems/run_timer.gd")
const RUN_CARD := preload("res://systems/run_card.gd")
const LOGO := preload("res://art/brand/wof_stacked.png")
const LOGO_FX := preload("res://shaders/logo_fx.gdshader")

## Root meta set while the ending runs; bone_yard_hunt.gd reads it.
const ACTIVE_META := "v01_ending_active"
const SEEN_EVENT := "v01_ending_seen"
const WORLD_SCENE := "res://bone_yard_hunt.tscn"
const MENU_SCENE := "res://country_town_menu.tscn"

## Beats, seconds from the gate.
## The white holds while the world loads behind it, then the eyes adjust.
const WORLD_AT := 0.2
const WHITE_HOLD := 0.9
const WHITE_ADJUST := 2.0
## The facility hum cuts dead at the gate; silence, then open air and wind.
const SILENCE := 1.6
const WIND_AT := 1.4
const TITLE_AT := 2.6
const TITLE_BURN := 1.1
const TITLE_HOLD := 4.2
const TITLE_FADE := 0.9
const CARD_AT := 9.0
const CARD_FADE_IN := 0.9
const CARD_HOLD := 8.0
const OUT_FADE := 0.8
const LONGEST_STEP := 1.0 / 20.0

const BONE := Color("ead4ad")
const COPPER := Color("dc5827")
const BLOOD := Color("a81716")
const DAY_WHITE := Color(1.0, 0.98, 0.93)

var clock := 0.0
var run_summary: Dictionary = {}
## True when this save has already seen the ending once.
var skippable := false
var world_shown := false
var menu_reached := false
var _sheet: Control
var _logo: TextureRect
var _logo_fx: ShaderMaterial
var _wind: AudioStreamPlayer
var _card: Node
var _master_db := 0.0
var _sound_back := false
var _recorded_surface := false
var _world_scene := WORLD_SCENE


## `world_scene` empty keeps the current scene as the view (gallery use).
func begin(world_scene: String = WORLD_SCENE) -> void:
	_world_scene = world_scene
	layer = 90
	name = "V01Ending"
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.set_meta(ACTIVE_META, true)
	skippable = WorldHistory.event_count(SEEN_EVENT) > 0
	WorldHistory.record_event(SEEN_EVENT, {"location": "surface_gate"})
	# The facility run ends at the gate; the card reads it at the end.
	run_summary = RUN_TIMER.finish()
	if run_summary.is_empty():
		run_summary = RUN_TIMER.summary() if not RUN_TIMER.record().is_empty() else {}
	# Blinding daylight needs day. The first surfacing already opens at 13:00;
	# a later one at night would white out into black.
	if WorldClock.daylight() < 0.6:
		WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	_master_db = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, -80.0)
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.draw.connect(_draw_sheet)
	_logo_fx = ShaderMaterial.new()
	_logo_fx.shader = LOGO_FX
	_logo_fx.set_shader_parameter("calm", 0.5)
	_logo_fx.set_shader_parameter("drips_on", 0.0)
	_logo_fx.set_shader_parameter("drip_flow", 1.0)
	_logo_fx.set_shader_parameter("drip_top", 0.62)
	_logo_fx.set_shader_parameter("reveal", 0.0)
	_logo = TextureRect.new()
	_logo.name = "TitleLogo"
	_logo.texture = LOGO
	_logo.material = _logo_fx
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.anchor_left = 0.2
	_logo.anchor_right = 0.8
	_logo.anchor_top = 0.16
	_logo.anchor_bottom = 0.52
	_logo.visible = false
	add_child(_logo)
	_wind = AudioStreamPlayer.new()
	_wind.stream = SIGHT_AUDIO.stream("wind")
	_wind.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_wind.volume_db = -40.0
	add_child(_wind)
	if _world_scene == "":
		world_shown = true


func _process(delta: float) -> void:
	if _sheet == null or menu_reached:
		return
	# The world load is one long frame; the white must not jump past it.
	clock += minf(delta, LONGEST_STEP)
	if not world_shown and clock >= WORLD_AT:
		world_shown = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(_world_scene)
	elif world_shown and not _recorded_surface and clock >= WORLD_AT + 0.2:
		# After the Hunt has read its first-surfacing state, not before.
		_recorded_surface = true
		WorldHistory.record_event("surfaced", {"location": "hunt"})
		if WorldHistory.event_count("title_drop_seen") == 0:
			WorldHistory.record_event("title_drop_seen", {"location": "surface_gate"})
	if _recorded_surface:
		# Every frame: the Hunt's own systems turn its HUD back on.
		_hide_world_hud()
	if clock >= WIND_AT:
		if not _wind.playing:
			_wind.play()
		_wind.volume_db = lerpf(-30.0, -8.0, clampf((clock - WIND_AT) / 1.8, 0.0, 1.0))
	if not _sound_back:
		var back := clampf((clock - SILENCE) / 1.4, 0.0, 1.0)
		AudioServer.set_bus_volume_db(0, lerpf(-80.0, _master_db, sqrt(back)))
		_sound_back = back >= 1.0
	# logo_fx writes COLOR itself, so modulate cannot fade it: it burns in
	# through `reveal` and burns back out the same way.
	var burn := clampf((clock - TITLE_AT) / TITLE_BURN, 0.0, 1.0)
	var off := clampf((TITLE_AT + TITLE_BURN + TITLE_HOLD + TITLE_FADE - clock) / TITLE_FADE, 0.0, 1.0)
	_logo_fx.set_shader_parameter("reveal", burn * off)
	_logo.visible = title_alpha() > 0.0
	if _card == null and clock >= CARD_AT + CARD_FADE_IN * 0.6 and not run_summary.is_empty():
		_card = RUN_CARD.new()
		_card.hold_seconds = CARD_HOLD
		_card.centred = true
		add_child(_card)
		_card.show_summary(run_summary)
		# show_summary sets its own layer; this card sits over the black.
		_card.layer = layer + 1
	if clock >= CARD_AT + CARD_FADE_IN + CARD_HOLD + OUT_FADE:
		go_to_menu()
		return
	_sheet.queue_redraw()


## 0..1, the logo over the world.
func title_alpha() -> float:
	var on := clampf((clock - TITLE_AT) / 0.35, 0.0, 1.0)
	var off := clampf((TITLE_AT + TITLE_BURN + TITLE_HOLD + TITLE_FADE - clock) / TITLE_FADE, 0.0, 1.0)
	return on * off


## 0..1, the day white-out.
func white_alpha() -> float:
	var adjust := clampf((clock - WHITE_HOLD) / WHITE_ADJUST, 0.0, 1.0)
	return pow(1.0 - adjust, 0.55)


## 0..1, the black under TO BE CONTINUED (and the fade out to the menu).
func card_alpha() -> float:
	return clampf((clock - CARD_AT) / CARD_FADE_IN, 0.0, 1.0)


func can_skip() -> bool:
	return skippable or clock >= CARD_AT


func _unhandled_input(event: InputEvent) -> void:
	if menu_reached or not can_skip():
		return
	var start_button := event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or start_button:
		get_viewport().set_input_as_handled()
		go_to_menu()


func go_to_menu() -> void:
	if menu_reached:
		return
	menu_reached = true
	_restore_sound()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().root.remove_meta(ACTIVE_META)
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
	queue_free()


## The Hunt's HUD (objective, vials, prompts) is not part of the first view.
func _hide_world_hud() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var hud := scene.get_node_or_null("HUD")
	if hud is CanvasLayer:
		hud.visible = false


func _draw_sheet() -> void:
	var view := _sheet.size
	var black := card_alpha()
	if black > 0.0:
		_sheet.draw_rect(Rect2(Vector2.ZERO, view), Color(0.012, 0.006, 0.008, black))
		var words := "TO BE CONTINUED"
		var cap := 34.0
		var width := CellOutzType.width(words, cap, 3.0)
		var text := clampf((clock - CARD_AT - CARD_FADE_IN * 0.4) / 0.8, 0.0, 1.0)
		CellOutzType.draw_stamped(_sheet, Vector2((view.x - width) * 0.5, view.y * 0.3), words, cap, Color(BONE, text), Color(BLOOD, 0.55 * text), 3.0)
		if can_skip() and text >= 1.0:
			var hint := "PRESS TO RETURN TO THE TITLE"
			var hint_width := CellOutzType.width_condensed(hint, 12.0, 1.6)
			CellOutzType.draw_condensed(_sheet, Vector2((view.x - hint_width) * 0.5, view.y - 56.0), hint, 12.0, Color(COPPER, 0.8 * text), 1.6)
	var white := white_alpha()
	if white > 0.0:
		_sheet.draw_rect(Rect2(Vector2.ZERO, view), Color(DAY_WHITE, white))
	var out := clampf((clock - CARD_AT - CARD_FADE_IN - CARD_HOLD) / OUT_FADE, 0.0, 1.0)
	if out > 0.0:
		_sheet.draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, out))


func _restore_sound() -> void:
	if not _sound_back:
		_sound_back = true
		AudioServer.set_bus_volume_db(0, _master_db)


## Never leave the game silent or the Hunt stood down if this goes away.
func _exit_tree() -> void:
	_restore_sound()
	if get_tree() != null and get_tree().root.has_meta(ACTIVE_META) and not menu_reached:
		get_tree().root.remove_meta(ACTIVE_META)
