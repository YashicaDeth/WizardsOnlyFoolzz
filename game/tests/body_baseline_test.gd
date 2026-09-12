extends Node

## B2.2. Organs, bones and implants readable without opening anybody.
##
## The failure this guards against is quiet: a person in the registry carries a
## blood type and a list of cybernetics and nothing else, so their dossier could
## list the organs a body has and say nothing about any of them. Reading
## somebody's insides meant opening them. A baseline body is built for anyone
## the world has not recorded, from the same component every real body uses.

const BODY_INSPECTOR := preload("res://systems/body_inspector.gd")

var failures: Array[String] = []


func check(condition: bool, described: String) -> void:
	if not condition:
		failures.append(described)
	print("%s %s" % ["  ok" if condition else "FAIL", described])


func _ready() -> void:
	var inspector: Node = BODY_INSPECTOR.new()
	# Set directly rather than through `set_subject()`, which starts the lift
	# animation and wants a viewport a headless run does not have.
	inspector.subject = {
		"name": "Nix Arden", "kind": "person", "role": "Scrap medic",
		"wounds": ["spore-burned right lung"],
		"anatomy": {"blood_type": "A-ASH", "cybernetics": ["copper lung bellows", "dose counter"]},
	}
	var anatomy: Dictionary = inspector.call("_anatomy")
	var organs: Dictionary = anatomy.get("organs", {})
	var zones: Dictionary = anatomy.get("zones", {})
	check(organs.size() >= 6, "a stranger's organs are listed (%d)" % organs.size())
	var readable := 0
	for organ_id in organs:
		if (organs[organ_id] as Dictionary).has("health"):
			readable += 1
	check(readable == organs.size(), "every organ has a condition (%d of %d)" % [readable, organs.size()])
	check(zones.size() >= 6, "the zones carrying bone are listed (%d)" % zones.size())
	check(str(anatomy.get("blood_type", "")) == "A-ASH", "what the registry recorded is kept, not overwritten")

	# A body the world *has* opened must still win over the generated one.
	inspector.subject = {"name": "Opened Subject", "anatomy_state": {"organs": {"heart": {"health": 3.0}}}}
	var recorded: Dictionary = inspector.call("_anatomy")
	check(
		((recorded.get("organs", {}) as Dictionary).get("heart", {}) as Dictionary).get("health", -1.0) == 3.0,
		"a recorded body beats the baseline",
	)
	inspector.free()
	print("BODY_BASELINE_TEST_RESULT failures=", failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
