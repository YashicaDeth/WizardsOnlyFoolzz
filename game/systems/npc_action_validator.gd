class_name NPCActionValidator
extends RefCounted

## AI NPC Communication & Relationship System, section 5 and the MVP acceptance
## test's last line:
##
##   "NPC cannot invent inventory, grant nonexistent quests, teleport items, or
##    change world state merely because the language model says so."
##
## This is where that is enforced. The model returns a *requested* action. This
## decides what actually happens, from the NPC's real state and the real world,
## and returns a GAME_RESULT which is then fed back so the NPC's next sentence
## matches what happened rather than what it asked for.
##
## The vocabulary is a closed list. An action outside it is refused by default
## rather than passed through, so adding a capability is a deliberate edit here
## and never an emergent property of a model being persuasive.

## Every action an NPC is permitted to request, and what each one needs to be
## true before Godot will consider it. `consider_*` actions are requests for a
## ruling; the validator picks the outcome, not the model.
const ALLOWED := {
	"none": {},
	"turn_to_face": {},
	"consider_robbery_compliance": {"needs_threat": true},
	"consider_request": {},
	"offer_information": {},
	"refuse": {},
	"flee": {},
	"call_for_help": {},
	"attack": {"needs_threat": true},
	"end_conversation": {},
}

## Section 3: "High fear can produce temporary compliance without friendship."
const COMPLY_FEAR := 55.0
const FLEE_FEAR := 75.0
const FIGHT_RESENTMENT := 60.0


## `request` is the model's `requested_game_action`. `perception` is what Godot
## knows to be true right now -- never what the model claimed.
##
## Returns a GAME_RESULT: what was asked, what was permitted, what happened,
## and a short line of fact the dialogue layer can put back in the prompt.
static func validate(npc_id: String, request: Dictionary, perception: Dictionary) -> Dictionary:
	var asked := str(request.get("type", "none")).to_lower().strip_edges()
	var result := {
		"requested": asked,
		"approved": false,
		"action": "none",
		"reason": "",
		"relationship_event": "",
		"fact": "",
	}

	if asked.is_empty() or asked == "none":
		result["approved"] = true
		result["fact"] = "Nothing was done."
		return result

	if not ALLOWED.has(asked):
		# The important half of the spec's promise. An unknown action is not
		# attempted, not approximated, and not silently dropped -- it is
		# refused, recorded, and reported back to the model as a refusal.
		result["reason"] = "outside_action_vocabulary"
		result["fact"] = "Nothing happened. That is not something you can do."
		WorldHistory.record_event("npc_action_refused", {"npc": npc_id, "requested": asked})
		return result

	var rule: Dictionary = ALLOWED[asked]
	# Godot's own perception, not the model's account of it. A model insisting
	# the player is holding a gun does not make one exist.
	var threatened := bool(perception.get("player_weapon_drawn", false)) or bool(perception.get("recent_violence", false))
	if bool(rule.get("needs_threat", false)) and not threatened:
		result["reason"] = "no_threat_present"
		result["fact"] = "Nothing happened. There was no threat to respond to."
		WorldHistory.record_event("npc_action_refused", {"npc": npc_id, "requested": asked, "why": "no_threat"})
		return result

	var relationship := NPCRelationship.state(npc_id)
	match asked:
		"consider_robbery_compliance":
			return _rule_on_robbery(npc_id, relationship, perception, result)
		"attack":
			# Requested, still ruled on. A frightened NPC does not swing.
			if float(relationship["fear"]) >= FLEE_FEAR:
				result["approved"] = true
				result["action"] = "flee"
				result["relationship_event"] = "threatened_with_weapon"
				result["fact"] = "You were too frightened to fight. You ran."
				return result
			result["approved"] = true
			result["action"] = "attack"
			result["relationship_event"] = "threatened_with_weapon"
			result["fact"] = "You attacked."
			return result
		_:
			result["approved"] = true
			result["action"] = asked
			result["fact"] = "You did that."
			return result


## The acceptance test's fourth line: "Point a weapon and demand valuables. NPC
## receives the weapon/threat context, interprets the demand, and Godot chooses
## a legal response such as refuse, comply, flee, call for help, or attack."
##
## Interprets is the model's word. Chooses is this function's.
static func _rule_on_robbery(npc_id: String, relationship: Dictionary, perception: Dictionary, result: Dictionary) -> Dictionary:
	var fear := float(relationship["fear"])
	var resentment := float(relationship["resentment"])
	var help_nearby := int(perception.get("allies_nearby", 0)) > 0

	result["approved"] = true
	if help_nearby and fear < FLEE_FEAR:
		result["action"] = "call_for_help"
		result["relationship_event"] = "threatened_with_weapon"
		result["fact"] = "You did not hand anything over. You called out for help."
	elif fear >= FLEE_FEAR:
		result["action"] = "flee"
		result["relationship_event"] = "threatened_with_weapon"
		result["fact"] = "You did not hand anything over. You ran."
	elif fear >= COMPLY_FEAR:
		result["action"] = "comply"
		result["relationship_event"] = "robbed"
		result["fact"] = "You handed over what you were carrying."
	elif resentment >= FIGHT_RESENTMENT:
		result["action"] = "attack"
		result["relationship_event"] = "threatened_with_weapon"
		result["fact"] = "You did not hand anything over. You went for them."
	else:
		result["action"] = "refuse"
		result["relationship_event"] = "threatened_with_weapon"
		result["fact"] = "You refused. Nothing changed hands."
	return result


## Run the ruling and then actually apply it, which is the only place a
## validated action becomes world state. Returns the GAME_RESULT with the
## relationship change folded in, ready to go back into the next prompt.
static func execute(npc_id: String, request: Dictionary, perception: Dictionary) -> Dictionary:
	var result := validate(npc_id, request, perception)
	if result["approved"] and str(result["relationship_event"]) != "":
		result["relationship"] = NPCRelationship.apply_event(npc_id, str(result["relationship_event"]))
	WorldHistory.record_event("npc_action_validated", {
		"npc": npc_id,
		"requested": result["requested"],
		"action": result["action"],
		"approved": result["approved"],
	})
	return result
