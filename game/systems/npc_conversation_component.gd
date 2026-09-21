class_name NPCConversationComponent
extends Node3D

## AI NPC Communication & Relationship System, sections 4 and 8.
##
## "Each NPC owns a lightweight conversation component referencing a reusable
## character definition resource." This is that component. It owns perception,
## attention and the turn loop; it owns no world state at all.
##
## The order is fixed and the whole design rests on it:
##
##   perceive -> brain proposes -> validator rules -> relationship moves ->
##   NPC speaks from what actually happened
##
## The NPC's line is produced *after* the ruling, never before, because section
## 5 is explicit: "The final world result is then fed back to the dialogue
## layer so the NPC's next sentence matches what actually happened."

signal npc_thinking(npc_id: String)
signal npc_speech_started(npc_id: String, text: String)
signal npc_speech_finished(npc_id: String)
signal relationship_changed(npc_id: String, dimension: String, old_value: float, new_value: float)
signal requested_action(npc_id: String, action: Dictionary)
signal validated_action(npc_id: String, result: Dictionary)
signal attention_changed(npc_id: String, attending: bool)

## Section 4: "within hearing radius, speech can be heard; within interaction
## radius and with attention acquired, the NPC may treat speech as directed at
## them."
@export var hearing_radius := 14.0
@export var interaction_radius := 4.5
@export var turn_speed := 4.0
## How long a line stays on screen. Stands in for TTS duration until there is
## real audio to wait on, so the beat is already the right shape.
@export var speech_seconds := 3.6

var npc_id := "npc"
var character: Dictionary = {}
var brain: RefCounted
var player: Node3D

var attending := false
var thinking := false
var last_turn: Dictionary = {}
var last_latency_ms := 0
var _speech_left := 0.0
var _bubble: Label3D
var _memories: Array[String] = []
## Section 2's output pipeline. Defaults to the best voice the machine has and
## degrades to subtitles-only where there is none, so no caller has to choose.
var voice: NPCSpeechOutput.Voice
## The floating 3D bubble is for overhearing an NPC across a room. While a full
## dialogue screen is open it is the same line twice, so the screen turns it off.
var suppress_bubble := false

const MAX_MEMORIES := 6


func configure(id: String, character_definition: Dictionary, target: Node3D, dialogue_brain: RefCounted = null) -> void:
	npc_id = id
	character = character_definition
	player = target
	# Defaults to the offline brain deliberately. A component that cannot think
	# without credentials is a component that cannot be playtested.
	brain = dialogue_brain if dialogue_brain != null else NPCDialogueBrain.MockBrain.new(character_definition)
	if voice == null:
		voice = NPCSpeechOutput.make(str(character_definition.get("voice_language", "en_AU")))
	if not WorldHistory.subject(npc_id).has("kind"):
		WorldHistory.register_subject(npc_id, {
			"name": str(character_definition.get("name", "UNKNOWN")),
			"kind": "person",
		})
	_build_bubble()


func _build_bubble() -> void:
	_bubble = Label3D.new()
	_bubble.name = "SubtitleBubble"
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	# Label3D sizes in world units via `pixel_size`, so a font_size that looks
	# sane in a 2D theme renders as a billboard several metres tall standing on
	# the NPC's head. Tuned against a capture rather than guessed: this reads at
	# conversational distance and leaves the debug HUD legible behind it.
	_bubble.font_size = 32
	_bubble.pixel_size = 0.0016
	_bubble.outline_size = 10
	_bubble.modulate = Color("e8dcc4")
	_bubble.outline_modulate = Color(0, 0, 0, 0.85)
	_bubble.width = 540.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.position = Vector3(0, 2.35, 0)
	_bubble.visible = false
	add_child(_bubble)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var distance := global_position.distance_to(player.global_position)
	var now_attending := distance <= interaction_radius
	if now_attending != attending:
		attending = now_attending
		attention_changed.emit(npc_id, attending)
	# Look-at, and only on the horizontal. A head that tips to follow a player
	# up a staircase reads as a turret rather than as a person.
	if attending:
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.001:
			var want := atan2(-to_player.x, -to_player.z)
			rotation.y = lerp_angle(rotation.y, want, clampf(delta * turn_speed, 0.0, 1.0))
	if _speech_left > 0.0:
		_speech_left = maxf(0.0, _speech_left - delta)
		if _speech_left <= 0.0:
			_bubble.visible = false
			npc_speech_finished.emit(npc_id)


