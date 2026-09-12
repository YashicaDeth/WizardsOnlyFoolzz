extends Node

## Q1.4. Stalking a feed must actually locate somebody from real recorded
## history, refuse honestly when there is none, and prefer the most recent
## sighting over a stale one.

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
	WorldHistory.register_subject("mara_voss", {"name": "Mara Voss", "kind": "person"})

	var wire := WireNet.new()

	var no_sighting := wire.locate("mara_voss")
	check(not bool(no_sighting.get("ok", false)), "refuses honestly when nobody has recorded where they were")

	WorldHistory.record_event("rival_struck_player", {"rival": "mara_voss", "location": "bone_yard_pit"})
	var found := wire.locate("mara_voss")
	check(bool(found.get("ok", false)), "a real recorded location is found")
	check(str(found.get("location", "")) == "bone_yard_pit", "and it is the actual recorded place, not invented")
	check(str(found.get("from_event", "")) == "rival_struck_player", "attributed to the real event it came from")

	# --- prefers the most recent sighting, not the first one -----------------
	WorldHistory.record_event("proximity_voice_addressed", {"listener": "mara_voss", "location": "ossuary_stairwell"})
	var updated := wire.locate("mara_voss")
	check(str(updated.get("location", "")) == "ossuary_stairwell", "a later sighting supersedes an earlier one (%s)" % str(updated.get("location", "")))

	# --- observe surfaces it, without breaking the existing detail string ---
	var observed := wire.act("mara_voss", "observe")
	check(bool(observed.get("ok", false)), "observe still succeeds")
	check(str(observed.get("location", {}).get("location", "")) == "ossuary_stairwell", "and now also surfaces where they were last seen")
	check(str(observed.get("detail", "")).contains("REACH"), "without disturbing the existing detail string anything else may already parse")

	print("WIRE_LOCATE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
