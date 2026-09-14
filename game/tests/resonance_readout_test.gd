extends Node

const ResonanceReadout := preload("res://systems/resonance_readout.gd")

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})

	var sober := ResonanceReadout.snapshot("player", "yesod")
	check(bool(sober.get("ok", false)), "a mapped plane produces one compact readout")
	check(not bool((sober.get("floors", [])[1] as Dictionary).get("available", true)), "sober player cannot talk on Yesod")
	check(str((sober.get("consequence", {}) as Dictionary).get("posture", "")) == "MIXED: KEEP WITNESSES IN FRAME", "zero history does not pretend to be absolution")

	var dose := Substances.take("player", "choir_bloom")
	check(bool(dose.get("ok", false)), "the test took a real door substance")
	var opened := ResonanceReadout.snapshot("player", "yesod")
	check(bool((opened.get("floors", [])[1] as Dictionary).get("available", false)), "readout reports the access the dose actually opened")
	var provenance: Dictionary = opened.get("provenance", {})
	check(int(provenance.get("ATTRIBUTED", 0)) == 1, "the dose is marked attributed, not silently treated as proof")

	for _act in 3:
		WorldHistory.record_event("npc_resolution", {"actor": "player", "outcome": "execute"})
	var harmed := ResonanceReadout.snapshot("player", "yesod")
	check(str((harmed.get("consequence", {}) as Dictionary).get("posture", "")) == "HARM OUTRUNS REPAIR", "the consequence wheel reports unresolved harm in plain language")
	check(not bool(ResonanceReadout.snapshot("player", PlaneLadder.DAATH).get("ok", true)), "an unmapped place gets no confident readout")

	print("RESONANCE_READOUT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