## Section 4. Only what this NPC could plausibly have come by honestly -- the
## spec is firm that "the model should never be told hidden world facts the NPC
## is not allowed to know", and the cheapest way to honour that is for the
## hidden facts never to enter the dictionary in the first place.
func perceive() -> Dictionary:
	var distance := 999.0
	var facing := false
	if player != null and is_instance_valid(player):
		distance = global_position.distance_to(player.global_position)
		var to_npc := (global_position - player.global_position).normalized()
		facing = to_npc.dot(-player.global_transform.basis.z) > 0.55
	return {
		"distance": distance,
		"player_facing_npc": facing,
		"line_of_sight": true,
		"player_weapon_drawn": bool(WorldHistory.subject("player").get("weapon_drawn", false)),
		"recent_violence": WorldHistory.event_count("npc_action_validated") > 0 and _recent_violence(),
		"allies_nearby": int(character.get("allies_nearby", 0)),
		"location": str(character.get("location", "")),
	}


func _recent_violence() -> bool:
	for event in WorldHistory.recent_events(6):
		if str((event as Dictionary).get("type", "")).contains("attack"):
			return true
	return false


func can_hear(distance: float) -> bool:
	return distance <= hearing_radius


## One conversational turn. Everything the spec promises happens in here, in
## the order it promises it.
func hear(transcript: String) -> Dictionary:
	var started := Time.get_ticks_msec()
	var perception := perceive()
	if not can_hear(float(perception.distance)):
		return {"ok": false, "reason": "out_of_earshot"}

	thinking = true
	npc_thinking.emit(npc_id)

	var reply: Dictionary = brain.respond(transcript, perception, npc_id)
	# Section 4 again: inside hearing radius but outside interaction radius, an
	# NPC hears speech without assuming it was meant for them. Overhearing is
	# not being spoken to.
	var directed := bool(reply.get("addressed_to_npc", false)) and float(perception.distance) <= interaction_radius
	if not directed:
		thinking = false
		WorldHistory.record_event("npc_overheard", {"npc": npc_id, "said": transcript})
		return {"ok": false, "reason": "not_addressed", "reply": reply}

	var request: Dictionary = reply.get("requested_game_action", {})
	if not request.is_empty():
		requested_action.emit(npc_id, request)

	# The ruling comes before the line. This is the ordering the whole system
	# exists to guarantee.
	var before := NPCRelationship.state(npc_id)
	var result := NPCActionValidator.execute(npc_id, request, perception)
	validated_action.emit(npc_id, result)
	_emit_relationship_deltas(before)

	# Ordinary conversation still moves familiarity, or an NPC you have spoken
	# to fifty times is as much a stranger as one you have never met.
	if str(result.get("relationship_event", "")).is_empty():
		var talk_before := NPCRelationship.state(npc_id)
		NPCRelationship.apply_event(npc_id, "greeted" if str(reply.intent) == "greet" else "conversed")
		_emit_relationship_deltas(talk_before)

	_remember(str(reply.get("memory_candidate", "")))

	var spoken := str(reply.speech)
	# Section 5's feedback loop, made concrete: when the world refused or
	# replaced what the NPC asked for, it does not get to narrate the version it
	# wanted. It says its line and the truth is appended.
	if not bool(result.approved) or str(result.action) != str(result.requested):
		spoken = "%s %s" % [spoken, str(result.fact)]

	_say(spoken)
	thinking = false
	last_latency_ms = Time.get_ticks_msec() - started
	last_turn = {
		"transcript": transcript,
		"intent": str(reply.intent),
		"tone": str(reply.tone),
		"speech": spoken,
		"result": result,
		"latency_ms": last_latency_ms,
		"ok": true,
	}
	return last_turn


func _emit_relationship_deltas(before: Dictionary) -> void:
	var after := NPCRelationship.state(npc_id)
	for dimension in NPCRelationship.DIMENSIONS:
		var was := float(before.get(dimension, 0.0))
		var now := float(after.get(dimension, 0.0))
		if not is_equal_approx(was, now):
			relationship_changed.emit(npc_id, dimension, was, now)


## Section 2: "Short conversational context plus selected durable facts. Never
## dump an unlimited transcript into every prompt." So this is a small ring
## buffer of durable facts, not a transcript.
func _remember(fact: String) -> void:
	var trimmed := fact.strip_edges()
	if trimmed.is_empty() or _memories.has(trimmed):
		return
	_memories.append(trimmed)
	while _memories.size() > MAX_MEMORIES:
		_memories.pop_front()
	WorldHistory.record_event("npc_remembered", {"npc": npc_id, "fact": trimmed})


func memories() -> Array[String]:
	return _memories.duplicate()


func _say(text: String) -> void:
	_bubble.text = text
	_bubble.visible = not suppress_bubble
	# Hold the subtitle for as long as the line plausibly takes to say, rather
	# than a flat 3.6s: a four-word answer and a two-sentence one held for the
	# same beat is what makes a talking NPC feel like a slideshow.
	_speech_left = maxf(speech_seconds, float(text.length()) * 0.055)
	if voice != null:
		voice.speak(text)
	npc_speech_started.emit(npc_id, text)
