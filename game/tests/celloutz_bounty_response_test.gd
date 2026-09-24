extends Node

const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

const FACILITY := preload("res://systems/facility_territory.gd")

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
	FACILITY.apply_event("opening_entered_pit")
	FACILITY.apply_event("derby_round_won")
	var first_area := FACILITY.publish_target_ping(Vector2(90, 3))
	var first_ping_events := WorldHistory.recent_events(8).filter(func(event: Dictionary): return str(event.get("type", "")) == "celloutz_target_area_published")
	check(first_ping_events.size() == 1 and str((first_ping_events[0] as Dictionary).get("details", {}).get("action_id", "")).begins_with("action_"),
		"the first corporate acquisition area receives one durable player-action receipt")
	check(PLAYER_ACTION_LEDGER.count("celloutz_target_area_published") == 1 and int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"the bounty mutation and its publication close as one persisted action")

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	hunt._maintain_celloutz_contractors()
	var first_team: Array = hunt.encounter_actors.filter(func(actor: Dictionary):
		return str(actor.get("encounter_id", "")).begins_with("celloutz_contract_1_"))
	check(first_team.size() == 2, "the first published target area dispatches one two-person recovery contract")
	check(WorldHistory.event_count("celloutz_repossession_team_dispatched") == 1 and int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"dispatch, response state and both persistent contractors close as one world transaction")
	var centre := Vector3(float(first_area.x), 0.0, float(first_area.z))
	check(first_team.all(func(actor: Dictionary):
		return (actor.node as Node3D).global_position.distance_to(centre) <= float(first_area.radius) * 1.15),
		"both contractors enter through the approximate area rather than at the player coordinate")
	check(first_team.all(func(actor: Dictionary):
		return str(WorldHistory.subject(str(actor.subject_id)).get("faction_id", "")) == "celloutz"),
		"the responders are named persistent CellOutz people, not anonymous map markers")
	var remembered_contractors: Array = (WorldHistory.subject("player").get("hunted_by", []) as Array).filter(func(entry: Dictionary):
		return str(entry.get("reason", "")) == "repossession_contract")
	check(remembered_contractors.size() == 2 and first_team.all(func(actor: Dictionary):
		return remembered_contractors.any(func(entry: Dictionary): return str(entry.get("hunter_id", "")) == str(actor.subject_id))),
		"the player carries both exact corporate hunters, not just the bounty that sent them")

	hunt._maintain_celloutz_contractors()
	check(hunt.encounter_actors.filter(func(actor: Dictionary):
		return str(actor.get("encounter_id", "")).begins_with("celloutz_contract_1_")).size() == 2,
		"ticking the response cannot duplicate a living team")
	FACILITY.publish_target_ping(Vector2(-150, 3))
	FACILITY.publish_target_ping(Vector2(-151, 4))
	check(PLAYER_ACTION_LEDGER.count("celloutz_target_area_published") == 2,
		"crossing a cell adds one receipt while consulting MAP again inside it adds none")
	hunt._maintain_celloutz_contractors()
	check(WorldHistory.event_count("celloutz_repossession_team_dispatched") == 1,
		"crossing another ping cell reroutes the live contract instead of printing enemies")

	for actor: Dictionary in first_team:
		WorldHistory.amend_subject(str(actor.subject_id), {"status": "dead"})
		actor["dead"] = true
	hunt._maintain_celloutz_contractors()
	var replacement: Array = hunt.encounter_actors.filter(func(actor: Dictionary):
		return str(actor.get("encounter_id", "")).begins_with("celloutz_contract_2_"))
	check(replacement.size() == 2 and WorldHistory.event_count("celloutz_repossession_team_dispatched") == 2 and int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"a later area commissions one replacement transaction only after the prior contract is resolved")

	print("CELLOUTZ_BOUNTY_RESPONSE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
