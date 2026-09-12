extends Node

## F4.2 / J3.1. LimboAI has sat in this project unused at 119MB. The question was
## whether to adopt it at all; the answer taken was to use it for the layer that
## does not exist rather than to port the encounter AI, which works.

const Tactics := preload("res://systems/rival_tactics.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("F4.2 - a rival who has fought you before fights you differently")
	_check(ClassDB.class_exists("BehaviorTree"), "LimboAI is actually registered")
	_check(ClassDB.class_exists("BTPlayer"), "and so is its runner")

	WorldHistory.clear_history()
	WorldHistory.register_subject("fresh", {"name": "Fresh", "kind": "person"})
	var green: Dictionary = Tactics.tactic_for("fresh")
	_check(str(green["id"]) == "press", "somebody who has never met you presses (%s)" % green["label"])

	# Beaten from the front, repeatedly, without losing anything.
	WorldHistory.register_subject("beaten", {"name": "Beaten", "kind": "person"})
	for _hit in 5:
		WorldHistory.record_event("melee_body_hit", {"subject": "beaten", "zone": "torso"})
	var wary: Dictionary = Tactics.tactic_for("beaten")
	_check(str(wary["id"]) == "circle", "somebody you keep hitting from the front stops going there (%s)" % wary["label"])

	# Opened at the head.
	WorldHistory.register_subject("headcase", {"name": "Headcase", "kind": "person"})
	WorldHistory.record_event("melee_body_hit", {"subject": "headcase", "zone": "head"})
	var covered: Dictionary = Tactics.tactic_for("headcase")
	_check(str(covered["id"]) == "turtle", "somebody whose head you opened covers up (%s)" % covered["label"])
	_check(float(covered["guard_bias"]) > float(green["guard_bias"]), "and guards more than somebody who has not been (%.2f vs %.2f)" % [float(covered["guard_bias"]), float(green["guard_bias"])])

	# Lost a limb — the loudest thing that can happen to a body wins.
	WorldHistory.register_subject("stump", {"name": "Stump", "kind": "person"})
	WorldHistory.record_event("melee_body_hit", {"subject": "stump", "zone": "head"})
	WorldHistory.record_event("limb_severed_in_combat", {"subject": "stump", "zones": ["left_arm"]})
	var burned: Dictionary = Tactics.tactic_for("stump")
	_check(str(burned["id"]) == "stand_off", "losing an arm inside your reach beats every other memory (%s)" % burned["label"])
	_check(float(burned["keep_distance"]) > 6.0, "and they keep a real distance (%.1fm)" % float(burned["keep_distance"]))

	# Beaten alone often enough that they stop coming alone.
	WorldHistory.register_subject("crowd", {"name": "Crowd", "kind": "person"})
	for _loss in 3:
		WorldHistory.record_event("npc_resolution", {"subject": "crowd"})
	_check(str(Tactics.tactic_for("crowd")["id"]) == "swarm", "three losses and they bring others")

	# The approach a tactic produces, which is what the encounter loop asks for.
	_check(str(Tactics.approach(burned, 20.0)) == "close", "too far from their preferred distance, they close")
	_check(str(Tactics.approach(burned, 7.5)) == "hold", "at it, they hold")
	_check(str(Tactics.approach(burned, 1.0)) == "withdraw", "inside it, they back off")
	_check(str(Tactics.approach(green, 14.0)) == "close", "a presser always closes")

	# The tree itself.
	var tree = Tactics.build_tree(burned)
	_check(tree != null, "a behaviour tree is built for the tactic")
	if tree != null:
		_check(str(tree.get_meta("tactic")) == "stand_off", "carrying the tactic it was built from")
		_check(is_equal_approx(float(tree.get_meta("keep_distance")), float(burned["keep_distance"])), "and the distance it should keep")

	# Nothing is stored, so the tactic cannot drift from what happened.
	var again: Dictionary = Tactics.tactic_for("stump")
	_check(str(again["id"]) == str(burned["id"]), "asking twice gives the same answer, because nothing is cached")

	print("")
	if failures.is_empty():
		print("F4.2 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
