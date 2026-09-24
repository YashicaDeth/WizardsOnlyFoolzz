extends Node

## The people the story wrote, written down once.
##
## The Examiner was authored inside `npc_conversation_lab.gd`, so the only
## place in the game he could be talked to was a test scene. That is the same
## shape as every other gap this week: a finished system reachable from one
## room. He lives in `FacilityCharacters` now and the lab reads him from there,
## which is what stops the two versions of him drifting.
##
## The distinction worth pinning is authored against generated.
## `bone_yard_hunt._standing_character()` builds a person out of whatever
## `WorldHistory` knows about a roamer, which is right for a scavenger on the
## road and wrong for staff: an Examiner improvised out of a grudge score is
## not the Examiner.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func rules_of(character: Dictionary) -> String:
	return ", ".join(PackedStringArray(character.get("rules", []))).to_lower()


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("-- the examiner, wherever he is asked for --")
	var examiner := FacilityCharacters.examiner()
	check(str(examiner.get("name", "")) == "THE EXAMINER", "he is who he was in the lab")
	check(str(examiner.get("identity", "")).contains("unnamed"), "and still unnamed")
	# The rule that exists because llama3.2 called itself Dr. Thompson on the
	# second turn it was ever asked. A name is well-formed JSON, so the airlock
	# cannot catch it and only the prompt can.
	check(rules_of(examiner).contains("never given anyone your name"), "and still refuses to give a name")
	check(rules_of(examiner).contains("more precise rather than louder"), "and still gets quieter when angry")
	# Two calls must be the same man, or the lab and the world have drifted
	# again by a different route.
	check(FacilityCharacters.examiner() == examiner, "and he is the same man every time he is asked for")

	print("-- a guard is staff, not a monster --")
	var alone := FacilityCharacters.guard({"name": "HOLT"})
	check(str(alone.get("name", "")) == "HOLT", "a guard is whoever the record says")
	check(str(alone.get("identity", "")).contains("CellOutz facility guard"), "and is written as staff on a shift")
	# The load-bearing one: the player is about to be offered the chance to
	# surrender to this person, and somebody who is enjoying it has already
	# decided.
	check(rules_of(alone).contains("procedure first"), "who follows procedure before anything else")
	check(rules_of(alone).contains("not paid enough"), "and is not here for a cause")
	check(rules_of(alone).contains("on your own"), "a lone guard knows he is alone")
	var backed := FacilityCharacters.guard({"name": "HOLT"}, 3)
	check(not rules_of(backed).contains("on your own"), "and one with others does not")
	check(rules_of(backed).contains("not the one who has to be brave"), "he knows that too")
	check(int(backed.get("allies_nearby", 0)) == 3, "and the count reaches the prompt")

	print("-- and they answer to what has already happened --")
	var calm := FacilityCharacters.guard({"name": "HOLT"})
	var burned := FacilityCharacters.guard({"name": "HOLT", "grudge": 55})
	check(not rules_of(calm).contains("past talking"), "a guard nobody has shot at is still talking")
	check(rules_of(burned).contains("past talking"), "one who has been is nearly past it")

	print("-- the house register is everyone's, not one man's --")
	# These lived in the Examiner's own list, so nobody else could have them.
	for rule in FacilityCharacters.HOUSE_RULES:
		check(rules_of(examiner).contains(str(rule).to_lower()), "the examiner keeps the house rule: %s" % str(rule).left(34))
		check(rules_of(alone).contains(str(rule).to_lower()), "and so does a guard")

	print("-- only the written are answered as written --")
	check(FacilityCharacters.for_role({"role": "examiner"}).get("name", "") == "THE EXAMINER", "a subject filed as the examiner gets him")
	check(str(FacilityCharacters.for_role({"role": "guard", "name": "HOLT"}).get("identity", "")).contains("facility guard"), "one filed as a guard gets one")
	check(str(FacilityCharacters.for_role({"role": "sentinel", "name": "UNIT"}).get("identity", "")).contains("facility guard"), "a sentinel is a guard by another name")
	# Everybody else is generated from the record, and putting facility
	# dialogue in a scavenger's mouth would be worse than saying nothing.
	# `role` in this game is prose, not an enum. An exact match would never
	# have fired for anybody, so the authored guard would have been written and
	# unreachable -- which is the failure this whole week keeps turning up.
	check(str(FacilityCharacters.for_role({"role": "Facility guard", "name": "HOLT"}).get("identity", "")).contains("facility guard"), "a role written as prose still matches")
	check(str(FacilityCharacters.for_role({"role": "Sentinel relay operator"}).get("identity", "")).contains("facility guard"), "and so does one with the word buried in it")
	# And the other way: the roamers really are filed as "Yard salvage hand"
	# and "Haul foreman", and none of them is staff.
	check(FacilityCharacters.for_role({"role": "Yard salvage hand"}).is_empty(), "a yard salvage hand is not a guard")
	check(FacilityCharacters.for_role({"role": "Haul foreman"}).is_empty(), "and neither is a haul foreman")
	# "Yard Warden" is a real entry in `CastNames.ROLES` and is a scrap-yard
	# boss on the road, not CellOutz staff. "warden" was in the match list for
	# one commit and would have handed him facility dialogue every time one was
	# rolled.
	check(FacilityCharacters.for_role({"role": "Yard Warden"}).is_empty(), "and a yard warden is a road boss, not facility staff")
	check(FacilityCharacters.for_role({"role": "Pit Marshal"}).is_empty(), "nor is a pit marshal")
	check(FacilityCharacters.for_role({"role": "scavenger"}).is_empty(), "a scavenger is not answered as staff")
	check(FacilityCharacters.for_role({}).is_empty(), "and neither is somebody with no role at all")

	print("FACILITY_CHARACTERS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
