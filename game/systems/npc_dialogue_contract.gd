class_name NPCDialogueContract
extends RefCounted

## AI NPC Communication & Relationship System, section 5.
##
## "Require JSON or tool/function output. Free-form text alone is not
## sufficient." And from the engineering requirements: "Use typed/validated
## response parsing and robust fallbacks for malformed model output."
##
## So this is the airlock. Everything a language model says arrives here as an
## untrusted string and leaves as a known-shaped Dictionary or as a refusal.
## Nothing downstream ever parses model output itself.
##
## The failure this exists to prevent is not a crash. It is a malformed
## response being half-understood -- an NPC delivering a line while the intent
## field silently defaults to "attack".

const INTENTS := [
	"greet", "smalltalk", "ask_question", "answer_question", "request_help",
	"offer_help", "threaten", "threaten_and_rob", "insult", "apologise",
	"promise", "refuse", "warn", "farewell", "unclear",
]

const TONES := ["neutral", "warm", "cold", "hostile", "frightened", "amused", "clinical", "pleading"]

const MAX_SPEECH_CHARACTERS := 400
const MAX_MEMORY_CHARACTERS := 200


## The shape every caller downstream can rely on. A refusal is still this
## shape -- `ok` is the only field anyone has to check first.
static func blank() -> Dictionary:
	return {
		"ok": false,
		"reason": "",
		"addressed_to_npc": false,
		"intent": "unclear",
		"tone": "neutral",
		"speech": "",
		"requested_game_action": {},
		"memory_candidate": "",
		"emotion": {},
	}


## Parse one model response. `raw` is whatever came back over the wire.
##
## Never throws and never returns a partially-filled record: either every field
## is present and of the right type, or `ok` is false and `speech` carries a
## safe in-character fallback so the NPC still says something.
static func parse(raw: String) -> Dictionary:
	var result := blank()
	var body := _extract_object(raw)
	if body.is_empty():
		result["reason"] = "no_json_object"
		result["speech"] = fallback_speech()
		return result

	var parsed: Variant = JSON.parse_string(body)
	if not (parsed is Dictionary):
		result["reason"] = "not_an_object"
		result["speech"] = fallback_speech()
		return result

	var data: Dictionary = parsed
	# `speech` is the one field with no sane default. A response with no line
	# in it is not a response, whatever else it got right.
	var speech := str(data.get("speech", "")).strip_edges()
	if speech.is_empty():
		result["reason"] = "empty_speech"
		result["speech"] = fallback_speech()
		return result

	result["ok"] = true
	result["addressed_to_npc"] = bool(data.get("addressed_to_npc", true))
	# Out-of-vocabulary intents and tones fall back rather than passing through.
	# A model that invents "intent": "seduce_and_betray" gets "unclear", which
	# is honest, instead of a string nothing downstream has a branch for.
	result["intent"] = _one_of(str(data.get("intent", "unclear")), INTENTS, "unclear")
	result["tone"] = _one_of(str(data.get("tone", "neutral")), TONES, "neutral")
	result["speech"] = speech.substr(0, MAX_SPEECH_CHARACTERS)
	result["memory_candidate"] = str(data.get("memory_candidate", "")).strip_edges().substr(0, MAX_MEMORY_CHARACTERS)
	result["requested_game_action"] = data.get("requested_game_action", {}) if data.get("requested_game_action") is Dictionary else {}
	result["emotion"] = _clean_emotion(data.get("emotion", {}))
	return result


## Models wrap JSON in prose, in ```json fences, or in both. Rather than
## demanding they stop, take the first balanced object in the string -- counted
## rather than regexed, so a brace inside a quoted line of dialogue ("he said
## {nothing}") does not end the object early.
static func _extract_object(raw: String) -> String:
	var text := raw.strip_edges()
	var start := text.find("{")
	if start < 0:
		return ""
	var depth := 0
	var in_string := false
	var escaped := false
	for index in range(start, text.length()):
		var character := text[index]
		if escaped:
			escaped = false
			continue
		if character == "\\":
			escaped = true
			continue
		if character == "\"":
			in_string = not in_string
			continue
		if in_string:
			continue
		if character == "{":
			depth += 1
		elif character == "}":
			depth -= 1
			if depth == 0:
				return text.substr(start, index - start + 1)
	return ""


## Emotions are advisory -- they colour a performance, they never move a
## relationship, because section 3 reserves that for Godot's own delta table.
## Kept anyway so the debug HUD can show what the model thought it was doing.
static func _clean_emotion(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var out := {}
	for key in (value as Dictionary):
		var number: Variant = (value as Dictionary)[key]
		if number is float or number is int:
			out[str(key)] = clampf(float(number), 0.0, 1.0)
	return out


static func _one_of(value: String, allowed: Array, fallback: String) -> String:
	var lowered := value.to_lower().strip_edges()
	return lowered if allowed.has(lowered) else fallback


## What the NPC says when the brain fails. Deliberately in character and
## deliberately content-free: it must not promise anything, deny anything, or
## reveal that anything went wrong.
static func fallback_speech() -> String:
	return "..."


## The schema, as the model is shown it. Lives here next to the parser so the
## two cannot drift -- a prompt promising a field the parser drops is the
## quietest way for this system to rot.
static func schema_prompt() -> String:
	return """Return ONLY a JSON object of exactly this shape:
{
  "addressed_to_npc": true,
  "intent": one of [%s],
  "tone": one of [%s],
  "speech": "what you say aloud, in character, at most two sentences",
  "requested_game_action": {"type": "<action>", "target": "<id>"} or {},
  "memory_candidate": "one short durable fact worth remembering, or \\"\\"",
  "emotion": {"fear": 0.0, "anger": 0.0}
}
You may REQUEST a game action. You may never assume it happened.""" % [
		", ".join(INTENTS), ", ".join(TONES),
	]
