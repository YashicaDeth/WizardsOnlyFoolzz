extends Node

const ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

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
	await get_tree().process_frame
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	get_tree().root.add_child(hunt)
	get_tree().current_scene = hunt
	for _settle in 45:
		await get_tree().process_frame
	# Put a deterministic body beside the player with a manifest that can be
	# verified both before and after one physical search.
	hunt.player = Vector3(58.0, 1.0, 58.0)
	(hunt.player_body as CharacterBody3D).position = hunt.player
	var at: Vector3 = hunt.player + Vector3(1.0, -0.5, 0.2)
	hunt._spawn_encounter_actor({
		"instance_id": "searched_body", "kind": "hostile",
		"display_name": "Searched Body", "loot": ["field dressing", "rust scrip"],
	}, at)
	var actor: Dictionary = hunt.encounter_actors.back()
	(actor.node as Node3D).position = at
	hunt._kill_encounter_actor(hunt.encounter_actors.size() - 1, "test")
	var preview: Dictionary = hunt._nearest_world_item_for_inspection()
	check(str(preview.get("kind", "")) == "corpse" and str(preview.get("item_id", "")) == str(actor.subject_id),
		"I targets the whole dead body rather than its loose cache or a gore fragment")
	var detail := str(preview.get("detail", ""))
	check(detail.contains("FIELD DRESSING") and detail.contains("RUST SCRIP"),
		"the corpse inspection names the exact loose manifest before it is taken")
	var inventory_before: int = (WorldHistory.subject("inventory").get("items", []) as Array).size()
	var receipt_before := ACTION_LEDGER.count("loot_collected")
	hunt._interact()
	var inventory_after: Array = WorldHistory.subject("inventory").get("items", [])
	check(inventory_after.size() == inventory_before + 2 and inventory_after.has("field dressing") and inventory_after.has("rust scrip"),
		"one E search moves the body's complete loose manifest into inventory")
	check(ACTION_LEDGER.count("loot_collected") == receipt_before + 1 and hunt.loose_loot.is_empty(),
		"the body search writes one routed receipt and cannot be spam-collected")
	check(not hunt.dead_bodies.is_empty() and str(hunt._nearest_robbable().get("subject_id", "")) == str(actor.subject_id),
		"collecting loose loot leaves the physical corpse available for deliberate H extraction")
	print("CORPSE_LOOT_INSPECTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
