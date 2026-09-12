extends Node

## O5.10 v2 verification. Enemies used to run on the older binary `staggered`
## lock alone — a hit either interrupted them outright or left no mark at all.
## This checks they now share the player's own footing meter: sub-threshold
## hits chip it, it recovers on its own, a parried attacker actually pays for
## the commitment, and stumbling stops a fresh attack from winding up.

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

	hunt._spawn_encounter_actor({"instance_id": "footing_probe", "kind": "hostile"}, hunt.player + Vector3(0, 0, 2.0))
	var actor: Dictionary = hunt.encounter_actors.back()

	check(is_equal_approx(hunt._actor_footing(actor), 1.0), "a fresh body starts with full footing")

	# --- a sub-stagger hit still costs footing, which it never used to ------
	var report := {"damage": 10.0, "impulse": 8.0, "damage_type": "cut", "weapon": "sword", "heavy": false}
	hunt._apply_combat_response(actor, report, {"pain": actor.anatomy.pain})
	check(hunt._actor_footing(actor) < 1.0, "a landed hit chips footing even when it does not stagger (%.2f)" % hunt._actor_footing(actor))
	check(str(actor.get("state", "")) != "staggered", "and a hit this light does not trigger the old hard lock")

	# --- footing recovers on its own -----------------------------------------
	var recovering := float(hunt._actor_footing(actor))
	for _tick in 30:
		hunt._update_encounter_actors(0.05)
	check(hunt._actor_footing(actor) > recovering, "footing comes back on its own (%.2f -> %.2f)" % [recovering, hunt._actor_footing(actor)])

	# --- a parry actually punishes them now, not a dead write ---------------
	actor["footing"] = 1.0
	hunt._actor_lose_footing(actor, 0.45, "TEST PARRY PUNISH")
	check(hunt._actor_footing(actor) < 0.6, "a parry-strength loss actually lands (%.2f)" % hunt._actor_footing(actor))

	# --- stumbling stops a fresh attack from winding up ----------------------
	actor["footing"] = 0.1
	actor["attack_time"] = 0.0
	var node := actor.node as Node3D
	node.global_position = hunt.player + Vector3(0, 0, 1.4)
	hunt._update_encounter_actors(0.3)
	check(is_equal_approx(float(actor.attack_time), 0.0), "a stumbling fighter cannot wind up a fresh attack (%.2f)" % float(actor.attack_time))

	# --- and attacks that do land hit softer and slower while off balance ---
	actor["footing"] = 1.0
	var full_cycle: float = hunt._actor_attack_cycle(actor)
	var full_damage: int = hunt._actor_attack_damage(actor)
	actor["footing"] = 0.2
	check(hunt._actor_attack_cycle(actor) > full_cycle, "an off-balance fighter winds up slower (%.2f vs %.2f)" % [hunt._actor_attack_cycle(actor), full_cycle])
	check(hunt._actor_attack_damage(actor) < full_damage, "and hits softer (%d vs %d)" % [hunt._actor_attack_damage(actor), full_damage])

	print("ENEMY_FOOTING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
