extends Node

## AG5.31. Named workers make the yard inhabited without making every nearby
## person an enemy. Deliberate violence still provokes the exact person hit.

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
	await get_tree().physics_frame
	var workers: Array[Dictionary] = []
	for actor: Dictionary in hunt.encounter_actors:
		if str(actor.get("encounter_id", "")).begins_with("boneyard_worker_"):
			workers.append(actor)
	check(workers.size() == hunt.POPULATION_POSTS.size(), "every named yard post is still physically staffed")
	check(workers.all(func(actor: Dictionary): return str(actor.disposition) == "neutral" and str(actor.state) == "idle"), "yard workers begin as neutral inhabitants rather than a five-person ambush")

	print("AG5.31 - neutral inhabitants do not contribute hostile sight pressure")
	var worker := workers[0]
	(worker.node as Node3D).position = hunt.player + Vector3(0, -0.5, 2.0)
	worker["tracking_player"] = true
	worker["tracking_light"] = true
	hunt._update_perception(0.1)
	check(not bool(worker.tracking_player) and not bool(worker.tracking_light), "neutral workers are not sensors for the hostile network")
	check(str(worker.disposition) == "neutral", "mere proximity does not change allegiance")

	print("AG5.31 - striking first provokes only the person actually hit")
	for actor: Dictionary in hunt.encounter_actors:
		if actor != worker:
			actor.disposition = "friendly"
	hunt.player_body.position = Vector3(0, 0.9, 19)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	(worker.node as Node3D).position = hunt.player + Vector3(0, -0.5, 2.0)
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	var wounds_before: int = worker.anatomy.wounds.size()
	var landed: bool = hunt._attack_nearest_encounter_actor({
		"damage": 8.0, "impulse": 3.0, "damage_type": "cut", "range": 4.1, "weapon": "test edge",
	})
	check(landed and worker.anatomy.wounds.size() > wounds_before, "a deliberately aimed melee swing can still wound a neutral worker")
	check(str(worker.disposition) == "hostile" and str(worker.state) in ["hunting", "staggered"], "the struck worker becomes an active combatant")
	check(bool(worker.tracking_player) and float(worker.notice_remaining) <= 0.0, "provocation skips the polite detection delay for that exact body")
	check(str(WorldHistory.subject(str(worker.subject_id)).get("status", "")) == "provoked", "the person remembers who initiated the fight")
	check(workers.slice(1).all(func(actor: Dictionary): return str(actor.disposition) == "friendly"), "the hit does not globally enlist every worker into the fight")

	print("ENCOUNTER_PRESSURE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
