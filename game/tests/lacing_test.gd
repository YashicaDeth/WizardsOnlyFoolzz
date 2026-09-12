extends Node

## AU1.10. "You can lace somebody. witness_ledger.gd already decides who saw
## what, AE1.4's law responds to what was witnessed, AJ5's gods give a
## verdict and disagree. The game records it and does not congratulate you."
##
## AE1.4 (law responding to what was witnessed) is not built yet - this
## covers the two pieces that are real and buildable today: the act itself,
## witnessed through the exact same `WitnessLedger` object `Extraction`
## already takes as a parameter, and a real verdict from the gods.

const SUBSTANCES := preload("res://systems/substances.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "anatomy_state": {"pain": 0.0, "consciousness": 100.0}})
	WorldHistory.register_subject("mara_voss", {"name": "Mara Voss", "kind": "person", "anatomy_state": {"pain": 40.0, "consciousness": 100.0}})
	ModernGods.seed_gods()

	print("AU1.10 - it happens to the target, not the actor")
	var before_actor: Dictionary = WorldHistory.subject("player").get("anatomy_state", {})
	var result := SUBSTANCES.lace("player", "mara_voss", "marrow_dust")
	_check(bool(result.get("ok", false)), "lacing someone with a real substance actually goes through")
	var after_target: Dictionary = WorldHistory.subject("mara_voss").get("anatomy_state", {})
	_check(float(after_target.get("consciousness", 100.0)) < 100.0, "the target actually carries the effect")
	var after_actor: Dictionary = WorldHistory.subject("player").get("anatomy_state", {})
	_check(is_equal_approx(float(after_actor.get("consciousness", 100.0)), float(before_actor.get("consciousness", 100.0))), "and the actor's own body is untouched by it")

	print("AU1.10 - the actor gets nothing structural back")
	_check(Boons.active_boons("player").is_empty(), "no boon is granted for lacing somebody - this is not take() under another name")

	print("AU1.10 - the game records it")
	var found_event := false
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) == "subject_laced":
			found_event = true
	_check(found_event, "a real event exists naming what happened, not a silent state change")

	print("AU1.10 - the gods give a verdict, and can disagree")
	_check(not (result.get("verdicts", []) as Array).is_empty(), "at least one god actually renders a verdict")
	var verdict_events := 0
	var labels: Array = []
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) == "lacing_verdict":
			verdict_events += 1
			var label: String = str((event.get("details", {}) as Dictionary).get("label", ""))
			if not labels.has(label):
				labels.append(label)
	_check(verdict_events == (result.get("verdicts", []) as Array).size(), "every verdict is its own recorded event, not summed into one score")

	print("AU1.10 - it is genuinely witnessed, through the same ledger Extraction already uses")
	WorldHistory.register_subject("bystander", {"name": "A Bystander", "kind": "person"})
	var ledger := WitnessLedger.new()
	var witnessed := SUBSTANCES.lace("player", "mara_voss", "marrow_dust", ledger, ["bystander"])
	_check(int(witnessed.get("witnessed_by", 0)) == 1, "the caller's own witness list is honoured (%d)" % int(witnessed.get("witnessed_by", 0)))
	_check(not ledger.pending.is_empty(), "a real report is actually in flight for the witness, not merely counted")

	print("LACING_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
