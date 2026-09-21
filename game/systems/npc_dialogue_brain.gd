class_name NPCDialogueBrain
extends RefCounted

## AI NPC Communication & Relationship System, sections 2 and 7, plus the
## engineering requirement: "Include clear setup instructions and a mock mode
## so the scene runs without API credentials."
##
## Two things live here. `prompt_for()` builds the turn exactly as section 7
## lays it out -- stable character information kept separate from changing
## state -- and `MockBrain` answers it offline so the whole loop is playable
## and testable today, with no key, no network and no account.
##
## The mock is not a placeholder to be deleted. It is the fallback when the
## network is down or a request times out, and it is what the test suite runs
## against, because a suite that needs a paid API is a suite nobody runs.

const ENV_KEY := "ATG_DIALOGUE_API_KEY"


## Section 7. Identity and rules first, then perception, then relationship,
## then the few retrieved memories, then what was actually said, then the
## schema. "Never dump an unlimited transcript into every prompt."
static func prompt_for(character: Dictionary, perception: Dictionary, npc_id: String, transcript: String, memories: Array) -> String:
	var lines: Array[String] = []
	lines.append("SYSTEM: You are the dialogue brain for an NPC in a Godot game. Stay in character.")
	lines.append("Never invent authoritative game state. Never claim an action succeeded unless GAME_RESULT says it did.")
	lines.append("Return only the required structured response.")
	lines.append("")
	lines.append("CHARACTER: %s" % str(character.get("identity", "An unnamed person.")))
	if not str(character.get("voice", "")).is_empty():
		lines.append("VOICE: %s" % str(character.voice))
	for rule in character.get("rules", []):
		lines.append("RULE: %s" % str(rule))
	lines.append("")
	lines.append("CURRENT STATE: %s" % NPCRelationship.summary(npc_id))
	lines.append("PERCEPTION: %s" % _describe(perception))
	if not memories.is_empty():
		# Section 2: "Short conversational context plus selected durable facts."
		lines.append("RELEVANT MEMORY:")
		for memory in memories:
			lines.append("- %s" % str(memory))
	if perception.has("last_game_result"):
		# The feedback loop from section 5, without which an NPC narrates the
		# action it asked for rather than the one that happened.
		lines.append("GAME_RESULT: %s" % str(perception.last_game_result))
	lines.append("")
	lines.append("PLAYER SAID: \"%s\"" % transcript)
	lines.append("")
	lines.append(NPCDialogueContract.schema_prompt())
	return "\n".join(lines)


## Section 4: "The model should never be told hidden world facts the NPC is not
## allowed to know." So this renders only the perception keys an NPC could have
## come by honestly -- anything else in the dictionary is simply not described.
static func _describe(perception: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("the player is %.1f metres away" % float(perception.get("distance", 0.0)))
	if bool(perception.get("player_facing_npc", false)):
		parts.append("facing you")
	if not bool(perception.get("line_of_sight", true)):
		parts.append("out of sight")
	if bool(perception.get("player_weapon_drawn", false)):
		parts.append("holding a weapon openly")
	if bool(perception.get("recent_violence", false)):
		parts.append("there has just been violence here")
	var allies := int(perception.get("allies_nearby", 0))
	if allies > 0:
		parts.append("%d of your people are within earshot" % allies)
	if not str(perception.get("location", "")).is_empty():
		parts.append("you are in %s" % str(perception.location))
	return ", ".join(parts) + "."


static func has_credentials() -> bool:
	return not OS.get_environment(ENV_KEY).strip_edges().is_empty()


## Offline. Deterministic. Good enough to prove the loop and to keep the game
## running when a request fails.
##
## It is not pretending to be a language model -- it reads the transcript for
## the handful of things the acceptance test actually exercises, and answers in
## the right shape. Everything downstream of it is the real system.
class MockBrain extends RefCounted:
	var character: Dictionary = {}

	func _init(character_definition: Dictionary = {}) -> void:
		character = character_definition

	func respond(transcript: String, perception: Dictionary, npc_id: String) -> Dictionary:
		var said := transcript.to_lower()
		var armed := bool(perception.get("player_weapon_drawn", false))
		var disposition := NPCRelationship.disposition(npc_id)
		var demanding := _mentions(said, ["give me", "hand over", "your money", "valuables", "everything you"])

		if armed and demanding:
			return _reply("threaten_and_rob", "cold",
				"You've made a decision with that. Let's see whether it was the sensible one.",
				{"type": "consider_robbery_compliance", "target": "player"},
				"They pointed a weapon at me and demanded what I was carrying.",
				{"fear": 0.6, "anger": 0.4})
		if armed:
			return _reply("threaten", "clinical",
				"You can lower the weapon. Or you can discover why that would have been the sensible choice.",
				{"type": "none"}, "They drew a weapon on me.", {"fear": 0.45})
		if _mentions(said, ["hello", "hey", "hi ", "you there", "excuse me"]):
			var greeting := "Interesting. You remembered." if disposition in ["friendly", "companion"] else "You're awake, then. Come closer, I don't shout."
			return _reply("greet", "warm" if disposition == "friendly" else "clinical", greeting, {"type": "turn_to_face", "target": "player"}, "", {})
		if _mentions(said, ["help", "please", "need"]):
			return _reply("request_help", "neutral",
				"Ask me properly and I'll tell you whether it's possible.",
				{"type": "consider_request", "target": "player"}, "", {})
		if _mentions(said, ["who are you", "your name", "what are you"]):
			return _reply("ask_question", "clinical",
				"No. That's not what I asked you. Try again.", {"type": "none"}, "", {})
		return _reply("smalltalk", "neutral",
			"You're frightened. That's useful information, but it isn't an argument.",
			{"type": "none"}, "", {"fear": 0.2})

	func _mentions(text: String, needles: Array) -> bool:
		for needle in needles:
			if text.contains(str(needle)):
				return true
		return false

	## Built as a JSON string and handed back through the real parser rather
	## than returned as a Dictionary. The mock has to travel the same airlock as
	## a live model, or the parser is untested on the path that runs every day.
	func _reply(intent: String, tone: String, speech: String, action: Dictionary, memory: String, emotion: Dictionary) -> Dictionary:
		return NPCDialogueContract.parse(JSON.stringify({
			"addressed_to_npc": true,
			"intent": intent,
			"tone": tone,
			"speech": speech,
			"requested_game_action": action,
			"memory_candidate": memory,
			"emotion": emotion,
		}))
