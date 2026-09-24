extends Node

## The MVP acceptance test from the AI NPC Communication & Relationship System
## spec, run as a suite rather than trusted.
##
## Its last and most important line is the one this file exists for:
##
##   "NPC cannot invent inventory, grant nonexistent quests, teleport items, or
##    change world state merely because the language model says so."
##
## Everything here runs offline against MockBrain, deliberately. A suite that
## needs API credentials is a suite that does not run.

const NPC := "examiner_unknown"

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject(NPC, {"name": "EXAMINER", "kind": "person"})

	print("-- section 3: the relationship is not one number --")
	check(NPCRelationship.DIMENSIONS.size() >= 7, "there are at least seven dimensions, not a single bar")
	check(NPCRelationship.disposition(NPC) == "stranger", "an NPC who has never met you regards you as a stranger")

	# Section 3: "threatening with a weapon raises fear and resentment".
	NPCRelationship.apply_event(NPC, "threatened_with_weapon")
	var after_threat := NPCRelationship.state(NPC)
	check(float(after_threat.fear) > 0.0 and float(after_threat.resentment) > 0.0, "a weapon threat raises fear and resentment")
	check(float(after_threat.trust) < 0.0, "...and costs trust at the same time")

	# The dimensions must be able to disagree, which is the entire reason the
	# spec refuses a single number: someone can fear you and be indebted to you.
	NPCRelationship.apply_event(NPC, "helped_loved_one")
	var mixed := NPCRelationship.state(NPC)
	check(float(mixed.fear) > 0.0 and float(mixed.affinity) > 0.0, "affection and fear can be held at once (fear %.0f, affinity %.0f)" % [float(mixed.fear), float(mixed.affinity)])

	check(float(NPCRelationship.state(NPC).familiarity) > 0.0, "familiarity accumulates across interactions")
	for _repeat in 40:
		NPCRelationship.apply_event(NPC, "conversed")
	check(float(NPCRelationship.state(NPC).familiarity) <= 100.0, "dimensions stay inside their bounds under repetition")

	# Section 3: "High fear can produce temporary compliance without
	# friendship" -- so fear has to beat affinity when reading the room.
	for _repeat in 4:
		NPCRelationship.apply_event(NPC, "threatened_with_weapon")
	check(NPCRelationship.disposition(NPC) == "cowed", "sustained fear reads as cowed, not as friendship")

	print("-- the legacy single number stays in step --")
	var derived := WorldHistory.relationship_strength(NPC, "player")
	check(derived == NPCRelationship.derived_strength(NPCRelationship.state(NPC)), "WorldHistory's existing strength is derived from the dimensions, not stored apart from them")
	check(derived < 0, "a feared and resented player reads negative on the old bar too (%d)" % derived)

	print("-- section 5: the model proposes, Godot disposes --")
	WorldHistory.clear_history()
	WorldHistory.register_subject(NPC, {"name": "EXAMINER", "kind": "person"})

	# An action outside the vocabulary must be refused rather than attempted.
	var invented := NPCActionValidator.execute(NPC, {"type": "grant_quest_legendary_sword"}, {})
	check(not bool(invented.approved), "an action outside the vocabulary is refused")
	check(str(invented.action) == "none", "...and nothing happens as a result of asking")
	check(str(invented.fact).contains("not something you can do"), "...and the model is told plainly that it failed")

	# And a real action still has to clear Godot's own perception, not the
	# model's account of it.
	var unearned := NPCActionValidator.execute(NPC, {"type": "attack"}, {"player_weapon_drawn": false})
	check(not bool(unearned.approved), "an attack with no threat present is refused")

	print("-- acceptance test 3: point a weapon and demand valuables --")
	var brain := NPCDialogueBrain.MockBrain.new({})
	var armed := {"distance": 2.0, "player_weapon_drawn": true, "allies_nearby": 0, "location": "the growing floor"}
	var reply := brain.respond("Hand over everything you're carrying.", armed, NPC)
	check(bool(reply.ok), "the brain returns a well-formed structured response")
	check(str(reply.intent) == "threaten_and_rob", "the demand is interpreted as a robbery")
	check(str(reply.requested_game_action.get("type", "")) == "consider_robbery_compliance", "the NPC requests a ruling rather than deciding the outcome")

	var ruling := NPCActionValidator.execute(NPC, reply.requested_game_action, armed)
	check(bool(ruling.approved), "Godot rules on the robbery")
	check(["refuse", "comply", "flee", "call_for_help", "attack"].has(str(ruling.action)), "the outcome is one of the legal responses (%s)" % str(ruling.action))
	check(not str(ruling.fact).is_empty(), "the result is stated as fact for the NPC's next line")

	# Section 4: allies present changes the ruling without the model's input.
	WorldHistory.clear_history()
	WorldHistory.register_subject(NPC, {"name": "EXAMINER", "kind": "person"})
	var guarded: Dictionary = armed.duplicate()
	guarded["allies_nearby"] = 3
	var with_help := NPCActionValidator.execute(NPC, {"type": "consider_robbery_compliance"}, guarded)
	check(str(with_help.action) == "call_for_help", "an NPC with people nearby calls out instead of complying")

	print("-- robust parsing of malformed model output --")
	check(not bool(NPCDialogueContract.parse("I'm sorry, I can't help with that.").ok), "prose with no JSON is refused")
	check(not bool(NPCDialogueContract.parse("{\"intent\": \"greet\"}").ok), "a response with no speech is refused")
	check(not bool(NPCDialogueContract.parse("{\"speech\": ").ok), "truncated JSON is refused rather than half-read")
	check(str(NPCDialogueContract.parse("garbage").speech) == NPCDialogueContract.fallback_speech(), "a refused response still gives the NPC something safe to say")

	var fenced := NPCDialogueContract.parse("```json\n{\"speech\": \"Interesting.\", \"intent\": \"greet\"}\n```")
	check(bool(fenced.ok) and str(fenced.speech) == "Interesting.", "JSON wrapped in prose or fences is still read")
	# The brace-counting parser exists for exactly this: a brace inside a spoken
	# line used to end the object early and truncate the response.
	var braced := NPCDialogueContract.parse("{\"speech\": \"He said {nothing} at all.\", \"intent\": \"smalltalk\"}")
	check(bool(braced.ok) and str(braced.speech).contains("{nothing}"), "a brace inside spoken dialogue does not truncate the object")
	var invented_intent := NPCDialogueContract.parse("{\"speech\": \"x\", \"intent\": \"seduce_and_betray\"}")
	check(str(invented_intent.intent) == "unclear", "an invented intent falls back to unclear rather than passing through")

	print("-- acceptance test 5: state survives leaving and returning --")
	WorldHistory.clear_history()
	WorldHistory.register_subject(NPC, {"name": "EXAMINER", "kind": "person"})
	NPCRelationship.apply_event(NPC, "helped_loved_one")
	NPCRelationship.apply_event(NPC, "kept_promise")
	var remembered := NPCRelationship.state(NPC)
	var reloaded := NPCRelationship.state(NPC)
	check(is_equal_approx(float(remembered.trust), float(reloaded.trust)), "the relationship reads back the same from world state")
	check(NPCRelationship.summary(NPC).contains("trust"), "the prompt summary names what actually moved")
	check(not NPCRelationship.summary(NPC).contains("fear"), "...and stays quiet about dimensions sitting at zero")

	print("NPC_RELATIONSHIP_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
