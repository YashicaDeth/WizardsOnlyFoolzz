extends Node

## The production seam AE1.4/AE1.5 was missing: Hunt resolutions used to write
## straight into global history and never passed through witnesses or the land
## they happened on. Drive one real resolution through the real Hunt scene and
## prove its delayed report lands on the same holding MAP/INDEX/Board use.

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
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	# Tunnel Mouth is Gate Lantern ground. Their positive Tree position reads an
	# execution as an offence, making it the cleanest two-sided proof that place,
	# witness and local values all participate in the result.
	var at := Vector3(65.0, 1.0, 115.0)
	hunt.player_body.position = at + Vector3(0, 0, 1.4)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	for existing: Dictionary in hunt.encounter_actors:
		(existing.node as Node3D).position = Vector3(-220, 1, -170)

	hunt._spawn_encounter_actor({
		"instance_id": "law_target", "kind": "hostile", "display_name": "Kest Vane",
		"role": "GATE LANTERN DEBTOR", "summary": "Caught on Lantern ground.",
	}, at)
	var target: Dictionary = hunt.encounter_actors.back()
	target.node.position = at
	WorldHistory.amend_subject(str(target.subject_id), {"faction_id": "gate_lanterns", "faction": "Gate Lanterns"})

	hunt._spawn_encounter_actor({
		"instance_id": "law_witness", "kind": "hostile", "display_name": "Orra Wick",
		"role": "GATE LANTERN WITNESS", "summary": "Close enough to carry the account home.",
	}, at + Vector3(3, 0, 0))
	var witness: Dictionary = hunt.encounter_actors.back()
	witness.node.position = at + Vector3(3, 0, 0)
	WorldHistory.amend_subject(str(witness.subject_id), {"faction_id": "gate_lanterns", "faction": "Gate Lanterns"})

	target.anatomy.go_down()
	hunt.resolution_target = str(target.subject_id)
	hunt._resolve_downed("execute")
	var resolutions := WorldHistory.events.filter(func(event: Dictionary):
		return str(event.get("type", "")) == "npc_resolution" and str((event.get("details", {}) as Dictionary).get("subject_id", "")) == str(target.subject_id))
	check(resolutions.size() == 1, "the production resolution writes one canonical npc_resolution event")
	var details: Dictionary = (resolutions[0].get("details", {}) as Dictionary) if not resolutions.is_empty() else {}
	check(str(details.get("place_id", "")) == "ashbloom:tunnel_mouth" and str(details.get("held_by", "")) == "gate_lanterns",
		"the act records the real holding and its real holder from world position")
	check((details.get("witnesses", []) as Array).has(str(witness.subject_id)),
		"the nearby living faction member is attached through WitnessLedger")
	check(hunt.witness_ledger.in_flight().size() == 1 and WorldHistory.event_count("local_unrest") == 0,
		"law does not know instantly; the report is genuinely in flight")

	var landed: Array = hunt.witness_ledger.tick(WitnessLedger.REPORT_DELAY * 2.0)
	hunt._answer_local_reports(landed)
	check(landed.size() == 1 and hunt.witness_ledger.faction_knows("gate_lanterns", int(resolutions[0].sequence)),
		"the witness's own faction learns only after the report delay")
	check(float(WorldHistory.subject("ashbloom:tunnel_mouth").get("unrest", 0.0)) > 0.0,
		"the canonical Tunnel Mouth record remembers the witnessed wrong locally")
	check(WorldHistory.events.any(func(event: Dictionary):
		return str(event.get("type", "")) == "local_unrest" and str((event.get("details", {}) as Dictionary).get("place_id", "")) == "ashbloom:tunnel_mouth"),
		"the resulting unrest is attributable to the same holding in world history")

	# F1.3 / AE10.10. Exercise the production death seam, not the ledger helper
	# in isolation: a physical witness carrying a fresh account dies in the Hunt
	# before the delay, and that exact account must never become faction knowledge.
	hunt._spawn_encounter_actor({
		"instance_id": "cut_witness", "kind": "hostile", "display_name": "Sable Rook",
		"role": "GATE LANTERN COURIER", "summary": "Carrying a report home.",
	}, at + Vector3(5, 0, 0))
	var cut_witness: Dictionary = hunt.encounter_actors.back()
	WorldHistory.amend_subject(str(cut_witness.subject_id), {"faction_id": "gate_lanterns", "faction": "Gate Lanterns"})
	var cut_event: Dictionary = hunt.witness_ledger.record("npc_resolution", {
		"subject_id": "cut_report_target", "actor": "player", "outcome": "execute",
		"place_id": "ashbloom:tunnel_mouth", "held_by": "gate_lanterns",
	}, [str(cut_witness.subject_id)])
	check(hunt.witness_ledger.in_flight().any(func(report: Dictionary): return int(report.sequence) == int(cut_event.sequence)),
		"the physical witness is carrying a distinct report before they die")
	cut_witness.rig.execute()
	hunt._kill_encounter_actor(hunt.encounter_actors.find(cut_witness), "witness_silenced")
	hunt.witness_ledger.tick(WitnessLedger.REPORT_DELAY * 2.0)
	check(not hunt.witness_ledger.faction_knows("gate_lanterns", int(cut_event.sequence)),
		"killing the physical witness cuts their report before the faction can learn it")
	check(WorldHistory.events.any(func(event: Dictionary):
		return str(event.get("type", "")) == "report_cut" and str((event.get("details", {}) as Dictionary).get("subject", "")) == str(cut_witness.subject_id)),
		"the silencing is attributable in history rather than silently deleting testimony")

	# The other physical way to stop an account: buy it from the exact body
	# carrying it while they are held in a clinch. Drive the real contextual B
	# binding so smoking's ordinary grip-cycle use of B cannot mask a dead route.
	hunt._spawn_encounter_actor({
		"instance_id": "paid_witness", "kind": "hostile", "display_name": "Pell Writ",
		"role": "GATE LANTERN RUNNER", "summary": "Knows what an account costs.",
	}, at + Vector3(6, 0, 0))
	var paid_witness: Dictionary = hunt.encounter_actors.back()
	WorldHistory.amend_subject(str(paid_witness.subject_id), {"faction_id": "gate_lanterns", "faction": "Gate Lanterns"})
	var paid_event: Dictionary = hunt.witness_ledger.record("npc_resolution", {
		"subject_id": "paid_report_target", "actor": "player", "outcome": "execute",
		"place_id": "ashbloom:tunnel_mouth", "held_by": "gate_lanterns",
	}, [str(paid_witness.subject_id)])
	WorldHistory.amend_subject("inventory", {"rust_scrip": WitnessLedger.REPORT_PRICE * 2})
	hunt.kill_cam.cancel()
	hunt.grapple_target = str(paid_witness.subject_id)
	var buy_key := InputEventKey.new()
	buy_key.keycode = KEY_B
	buy_key.pressed = true
	hunt._unhandled_input(buy_key)
	hunt.grapple_target = ""
	check(hunt.witness_ledger.reports_carried_by(str(paid_witness.subject_id)) == 0,
		"the contextual B binding buys the report from the physically held witness")
	check(int(WorldHistory.subject("inventory").get("rust_scrip", -1)) == WitnessLedger.REPORT_PRICE,
		"the production exchange spends the real persistent rust-scrip wallet")
	var bought_events := WorldHistory.events.filter(func(event: Dictionary):
		return str(event.get("type", "")) == "report_bought" and int(paid_event.sequence) in ((event.get("details", {}) as Dictionary).get("source_sequences", []) as Array))
	check(bought_events.size() == 1 and str((bought_events[0].get("details", {}) as Dictionary).get("action_id", "")) != "",
		"buying testimony produces one attributable player-action receipt")
	hunt.witness_ledger.tick(WitnessLedger.REPORT_DELAY * 2.0)
	check(not hunt.witness_ledger.faction_knows("gate_lanterns", int(paid_event.sequence)),
		"the bought physical account never becomes faction knowledge")
	(paid_witness.node as Node3D).position = Vector3(-220, 1, -170)

	# One incident is memory, not an enemy printer. Repeated distinct witnessed
	# acts cross the real threshold and should finally put the holder's own people
	# onto the road through the ordinary encounter pipeline.
	hunt.kill_cam.cancel()
	for repeat in 3:
		var instance_id := "law_target_repeat_%d" % repeat
		hunt._spawn_encounter_actor({
			"instance_id": instance_id, "kind": "hostile", "display_name": "Repeat Debtor %d" % repeat,
			"role": "GATE LANTERN DEBTOR", "summary": "Another witnessed decision on Lantern ground.",
		}, at)
		var repeated: Dictionary = hunt.encounter_actors.back()
		repeated.node.position = at
		WorldHistory.amend_subject(str(repeated.subject_id), {"faction_id": "gate_lanterns", "faction": "Gate Lanterns"})
		repeated.anatomy.go_down()
		hunt.resolution_target = str(repeated.subject_id)
		hunt._resolve_downed("execute")
		var next_reports: Array = hunt.witness_ledger.tick(WitnessLedger.REPORT_DELAY * 2.0)
		hunt._answer_local_reports(next_reports)
		hunt.kill_cam.cancel()
	check(WorldHistory.event_count("law_dispatched") == 1 and WorldHistory.event_count("local_law_team_dispatched") == 1,
		"distinct local wrongs cross the threshold once and commission one physical team")
	var enforcers: Array = hunt.encounter_actors.filter(func(actor: Dictionary):
		return str(actor.get("encounter_id", "")).begins_with("local_law_"))
	check(enforcers.size() == 2, "the holder sends a two-person team into the live encounter world")
	check(enforcers.all(func(actor: Dictionary):
		return str(WorldHistory.subject(str(actor.subject_id)).get("faction_id", "")) == "gate_lanterns" and actor.rig is BaselineHuman),
		"both enforcers are persistent Gate Lantern people with full anatomy, not law markers")
	var remembered_law: Array = (WorldHistory.subject("player").get("hunted_by", []) as Array).filter(func(entry: Dictionary):
		return str(entry.get("reason", "")) == "local_law")
	check(remembered_law.size() == 2 and enforcers.all(func(actor: Dictionary):
		return remembered_law.any(func(entry: Dictionary): return str(entry.get("hunter_id", "")) == str(actor.subject_id))),
		"the player remembers both exact officers as hunters rather than a generic wanted level")
	check(str((WorldHistory.subject("ashbloom:tunnel_mouth").get("active_law_dispatch", {}) as Dictionary).get("status", "")) == "active",
		"the active warrant persists on the holding instead of depending on the rolling event log")
	var distance_before := (enforcers[0].node as Node3D).global_position.distance_to(at) if not enforcers.is_empty() else 0.0
	for _step in 3:
		hunt._update_encounter_actors(0.5)
	var distance_after := (enforcers[0].node as Node3D).global_position.distance_to(at) if not enforcers.is_empty() else 0.0
	check(distance_after < distance_before, "the dispatched team physically follows a route to the recorded scene instead of knowing the player's new position")
	for index in range(hunt.encounter_actors.size() - 1, -1, -1):
		var candidate: Dictionary = hunt.encounter_actors[index]
		if not str(candidate.get("encounter_id", "")).begins_with("local_law_"):
			continue
		(candidate.node as Node3D).queue_free()
		hunt.encounter_actors.remove_at(index)
	await get_tree().process_frame
	hunt._restore_local_law_teams()
	var restored: Array = hunt.encounter_actors.filter(func(actor: Dictionary):
		return str(actor.get("encounter_id", "")).begins_with("local_law_"))
	check(restored.size() == 2, "an unresolved physical law team restores from world history after the scene is rebuilt")

	# AE10.13. The team was previously incapable of completing its own job:
	# every ordinary actor attack hard-clamped the player to one health. Put one
	# restored officer in a real melee opening and prove the finishing blow uses
	# the same persistent capture route as the authored rival, rather than death,
	# reload, or a decorative arrest prompt.
	for candidate: Dictionary in hunt.encounter_actors:
		(candidate.node as Node3D).position = Vector3(-220, 1, -170)
	(witness.node as Node3D).position = hunt.player + Vector3(0, -0.5, 1.5)
	witness["attack_time"] = hunt._actor_attack_cycle(witness) + 0.1
	hunt.health = 1
	hunt.dodge_remaining = 0.0
	hunt.guarding = false
	hunt._update_encounter_actors(0.05)
	check(hunt.health == 1 and WorldHistory.event_count("player_captured") == 0,
		"an ordinary hostile still cannot counterfeit a law arrest or kill the undying player")
	for candidate: Dictionary in hunt.encounter_actors:
		(candidate.node as Node3D).position = Vector3(-220, 1, -170)
	var arrestor: Dictionary = restored[0] if not restored.is_empty() else {}
	if not arrestor.is_empty():
		(arrestor.node as Node3D).position = hunt.player + Vector3(0, -0.5, 1.5)
		arrestor["law_arrived"] = true
		arrestor["tracking_player"] = true
		arrestor["attack_time"] = hunt._actor_attack_cycle(arrestor) + 0.1
		hunt.health = 1
		hunt.dodge_remaining = 0.0
		hunt.guarding = false
		hunt._update_encounter_actors(0.05)
	var arrested_player := WorldHistory.subject("player")
	check(str(arrested_player.get("status", "")) == "shackled",
		"a law enforcer's finishing blow arrests the undying player instead of killing them")
	check(str(arrested_player.get("captor_id", "")) == str(arrestor.get("subject_id", "")),
		"custody names the exact physical officer who landed the finishing blow")
	check(str(arrested_player.get("held_at", "")) == "ashbloom:tunnel_mouth",
		"local arrest holds the player in the jurisdiction that issued the warrant")
	check(WorldHistory.event_count("player_captured") == 1 and WorldHistory.event_count("local_law_arrested_player") == 1,
		"the finishing blow writes one capture and one attributable local-law arrest")
	check(str((WorldHistory.subject("ashbloom:tunnel_mouth").get("active_law_dispatch", {}) as Dictionary).get("status", "")) == "arrested",
		"the warrant settles when its physical team takes the player into custody")
	if not arrestor.is_empty():
		hunt._update_encounter_actors(10.0)
	check(WorldHistory.event_count("player_captured") == 1 and WorldHistory.event_count("local_law_arrested_player") == 1,
		"custody is idempotent rather than arresting the same player every AI tick")

	print("HUNT_LOCAL_LAW_INTEGRATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
