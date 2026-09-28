class_name Surfacing
extends CanvasLayer

## Greg, 28 September: surfacing into the Hunt is the payoff of the first
## thirty minutes. Blinding daylight that your eyes adjust out of; the
## facility's hum cut to silence, then open air and wind; the title,
## WIZARDS ONLY FOOLS, over the first view of the world; a short card with the
## keys that matter now; then the run card (the Hunt's own, delayed to here).

const SIGHT_AUDIO := preload("res://systems/sight_audio.gd")
const WHITE_OUT := 2.6
const WIND_AT := 1.2
const TITLE_AT := 1.4
const TITLE_HOLD := 3.6
const KEYS_AT := 5.6
const KEYS_HOLD := 8.0
const BONE := Color("ead4ad")
const COPPER := Color("dc5827")
const KEYS := [
	["WASD", "MOVE"], ["LMB", "ATTACK"], ["RMB", "GUARD / AIM"], ["MMB", "HEAVY // HOLD: GUARD BREAK"],
	["Z", "LOCK ON"], ["K", "WIZARD EYES"], ["TAB", "INVENTORY"], ["F1", "EVERY KEY"],
]

var clock := 0.0
var run_summary: Dictionary = {}
var _sheet: Control
var _wind: AudioStreamPlayer
var _card_shown := false


func begin(summary: Dictionary) -> void:
	run_summary = summary
	layer = 65
	name = "Surfacing"
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.draw.connect(_draw_sheet)
	_wind = AudioStreamPlayer.new()
	_wind.stream = SIGHT_AUDIO.stream("wind")
	_wind.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_wind.volume_db = -40.0
	add_child(_wind)
	WorldHistory.record_event("surfaced", {"location": "hunt"})


func _process(delta: float) -> void:
	if _sheet == null:
		return
	clock += delta
	if clock >= WIND_AT:
		if not _wind.playing:
			_wind.play()
		_wind.volume_db = lerpf(-40.0, -12.0, clampf((clock - WIND_AT) / 2.5, 0.0, 1.0))
	if not _card_shown and clock >= KEYS_AT + KEYS_HOLD * 0.5 and not run_summary.is_empty():
		_card_shown = true
		var card := preload("res://systems/run_card.gd").new()
		get_parent().add_child(card)
		card.show_summary(run_summary)
	_sheet.queue_redraw()


func _draw_sheet() -> void:
	var view := _sheet.size
	# Blinding daylight, then your eyes adjust.
	var white := 1.0 - clampf(clock / WHITE_OUT, 0.0, 1.0)
	if white > 0.0:
		_sheet.draw_rect(Rect2(Vector2.ZERO, view), Color(1, 0.98, 0.93, pow(white, 0.6)))
	# The title over the first view of the world.
	var title := clampf((clock - TITLE_AT) / 0.8, 0.0, 1.0) * clampf((TITLE_AT + TITLE_HOLD - clock) / 0.8, 0.0, 1.0)
	if title > 0.0:
		CellOutzType.draw_stamped(_sheet, Vector2(view.x * 0.5 - 330.0, view.y * 0.38), "WIZARDS ONLY FOOLS", 42.0, Color(BONE, title), Color(0, 0, 0, 0.5 * title), 3.0)
	# The keys that matter out here, once.
	var keys := clampf((clock - KEYS_AT) / 0.4, 0.0, 1.0) * clampf((KEYS_AT + KEYS_HOLD - clock) / 0.6, 0.0, 1.0)
	if keys > 0.0:
		var at := Vector2(40.0, view.y * 0.3)
		_sheet.draw_rect(Rect2(at - Vector2(14, 28), Vector2(330, 34 + KEYS.size() * 24)), Color(0.02, 0.01, 0.01, 0.7 * keys))
		CellOutzType.draw_condensed(_sheet, at, "OUT HERE", 11.0, Color(COPPER, keys), 1.4)
		for index in KEYS.size():
			var y := at.y + 26.0 + index * 24.0
			CellOutzType.draw_condensed(_sheet, Vector2(at.x, y), str(KEYS[index][0]), 10.0, Color(COPPER, keys), 1.2)
			CellOutzType.draw_condensed(_sheet, Vector2(at.x + 70.0, y), str(KEYS[index][1]), 10.0, Color(BONE, 0.9 * keys), 1.0)
	if clock > KEYS_AT + KEYS_HOLD + 1.0 and (_card_shown or run_summary.is_empty()):
		set_process(false)
		_sheet.visible = false
