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
	# The same rule, pointed at the one thing CHARACTER cannot enumerate: itself.
	# llama3.2 introduced itself as "Dr. Thompson" the second time it was ever
	# asked who it was, against an identity line that says *unnamed*. A name is
	# perfectly well-formed JSON with a legal intent and a legal tone, so
	# NPCDialogueContract passes it through exactly as it should -- the contract
	# checks shape, not truth. Nothing downstream can catch this, so it has to
	# be said here, once, for every NPC rather than remembered in each
	# character definition.
	lines.append("Everything true about you is below. Do not invent a name, a rank, a history or a relationship you have not been given -- if asked something you were not told, answer from what you do rather than from what you are.")
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
	var _idle_index := -1

	func _init(character_definition: Dictionary = {}) -> void:
		character = character_definition

	func respond(transcript: String, perception: Dictionary, npc_id: String) -> Dictionary:
		var said := transcript.to_lower()
		var armed := bool(perception.get("player_weapon_drawn", false))
		var disposition := NPCRelationship.disposition(npc_id)
		var familiar := float(NPCRelationship.state(npc_id).get("familiarity", 0.0))
		var demanding := _mentions(said, ["give me", "hand over", "your money", "valuables", "everything you", "wallet"])

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
		if _mentions(said, ["hello", "hi", "hey", "yo", "greetings", "you there", "excuse me", "morning", "evening"]):
			return _reply("greet", "warm" if disposition in ["friendly", "companion"] else "clinical",
				_greeting(disposition, familiar), {"type": "turn_to_face", "target": "player"}, "", {})
		if _mentions(said, ["who are you", "your name", "what are you", "what do i call you"]):
			return _reply("ask_question", "clinical",
				"Names are for people who expect to be looked up. Mine is not on your form.",
				{"type": "none"}, "They asked for my name.", {})
		if _mentions(said, ["where am i", "what is this place", "what place", "where is this"]):
			return _reply("answer_question", "clinical",
				"A growing floor. You were made here, which is a different thing from being born here.",
				{"type": "offer_information", "target": "player"}, "They did not know where they were.", {})
		if _mentions(said, ["why", "what did you do", "what have you done", "what am i"]):
			return _reply("answer_question", "clinical",
				"Because somebody paid for it. That is almost always the answer, and people rarely like it.",
				{"type": "none"}, "", {})
		if _mentions(said, ["let me out", "release me", "free me", "let me go"]):
			return _reply("refuse", "cold",
				"No. Not because I enjoy saying it. Because the door does not answer to me either.",
				{"type": "refuse"}, "They asked to be let out.", {})
		if _mentions(said, ["help", "please", "i need"]):
			return _reply("request_help", "neutral",
				"Ask me properly and I will tell you whether it is possible.",
				{"type": "consider_request", "target": "player"}, "", {})
		if _mentions(said, ["thank", "cheers", "appreciate"]):
			return _reply("smalltalk", "amused",
				"Don't. I have not done you a kindness, I have done you a procedure.",
				{"type": "none"}, "", {})
		if _mentions(said, ["fuck", "bastard", "idiot", "hate you", "shut up", "prick", "cunt"]):
			return _reply("insult", "cold",
				"Noted. It changes nothing, but I will write it down if it helps.",
				{"type": "none"}, "They swore at me.", {"anger": 0.2})
		if _mentions(said, ["kill you", "hurt you", "break your", "i'll end"]):
			return _reply("threaten", "clinical",
				"With what? I am asking sincerely. It matters to how this goes.",
				{"type": "none"}, "They threatened me without a weapon.", {"fear": 0.2})
		if _mentions(said, ["bye", "goodbye", "see you", "later", "leaving"]):
			return _reply("farewell", "neutral",
				"Mm. Someone will be along. It will not be me.",
				{"type": "end_conversation"}, "", {})
		if said.ends_with("?"):
			return _reply("ask_question", "clinical",
				"That is a question I am allowed to hear and not required to answer.",
				{"type": "none"}, "", {})
		return _reply("smalltalk", "neutral", _idle(disposition), {"type": "none"}, "", {})

	## The catch-all used to be one line, and it presumed the player was
	## frightened -- so a player typing "hi" was told they were afraid, forever.
	## Rotated by familiarity so repetition reads as a man getting bored of you
	## rather than as a broken script.
	func _idle(disposition: String) -> String:
		var pool := [
			"Mm.",
			"You can keep talking. I am listening in the way that I listen.",
			"That is not an answer to anything I asked.",
			"You're frightened. That's useful information, but it isn't an argument.",
			"Interesting. Not useful, but interesting.",
			"I have done four hundred of these. You are not the strangest.",
		]
		if disposition in ["cowed", "hostile"]:
			pool = [
				"We are past the part where talking helps you.",
				"Say it again. Slower. I want to be sure I heard it.",
				"No.",
			]
		_idle_index = (_idle_index + 1) % pool.size()
		return str(pool[_idle_index])

	func _greeting(disposition: String, familiar: float) -> String:
		if disposition in ["friendly", "companion"]:
			return "Interesting. You remembered."
		if disposition in ["cowed", "hostile"]:
			return "You again."
		if familiar >= 12.0:
			return "Back already. Sit still, it makes this faster."
		return "You're awake, then. Come closer, I don't shout."

	## Word-boundary matching, not substring. The greeting list used to contain
	## "hi " with a trailing space to stop it firing inside "this" and "which",
	## which meant a player typing exactly "hi" never matched it at all and fell
	## through to the catch-all every time.
	func _mentions(text: String, needles: Array) -> bool:
		var padded := " " + text.replace(",", " ").replace(".", " ").replace("!", " ").replace("?", " ") + " "
		for needle in needles:
			if padded.contains(" " + str(needle) + " ") or padded.contains(" " + str(needle)):
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
