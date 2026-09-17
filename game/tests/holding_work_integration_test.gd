extends Node

const HOLDINGS := preload("res://systems/ashbloom_holdings.gd")
const INDEX := preload("res://systems/world_index.gd")

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

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt._maintain_holding_work()
	var raid_targets: Array = hunt.encounter_actors.filter(func(actor: Dictionary): return str(actor.get("holding_work_job", "")) == raid_id)
	check(raid_targets.size() == 2 and raid_targets.all(func(actor: Dictionary): return actor.rig is BaselineHuman),
		"accepted raid work enters the production encounter world as two full anatomy bodies")
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
	check(str(WorldHistory.subject(raid_id).get("status", "")) == "completed" and int(WorldHistory.subject(raid_id).get("progress", 0)) == 2,
		"resolving both physical targets completes and timestamps the same raid record")

	var collection_id := "holding_job:bone_yard:field_recovery"
	HOLDINGS.accept_work(collection_id)
	hunt._maintain_holding_work()
	var work_caches: Array = hunt.loose_loot.filter(func(cache: Node3D): return str(cache.get_meta("holding_work_job", "")) == collection_id)
	check(work_caches.size() == 1, "accepted collection work places one identified cache at its saved world coordinate")
	if not work_caches.is_empty():
		hunt.player = (work_caches[0] as Node3D).global_position
		hunt.player_body.position = hunt.player - Vector3.UP * 0.6
		hunt._interact()
	check(str(WorldHistory.subject(collection_id).get("status", "")) == "completed" and WorldHistory.event_count("holding_work_resolved") == 2,
		"physically collecting the cache completes the recovery through the ordinary loot interaction")

	print("HOLDING_WORK_INTEGRATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
