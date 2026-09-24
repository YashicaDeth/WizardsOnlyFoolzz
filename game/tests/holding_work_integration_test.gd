extends Node

const HOLDINGS := preload("res://systems/ashbloom_holdings.gd")
const INDEX := preload("res://systems/world_index.gd")
const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

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
	HOLDINGS.ensure()
	check(HOLDINGS.work_orders("bone_yard").is_empty(), "unknown land does not leak jobs before exploration")

	var bone: Dictionary = HOLDINGS.DEFINITIONS[2]
	HOLDINGS.observe(bone.at)
	var jobs := HOLDINGS.work_orders("bone_yard")
	check(jobs.size() == 2 and jobs.all(func(job: Dictionary): return str(job.get("kind", "")) == "job" and str(job.get("status", "")) == "offered"),
		"revealing one holding publishes two persistent local work records")
	check(jobs.any(func(job: Dictionary): return str(job.get("work_type", "")) == "raid") and jobs.any(func(job: Dictionary): return str(job.get("work_type", "")) == "collection"),
		"the place offers both a physical raid and a physical recovery collection")
	HOLDINGS.work_orders("bone_yard")
	check(WorldHistory.event_count("holding_work_published") == 1, "reading the dossier again neither republishes nor rewrites its work")

	var index := INDEX.new()
	add_child(index)
	index.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	index.size = Vector2(1280, 720)
	index.open()
	for row_index in index._rail_cache.size():
		if str((index._rail_cache[row_index] as Dictionary).id) == str(bone.record):
			index.rail_index = row_index
			break
	index._rebuild_links()
	var work_links: Array = index._link_rects.filter(func(link: Dictionary): return str(link.get("kind", "")) == "holding_job")
	check(work_links.size() == 2, "the holding's real INDEX dossier exposes both offered orders as pointable actions")
	if work_links.is_empty():
		print("HOLDING_WORK_INTEGRATION_RESULT failures=", failures.size())
		get_tree().quit(1)
		return
	var raid_link: Dictionary = work_links.filter(func(link: Dictionary): return str(link.get("id", "")).ends_with(":claim_crew"))[0]
	index._follow_link(raid_link)
	var raid_id := str(raid_link.id)
	check(str(WorldHistory.subject(raid_id).get("status", "")) == "active" and WorldHistory.event_count("holding_work_started") == 1,
		"taking dossier work creates one saved active contract rather than a map toggle")
	index._follow_link(raid_link)
	check(WorldHistory.event_count("holding_work_started") == 1, "an accepted order cannot be consumed or duplicated twice")
	var start_events := WorldHistory.recent_events(8).filter(func(event: Dictionary): return str(event.get("type", "")) == "holding_work_started")
	check(start_events.size() == 1 and str((start_events[0] as Dictionary).get("details", {}).get("action_id", "")).begins_with("action_"),
		"acceptance receives one durable player-action receipt")
	check(PLAYER_ACTION_LEDGER.count("holding_work_started") == 1 and int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"acceptance leaves one summarized act and closes its persistence batch")

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt._maintain_holding_work()
	var raid_targets: Array = hunt.encounter_actors.filter(func(actor: Dictionary): return str(actor.get("holding_work_job", "")) == raid_id)
	check(raid_targets.size() == 2 and raid_targets.all(func(actor: Dictionary): return actor.rig is BaselineHuman) and int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"accepted raid work enters as two full anatomy bodies in one closed maintenance transaction")
	var raid_contacts: Array = hunt._map_contacts().filter(func(contact: Dictionary): return str(contact.get("job_id", "")) == raid_id)
	check(raid_contacts.size() == 1 and str(raid_contacts[0].state) == "work_raid",
		"MAP receives one raid objective at the contract coordinate instead of duplicating its two people")
	var target_ids: Array = WorldHistory.subject(raid_id).get("target_subjects", [])
	check(target_ids.size() == 2, "the contract persists the exact two people who own its progress")

	for actor: Dictionary in raid_targets:
		(actor.node as Node3D).queue_free()
		hunt.encounter_actors.erase(actor)
	await get_tree().process_frame
	hunt._maintain_holding_work()
	raid_targets = hunt.encounter_actors.filter(func(actor: Dictionary): return str(actor.get("holding_work_job", "")) == raid_id)
	check(raid_targets.size() == 2, "an unresolved raid restores the same targets after a scene rebuild")

	for actor: Dictionary in raid_targets.duplicate():
		var actor_index: int = hunt.encounter_actors.find(actor)
		if actor_index >= 0:
			hunt._kill_encounter_actor(actor_index, "holding_work_test")
	hunt._maintain_holding_work()
	check(str(WorldHistory.subject(raid_id).get("status", "")) == "completed" and int(WorldHistory.subject(raid_id).get("progress", 0)) == 2 and int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"resolving both physical targets completes the same raid record in one closed maintenance transaction")
	check(int(WorldHistory.subject(str(bone.record)).get("local_work_completed", 0)) == 1 and str(WorldHistory.subject(str(bone.record)).get("local_work_state", "")) == "disrupted",
		"one resolved order weakens the place's claim but cannot counterfeit reclamation")
	hunt._maintain_holding_work()
	var state_root: Node = hunt.generated_world.get_node_or_null("HoldingWorkState")
	var state_mark: Node = state_root.get_node_or_null("Claim_bone_yard") if state_root != null else null
	check(state_mark != null and str(state_mark.get_meta("work_state", "")) == "disrupted",
		"disrupted work appears as a physical broken claim in the walked district")
	var disrupted_profile: Dictionary = hunt.living_map.holding_work_profile("disrupted", 0.0)
	check(bool(disrupted_profile.visible) and not bool(disrupted_profile.decision_open) and float(disrupted_profile.crack_alpha) > 0.0,
		"MAP fractures a disrupted holding without falsely opening the land decision")
	check(not hunt._map_contacts().any(func(contact: Dictionary): return str(contact.get("job_id", "")) == raid_id),
		"completed raid work leaves MAP while its resolved people remain ordinary world records")

	var collection_id := "holding_job:bone_yard:field_recovery"
	HOLDINGS.accept_work(collection_id)
	hunt._maintain_holding_work()
	var work_caches: Array = hunt.loose_loot.filter(func(cache: Node3D): return str(cache.get_meta("holding_work_job", "")) == collection_id)
	check(work_caches.size() == 1, "accepted collection work places one identified cache at its saved world coordinate")
	var collection_contacts: Array = hunt._map_contacts().filter(func(contact: Dictionary): return str(contact.get("job_id", "")) == collection_id)
	check(collection_contacts.size() == 1 and str(collection_contacts[0].state) == "work_collection",
		"MAP marks the active recovery once rather than stacking a generic loot square beneath it")
	if not work_caches.is_empty():
		hunt.player = (work_caches[0] as Node3D).global_position
		hunt.player_body.position = hunt.player - Vector3.UP * 0.6
		hunt._interact()
	check(str(WorldHistory.subject(collection_id).get("status", "")) == "completed" and WorldHistory.event_count("holding_work_resolved") == 2,
		"physically collecting the cache completes the recovery through the ordinary loot interaction")
	var resolution_events := WorldHistory.recent_events(24).filter(func(event: Dictionary): return str(event.get("type", "")) == "holding_work_resolved")
	check(resolution_events.size() == 2 and resolution_events.all(func(event: Dictionary): return str(event.get("details", {}).get("action_id", "")).begins_with("action_")),
		"both physical resolutions travel through the same durable action route")
	check(PLAYER_ACTION_LEDGER.count("holding_work_resolved") == 2 and int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"resolved work is summarized without leaving a nested batch open")
	check(int(WorldHistory.subject(str(bone.record)).get("local_work_completed", 0)) == 2 and str(WorldHistory.subject(str(bone.record)).get("local_work_state", "")) == "ready_for_decision" and WorldHistory.event_count("holding_claim_disrupted") == 1,
		"both connected jobs open one persistent land decision without choosing its recipient")
	hunt._maintain_holding_work()
	state_root = hunt.generated_world.get_node_or_null("HoldingWorkState")
	state_mark = state_root.get_node_or_null("Claim_bone_yard") if state_root != null else null
	var open_profile: Dictionary = hunt.living_map.holding_work_profile("ready_for_decision", 1.0)
	check(state_mark != null and str(state_mark.get_meta("work_state", "")) == "ready_for_decision" and bool(open_profile.decision_open) and float(open_profile.pulse_alpha) > 0.0,
		"the walked district and MAP both escalate when its connected land decision opens")
	hunt.pin_board.pin(str(bone.record), "record")
	var decision_cards: Array = hunt.pin_board.cards.filter(func(card): return card.id == str(bone.record))
	check(decision_cards.size() == 1 and decision_cards[0].body.contains("CLAIM DISRUPTED") and decision_cards[0].body.contains("DECISION OPEN"),
		"the same completed place state reaches its pinned Board card without a parallel flag")

	print("HOLDING_WORK_INTEGRATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
