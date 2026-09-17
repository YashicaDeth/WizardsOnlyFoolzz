extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _spare(hunt: Node, index: int, at: Vector3) -> void:
	hunt._spawn_encounter_actor({
		"instance_id": "mercy_target_%d" % index, "kind": "hostile",
		"display_name": "Mercy Target %d" % index,
		"role": "UNAFFILIATED DRIFTER", "summary": "A real body in the Hunt.",
	}, at)
	var actor: Dictionary = hunt.encounter_actors.back()
	(actor.node as Node3D).position = at
	actor.anatomy.go_down()
	hunt.resolution_target = str(actor.subject_id)
	hunt._resolve_downed("spare")
	(actor.node as Node3D).position = Vector3(-220, 1, -170)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	CosmologyFactions._seed()
	AscentEntities.seed_entities()
	TheFourHorsemen.seed_horsemen()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	var at := Vector3(14, 1, 18)
	hunt.player_body.position = at + Vector3(0, 0, 1.4)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	for existing: Dictionary in hunt.encounter_actors:
		(existing.node as Node3D).position = Vector3(-220, 1, -170)

	_spare(hunt, 0, at)
	_spare(hunt, 1, at)
	check(not bool(WorldHistory.subject("clear_frequency").get("has_noticed", false)), "two real Hunt mercies remain below the Clear Frequency's threshold")
	check(HuntContracts.offers().is_empty(), "the market does not publish early just because the player opened the Hunt")
	_spare(hunt, 2, at)
	check(bool(WorldHistory.subject("clear_frequency").get("has_noticed", false)), "the third real spared body makes the Clear Frequency notice the player")
	var offers := HuntContracts.offers()
	check(offers.size() == 2, "that earned notice organically publishes the reciprocal top-tier market pair")
	var ascent_offers: Array = offers.filter(func(row: Dictionary): return str(row.get("patron_id", "")) == "clear_frequency")
	var descent_offers: Array = offers.filter(func(row: Dictionary): return str(row.get("patron_id", "")) == TheFourHorsemen.current_reign())
	check(ascent_offers.size() == 1 and str(ascent_offers[0].get("target_id", "")) == TheFourHorsemen.current_reign() and str(ascent_offers[0].get("block_kind", "")) == "frequency",
		"the ascent offer names the live CROWN holder as its exact frequency obstruction")
	check(descent_offers.size() == 1 and str(descent_offers[0].get("target_id", "")) == "clear_frequency" and str(descent_offers[0].get("block_kind", "")) == "aura",
		"the CROWN holder answers against the exact noticed aura through the same market")
	hunt._refresh_ascent_job_market()
	check(HuntContracts.offers().size() == 2 and WorldHistory.event_count("hunt_contract_published") == 2, "rechecking notice cannot duplicate either open contract")

	print("HUNT_CONTRACT_PUBLICATION_INTEGRATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
