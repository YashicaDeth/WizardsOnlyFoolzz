extends Node

## AU1.2. "It can be stolen off a body" wired into the real robbery verb: a
## body carrying a substance is now `_nearest_robbable()`, and `E`/
## `_begin_extraction()` takes it in one instant motion - a pocket, not a
## wound - before whatever the body's actual anatomy might also be worth
## digging for. No new key to discover; the existing extraction verb just
## does one more thing than it used to.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.player_body.position = Vector3(175, 0.9, 125)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt.third_person = false
	hunt._update_camera()

	print("AU1.2 - a body with only a pocket, nothing worth cutting open")
	var at: Vector3 = hunt.player + Vector3(0, -0.5, 1.6)
	hunt._spawn_encounter_actor({"instance_id": "carrier", "kind": "hostile", "summary": "unarmed carrier"}, at)
	var carrier: Dictionary = hunt.encounter_actors.back()
	carrier.node.position = at
	await get_tree().physics_frame
	hunt._kill_encounter_actor(hunt.encounter_actors.find(carrier), "test")
	WorldHistory.update_subject(str(carrier.subject_id), {"carried_substance": "marrow_dust"})

	check(str(hunt._nearest_robbable().get("subject_id", "")) == str(carrier.subject_id), "a body worth nothing but its pocket is still robbable")
	var carry_before: int = hunt.handheld.carry.items.size()
	hunt._begin_extraction()
	check(hunt.handheld.carry.items.size() == carry_before + 1, "E takes the substance in one motion, no dig session needed")
	check(hunt.extraction_session.is_empty(), "and never opens a dig session for it - there was nothing to dig")
	var taken: Dictionary = hunt.handheld.carry.items.back()
	check(str(taken.get("substance_id", "")) == "marrow_dust", "the item taken is the one the body actually carried")
	check(bool(taken.get("stolen", false)), "and it is marked stolen, the same as anything else lifted off somebody")
	check(str(WorldHistory.subject(str(carrier.subject_id)).get("carried_substance", "MISSING")) == "", "the body's own record is cleared")
	# A baseline body always has intact organs by default, so the body itself
	# stays robbable — the real check is that a second press now goes after
	# the anatomy rather than re-taking a pocket that is already empty.
	hunt._begin_extraction()
	check(hunt.handheld.carry.items.size() == carry_before + 1, "a second press does not somehow take the pocket twice")
	check(not hunt.extraction_session.is_empty(), "it opens a real anatomy dig instead, now that the pocket is empty")
	hunt.extraction_session = {}

	var found_event := false
	for event: Dictionary in WorldHistory.events:
		if str(event.get("type", "")) == "substance_stolen" and str((event.get("details", {}) as Dictionary).get("target_id", "")) == str(carrier.subject_id):
			found_event = true
	check(found_event, "the theft is a real recorded event, run through the same witness ledger as everything else")

	print("AU1.2 - a body with both a pocket and real anatomy gives up the pocket first")
	# Moved well outside _nearest_robbable()'s radius so the first carrier -
	# itself still robbable for its organs - cannot be picked up by mistake.
	carrier.node.position += Vector3(500, 0, 0)
	var at2: Vector3 = hunt.player + Vector3(0.4, -0.5, 1.6)
	hunt._spawn_encounter_actor({"instance_id": "loaded_carrier", "kind": "hostile", "summary": "armed carrier"}, at2)
	var loaded: Dictionary = hunt.encounter_actors.back()
	loaded.node.position = at2
	loaded.rig.install_prosthetic("torso", {"name": "ceramic sternum"})
	await get_tree().physics_frame
	hunt._kill_encounter_actor(hunt.encounter_actors.find(loaded), "test")
	WorldHistory.update_subject(str(loaded.subject_id), {"carried_substance": "choir_bloom"})

	var carry_before2: int = hunt.handheld.carry.items.size()
	hunt._begin_extraction()
	check(hunt.handheld.carry.items.size() == carry_before2 + 1, "the first press takes the pocket, not the sternum")
	check(hunt.extraction_session.is_empty(), "still no dig session opened on that same press")
	hunt._begin_extraction()
	check(not hunt.extraction_session.is_empty(), "a second press, with the pocket already empty, opens the real dig")

	print("POCKET_SEARCH_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
