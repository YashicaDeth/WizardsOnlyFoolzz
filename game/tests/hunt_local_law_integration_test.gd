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

	print("HUNT_LOCAL_LAW_INTEGRATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
