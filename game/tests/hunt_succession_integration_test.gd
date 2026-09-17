extends Node

## F10.5. WireNet's succession unit test proves the ranking rule; this proves
## the production Hunt death seam actually invokes it. A real anatomical actor
## dies through `_kill_encounter_actor()`, opening their saved post, and the
## deferred idle turn fills it from people who already existed.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func faction_people(faction_id: String) -> Array[String]:
	var people: Array[String] = []
	for subject_id: String in WorldHistory.all_subjects():
		var subject: Dictionary = WorldHistory.subject(subject_id)
		if str(subject.get("kind", "")) == "person" and str(subject.get("faction_id", "")) == faction_id:
			people.append(subject_id)
	people.sort()
	return people


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	WorldHistory.register_subject("succession_probe_faction", {
		"name": "The Test Claim", "kind": "faction", "vacant_posts": [],
	})
	WorldHistory.register_subject("succession_heir", {
		"name": "Existing Heir", "kind": "person",
		"faction_id": "succession_probe_faction", "role": "Quartermaster",
		"loyalty": 80, "wealth": 40, "elo": 800,
		"relations": {"succession_probe_faction": {"kind": "command", "strength": 75}},
	})
	WorldHistory.register_subject("succession_bruiser", {
		"name": "Stronger Bruiser", "kind": "person",
		"faction_id": "succession_probe_faction", "role": "Bruiser",
		"loyalty": 2, "wealth": 0, "elo": 1900,
		"relations": {},
	})
	hunt._spawn_encounter_actor({
		"instance_id": "succession_holder", "kind": "hostile",
		"display_name": "Fallen Holder", "role": "Crown of the Test Claim",
	}, hunt.player + Vector3(0, -0.5, 4))
	var holder: Dictionary = hunt.encounter_actors.back()
	WorldHistory.amend_subject(str(holder.subject_id), {
		"faction_id": "succession_probe_faction", "faction_rank": "CROWN",
		"role": "Crown of the Test Claim",
	})
	var faction_people_before := faction_people("succession_probe_faction")
	WorldHistory.amend_subject(str(holder.subject_id), {"status": "hunting"})
	OffscreenHunts.start(str(holder.subject_id), "player", "ashbloom_bone_yard")
	WorldClock.pass_time(0.5)
	OffscreenHunts.advance("rift_derby_quarry")
	holder.rig.execute()
	hunt._kill_encounter_actor(hunt.encounter_actors.find(holder), "succession_probe")
	check(str(WorldHistory.subject(str(holder.subject_id)).get("status", "")) == "dead",
		"the production anatomical actor dies through the ordinary Hunt route")
	check(WorldHistory.event_count("faction_post_vacated") == 1,
		"that physical death opens the holder's actual saved post")
	await get_tree().process_frame
	await get_tree().process_frame
	var heir := WorldHistory.subject("succession_heir")
	check(str(heir.get("faction_rank", "")) == "CROWN",
		"the deferred Hunt turn fills the vacancy with an existing faction person")
	check(int(heir.get("elo", 0)) < int(WorldHistory.subject("succession_bruiser").get("elo", 0)),
		"loyalty, influence and wealth outrank raw combat skill in production")
	check(faction_people("succession_probe_faction") == faction_people_before,
		"succession creates no replacement template or extra faction person")
	check(WorldHistory.event_count("faction_post_filled") == 1 and (WorldHistory.subject("succession_probe_faction").get("vacant_posts", []) as Array).is_empty(),
		"promotion closes the persisted vacancy exactly once")
	check(str(heir.get("status", "")) == "hunting" and str(heir.get("hunt_target", "")) == "player" and str(heir.get("hunt_inherited_from", "")) == str(holder.subject_id),
		"the promoted person inherits the fallen holder's exact unfinished hunt")
	check(bool(heir.get("hunt_inherited_without_contact", false)) and not (heir.get("relations", {}) as Dictionary).has("player"),
		"inheritance needs no prior meeting or relationship with the target")
	check(int(heir.get("hunt_offscreen_turns", 0)) == 2 and str(WorldHistory.subject(str(holder.subject_id)).get("hunt_inherited_by", "")) == "succession_heir",
		"the same offscreen search state transfers instead of restarting a new hunt")
	check(WorldHistory.event_count("hunt_inherited") == 1 and (WorldHistory.subject("player").get("hunted_by", []) as Array).any(func(entry: Dictionary): return str(entry.get("hunter_id", "")) == "succession_heir" and str(entry.get("reason", "")) == "inherited_hunt"),
		"the stranger's inherited hunt is attributable and enters the player's exact hunter memory")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"promotion, hunt transfer and player memory close as one deferred succession transaction")

	print("HUNT_SUCCESSION_INTEGRATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
