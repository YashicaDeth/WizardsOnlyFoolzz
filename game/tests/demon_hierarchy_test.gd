extends Node

## K4.3/K4.5. The four tiers must be a reading of subjects that already
## exist, never a spawner — this test builds its own minimal subjects rather
## than relying on bone_yard_hunt.gd's seed to prove the classifier works off
## any faction/rival shaped correctly, not off one hardcoded roster.

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
	CosmologyFactions._seed()

	check(DemonHierarchy.tier("celloutz") == "LEADERSHIP", "CellOutz itself reads as the Leadership tier")
	check(DemonHierarchy.tier("vanity_row") == "SIN", "a Sin-faction built this session reads as SIN")

	# --- a Sin seeded elsewhere (bone_yard_hunt.gd) reads the same way, by
	# faction id alone, and its captain is read off its own command edge
	# rather than a new field this file would have to invent.
	WorldHistory.register_subject("ashline_wreckers", {"kind": "faction", "name": "Ashline Wreckers"})
	check(DemonHierarchy.tier("ashline_wreckers") == "SIN", "and so does one seeded elsewhere, by faction id alone")
	WorldHistory.register_subject("mara_voss", {"kind": "person", "faction_id": "ashline_wreckers", "is_rival": false})
	WorldHistory.register_subject("ashline_wreckers", {"relations": {"mara_voss": {"kind": "command", "strength": 72}}})
	check(DemonHierarchy.tier("mara_voss") == "CAPTAIN", "the person a Sin's own relations name as its commander reads as CAPTAIN")

	WorldHistory.register_subject("gate_lanterns", {"kind": "faction", "name": "Gate Lanterns"})
	check(DemonHierarchy.tier("gate_lanterns") == "", "an ascending faction is not part of this hierarchy at all")

	# --- a Horseman is whoever actually holds the CROWN, no name required ----
	WorldHistory.register_subject("nobody_yet", {"kind": "person", "faction_id": "celloutz"})
	check(DemonHierarchy.tier("nobody_yet") == "", "a CellOutz member with no rank is not a Horseman")
	WorldHistory.update_subject("nobody_yet", {"faction_rank": "CROWN"})
	check(DemonHierarchy.tier("nobody_yet") == "LEADERSHIP", "whoever actually holds CROWN reads as Leadership the moment they do, unnamed or not")

	# --- lesser demons are F4.1's own rivals, reread, never spawned here -----
	WorldHistory.register_subject("stray_one", {"kind": "person", "is_rival": true, "faction_id": ""})
	WorldHistory.register_subject("affiliated_rival", {"kind": "person", "is_rival": true, "faction_id": "black_mile"})
	WorldHistory.register_subject("bystander", {"kind": "person", "is_rival": false, "faction_id": ""})
	check(DemonHierarchy.is_lesser_demon("stray_one"), "an unaffiliated rival is a lesser demon")
	check(not DemonHierarchy.is_lesser_demon("affiliated_rival"), "a rival already folded into a Sin's roster is not — it is that Sin's captain material")
	check(not DemonHierarchy.is_lesser_demon("bystander"), "a bystander who was never made a rival is not a demon at all")
	var roaming := DemonHierarchy.lesser_demons()
	check(roaming.has("stray_one") and not roaming.has("affiliated_rival") and not roaming.has("bystander"), "lesser_demons() lists exactly the roaming ones")

	print("DEMON_HIERARCHY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
