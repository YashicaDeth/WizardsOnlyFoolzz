extends Node

var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition: failures.append(label)

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("road_knife", {"name": "Road Knife", "kind": "person", "status": "escaped", "is_rival": false, "anatomy_state": {"zones": {"left_arm": {"health": 0.0}, "torso": {"health": 91.0}}, "organs": {}, "severed": ["left_arm"], "wounds": [], "cybernetics": []}})
	WorldHistory.register_subject("written_boss", {"name": "Written Boss", "kind": "person", "status": "active", "is_rival": true})
	var population_before := WorldHistory.all_subjects().size()
	var hit := WorldHistory.record_event("melee_body_hit", {"target": "road_knife", "body_zone": "left_arm", "actor": "player"})
	WorldHistory.record_event("hunt_arc_first_beat_complete", {"target": "road_knife", "outcome": "escaped"})
	var emerged := RivalRegistry.consider("road_knife")
	check(bool(emerged.get("is_rival", false)), "an existing nobody becomes a rival after surviving a real encounter")
	check(str(emerged.get("rival_origin", "")) == str(hit.id), "the rivalry points to the event that caused it")
	check(WorldHistory.all_subjects().size() == population_before, "no rival was generated from a template")
	check(str((emerged.get("rival_adaptation", {}) as Dictionary).get("kind", "")) == "prosthetic", "a missing limb demands a prosthetic")
	check(str((emerged.rival_adaptation as Dictionary).get("zone", "")) == "left_arm", "the adaptation comes from the actually missing limb")
	check(str(emerged.get("memory", "")).contains("left arm"), "the body wound is the written memory")
	check(WorldHistory.event_count("rival_emerged") == 1, "emergence is a fact in world history")
	RivalRegistry.consider("road_knife")
	check(WorldHistory.event_count("rival_emerged") == 1, "reconsidering an existing rival does not invent a second origin")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "rival state and its one-time emergence fact close one world transaction")
	WorldHistory.register_subject("untouched", {"name": "Untouched", "kind": "person", "status": "escaped"})
	check(RivalRegistry.consider("untouched").is_empty(), "escape alone does not author a rival")
	check(RivalRegistry.consider("written_boss").is_empty(), "an authored label without lived history is not enough")
	print("RIVAL_REGISTRY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
