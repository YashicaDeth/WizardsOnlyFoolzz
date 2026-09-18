extends Node

## F10.4. A real escaped person, already concluded to be a rival, re-enters the
## production encounter list. The return keeps their identity and population
## count while mounting the adaptation derived from the body the player damaged.

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

	var subject_id := "return_probe_actor"
	WorldHistory.register_subject(subject_id, {
		"name": "Road Knife Returned", "kind": "person", "role": "TOLL KNIFE",
		"elo": 1170, "status": "escaped", "is_rival": true,
		"rival_returns": 0,
		"rival_adaptation": {
			"kind": "prosthetic", "zone": "left_arm",
			"item": "industrial torque arm", "response": "replaces the limb the player took",
		},
		"anatomy_state": {
			"zones": {"left_arm": {"health": 0.0}}, "organs": {},
			"severed": ["left_arm"], "wounds": [], "cybernetics": [],
		},
	})
	var population_before := WorldHistory.all_subjects().size()
	check(hunt._spawn_returning_rival(),
		"the live Hunt spends an open population slot on the escaped rival")
	var matches: Array = hunt.encounter_actors.filter(func(actor: Dictionary):
		return str(actor.get("subject_id", "")) == subject_id)
	check(matches.size() == 1,
		"the exact saved person returns as one ordinary encounter actor")
	if not matches.is_empty():
		var actor: Dictionary = matches[0]
		var installed: Dictionary = actor.rig.anatomy.installed_parts.get("left_arm", {})
		var arm := actor.rig.parts.get("left_arm") as MeshInstance3D
		var hardware := arm.get_node_or_null("InstalledHardware") if arm != null else null
		check(str(installed.get("name", "")).contains("industrial torque arm"),
			"the returned anatomy owns the prosthetic derived from the lost arm")
		check(hardware != null and hardware is MeshInstance3D and (hardware as MeshInstance3D).mesh != null,
			"that adaptation is visible geometry mounted on the returned arm")
		var arm_state: Dictionary = actor.rig.anatomy.zones.get("left_arm", {})
		check(not actor.rig.severed.has("left_arm") and float(arm_state.get("health", 0.0)) > 0.0,
			"the replacement restores some real limb function instead of decorating a missing arm")
		var label := actor.node.get_node_or_null("Identity") as Label3D
		check(label != null and label.text.contains("RETURNED RIVAL"),
			"the same body's world label makes the return readable at fighting distance")
	check(WorldHistory.all_subjects().size() == population_before,
		"returning reuses the existing person rather than generating a rival template")
	var saved := WorldHistory.subject(subject_id)
	check(str(saved.get("status", "")) == "hunting" and int(saved.get("rival_returns", 0)) == 1,
		"the return is durable state on that exact person")
	check(WorldHistory.event_count("rival_returned_to_hunt") == 1 and int(WorldHistory.get("_ledger_batch_depth")) == 0,
		"the restored body, rival state and visible return close as one world transaction")
	var remembered: Array = (WorldHistory.subject("player").get("hunted_by", []) as Array)
	check(remembered.any(func(entry: Dictionary):
		return str(entry.get("hunter_id", "")) == subject_id and str(entry.get("reason", "")) == "returning_rival"),
		"the player remembers the exact returning person as a hunter")
	check(not hunt._spawn_returning_rival(),
		"a rival already present cannot be duplicated by the maintenance loop")

	print("HUNT_RIVAL_RETURN_INTEGRATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
