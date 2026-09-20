extends Node

const Society := preload("res://systems/pyramid_society.gd")

var failures: Array[String] = []
var hook_calls: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _hook(subject_id: String, _event: Dictionary) -> void:
	hook_calls.append(subject_id)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var society := Society.new()
	var apex := {
		"name": "The Last Receiver", "faction_id": "celloutz", "alignment": -0.95,
		"social_power": {"class": 98, "influence": 92, "wealth": 88, "access": 94, "reputation": 30, "fear": 80, "respect": 42, "faction": 96, "combat": 12, "leverage": 90, "knowledge": 72, "relationships": 84},
	}
	society.register_subject("receiver", apex)
	society.register_subject("fighter", {"name": "Vale Nine", "faction_id": "celloutz", "social_power": {"combat": 100, "fear": 92, "influence": 8}})
	for index in 4:
		society.register_subject("claimant_%d" % index, {"name": "Claimant %d" % index, "faction_id": "celloutz", "social_power": {"class": 91, "influence": 80 - index, "access": 75, "leverage": 70}})
	var pyramid := society.pyramid("celloutz")
	check(pyramid.geometry == "3x3_expanding_horseshoe", "pyramid exposes stable 2D/3D horseshoe geometry")
	check((pyramid.bands[0].members as Array).size() == 1, "exactly one subject holds the singularity")
	check((pyramid.bands[1].members as Array).size() <= 3, "the next ring has a distinct three-person capacity")
	var fighter := society.standing("fighter", "celloutz")
	check(fighter.band_id == "outside", "combat alone cannot grant social class")
	var receiver := society.standing("receiver", "celloutz")
	check(receiver.side == "BELOW" and float(receiver.position.horseshoe_x) < 0.0, "alignment places a subject on the lower horseshoe pole")
	check(not receiver.has("score") and not receiver.has("elo"), "player-facing standing has a band and vector, never one rating")

	var event := society.record_nemesis_event("fighter", "ambushed_player", {"location_id": "bone_yard"})
	society.record_nemesis_event("fighter", "escaped", {"wound": "left_arm"})
	check(str(event.id).begins_with("nemesis_") and society.nemesis_history("fighter").size() == 2, "nemesis history is ordered persistent data")
	society.link_dossier("fighter", "evidence", {"id": "photo_7", "event_id": event.id})
	society.link_dossier("fighter", "social_posts", {"id": "post_9", "website_id": "burnt_highway_forum"})
	society.link_dossier("fighter", "websites", {"id": "burnt_highway_forum"})
	society.link_dossier("fighter", "locations", {"id": "bone_yard"})
	society.link_dossier("fighter", "associates", {"id": "receiver", "relation": "command"})
	check(society.dossier("fighter").evidence.size() == 1 and society.dossier("fighter").social_posts.size() == 1 and society.dossier("fighter").associates.size() == 1, "dossier links evidence, posts, sites, places and people")

	var grave := society.mark_dead("fighter", {"event_id": "death_1", "location_id": "bone_yard"}, {
		"available": true,
		"costs": [
			{"resource": "grave_scrip", "amount": 400, "category": "world_resource"},
			{"resource": "AUD", "amount": 5, "category": "real_money"},
		],
		"hook_ids": ["restore_anatomy", "resume_story"],
		"story_gate": "the_body_was_recovered",
	})
	check(society.subject("fighter").status == "dead" and society.graveyard_entries().size() == 1, "death archives the whole subject instead of deleting it")
	check((grave.resurrection.costs as Array).size() == 1 and grave.resurrection.costs[0].resource == "grave_scrip", "real-money resurrection metadata is rejected")
	var request := society.request_resurrection("fighter")
	check(request.ok and request.hook_ids.has("restore_anatomy"), "resurrection exposes story/economy hook ids without charging anything")
	society.register_resurrection_hook("restore_anatomy", _hook)

	var saved_json := JSON.stringify(society.snapshot())
	var restored := Society.new()
	restored.restore(JSON.parse_string(saved_json))
	check(restored.subject("fighter").is_rival and restored.nemesis_history("fighter").size() == 3, "nemesis events survive JSON save and restore, including death")
	check(restored.dossier("fighter").websites[0].id == "burnt_highway_forum", "dossier references survive serialization")
	check(restored.graveyard_entries().size() == 1 and restored.request_resurrection("fighter").ok, "graveyard and resurrection offer survive serialization")
	restored.register_resurrection_hook("restore_anatomy", _hook)
	var returned := restored.complete_resurrection("fighter", {"fulfilled_by": "quest_system"})
	check(returned.status == "active" and restored.graveyard_entries().is_empty(), "an external system can complete resurrection through the hook boundary")
	check(hook_calls == ["fighter"], "registered runtime resurrection hook fires once")

	var legacy := Society.new()
	legacy.restore({"subjects": {"old_dead": {"name": "Old Dead", "status": "killed", "elo": 1900, "influence": 44, "custom_lore": "kept"}}})
	var migrated := legacy.subject("old_dead")
	check(migrated.schema_version == Society.SCHEMA_VERSION and migrated.custom_lore == "kept", "legacy records gain defaults without losing unknown authored fields")
	check(float(migrated.social_power.influence) == 44.0 and float(migrated.social_power.combat) == 0.0, "known dimensions migrate but legacy ELO is not treated as combat or class")
	check(legacy.graveyard_entries().size() == 1, "legacy dead status reconstructs a graveyard entry")
	check(JSON.stringify(legacy.snapshot()).contains("old_dead"), "migrated state remains JSON serializable")
	legacy.restore({"records": {"old_rival": {"nemesis_events": [{"id": "nemesis_000012", "sequence": 12, "type": "escaped", "details": {}}]}}})
	check(legacy.record_nemesis_event("old_rival", "returned").sequence == 13, "legacy event history advances its missing sequence counter safely")

	print("PYRAMID_SOCIETY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
