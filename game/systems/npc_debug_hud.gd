class_name NPCDebugHUD
extends Control

## AI NPC Communication & Relationship System, engineering requirements:
## "Add useful logging and a simple debug HUD showing transcript, intent,
## latency, relationship values and last validated action."
##
## All five, because between them they answer the only question that matters
## while tuning this: when the NPC said something odd, was it the brain, the
## validator, or the relationship? Showing the line alone cannot tell you.

const INK := Color("cfc2a4")
const HOT := Color("c4553a")
const MOSS := Color("7fbf95")
const DIM := Color(0.62, 0.58, 0.50)

var npc_id := ""
var transcript := ""
var intent := ""
var tone := ""
var latency_ms := 0
var last_action: Dictionary = {}
var thinking := false
var attending := false
var listening := false
var voice_status := "off"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func watch(component: NPCConversationComponent) -> void:
	npc_id = component.npc_id
	component.npc_thinking.connect(func(_id): thinking = true; queue_redraw())
	component.npc_speech_started.connect(func(_id, _text): thinking = false; queue_redraw())
	component.validated_action.connect(func(_id, result): last_action = result; queue_redraw())
	component.attention_changed.connect(func(_id, is_attending): attending = is_attending; queue_redraw())
	component.relationship_changed.connect(func(_id, _dimension, _old, _new): queue_redraw())


func note_turn(turn: Dictionary) -> void:
	transcript = str(turn.get("transcript", transcript))
	intent = str(turn.get("intent", ""))
	tone = str(turn.get("tone", ""))
	latency_ms = int(turn.get("latency_ms", 0))
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var y := 28.0
	_line(font, Vector2(24, y), "NPC  %s" % npc_id.to_upper(), 15, INK)
	y += 22.0

	var status := "IDLE"
	var status_tint := DIM
	if listening:
		status = "LISTENING  (release V to send)"
		status_tint = MOSS
	elif thinking:
		status = "THINKING"
		status_tint = HOT
	elif attending:
		status = "ATTENDING"
		status_tint = INK
	_line(font, Vector2(24, y), status, 13, status_tint)
	y += 18.0
	# Which input path is live, always. "Hold V does nothing" and "hold V is
	# listening and heard silence" look identical without it.
	var mic := "MIC  %s" % voice_status.to_upper()
	if voice_status in ["off", "missing_model", "no_python", "missing_listener"]:
		mic += "   (TYPED INPUT)"
	_line(font, Vector2(24, y), mic, 11, MOSS if voice_status in ["ready", "listening"] else DIM)
	y += 24.0

	if not transcript.is_empty():
		_line(font, Vector2(24, y), "HEARD    \"%s\"" % transcript, 13, INK)
		y += 20.0
	if not intent.is_empty():
		_line(font, Vector2(24, y), "INTENT   %s  //  TONE %s  //  %d ms" % [intent.to_upper(), tone.to_upper(), latency_ms], 13, DIM)
		y += 20.0

	if not last_action.is_empty():
		var requested := str(last_action.get("requested", "none"))
		var performed := str(last_action.get("action", "none"))
		var approved := bool(last_action.get("approved", false))
		# Requested and performed are drawn separately and always, even when
		# they agree. Collapsing them to one line when they match is how you
		# stop noticing the day they stop matching.
		_line(font, Vector2(24, y), "ASKED    %s" % requested.to_upper(), 13, DIM)
		y += 20.0
		_line(font, Vector2(24, y), "GODOT    %s%s" % [performed.to_upper(), "" if approved else "   (REFUSED)"], 13, MOSS if approved else HOT)
		y += 20.0
		var fact := str(last_action.get("fact", ""))
		if not fact.is_empty():
			_line(font, Vector2(24, y), "RESULT   %s" % fact, 12, DIM)
			y += 22.0

	y += 6.0
	_line(font, Vector2(24, y), "RELATIONSHIP  //  %s" % NPCRelationship.disposition(npc_id).to_upper(), 13, INK)
	y += 20.0
	var record := NPCRelationship.state(npc_id)
	for dimension in NPCRelationship.DIMENSIONS:
		var spec: Dictionary = NPCRelationship.DIMENSIONS[dimension]
		var value := float(record.get(dimension, 0.0))
		var low := float(spec.min)
		var high := float(spec.max)
		_line(font, Vector2(36, y), str(spec.label), 11, DIM)
		var bar := Rect2(Vector2(150, y - 9), Vector2(190, 9))
		draw_rect(bar, Color(0.10, 0.09, 0.08, 0.85))
		var span := maxf(0.001, high - low)
		var zero_x := bar.position.x + ((0.0 - low) / span) * bar.size.x
		var value_x := bar.position.x + ((value - low) / span) * bar.size.x
		var left := minf(zero_x, value_x)
		draw_rect(Rect2(Vector2(left, bar.position.y), Vector2(absf(value_x - zero_x), bar.size.y)), HOT if value < 0.0 else MOSS)
		# The zero mark matters: on a -100..100 axis an empty bar and a bar
		# sitting at true neutral look identical without it.
		draw_rect(Rect2(Vector2(zero_x - 1.0, bar.position.y - 2.0), Vector2(2.0, bar.size.y + 4.0)), DIM)
		_line(font, Vector2(352, y), "%+.0f" % value, 11, INK)
		y += 16.0

	if bool(record.get("companion_unlocked", false)):
		_line(font, Vector2(36, y + 4), "COMPANION UNLOCKED", 12, MOSS)


func _line(font: Font, at: Vector2, text: String, size: int, tint: Color) -> void:
	draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.75))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, tint)
