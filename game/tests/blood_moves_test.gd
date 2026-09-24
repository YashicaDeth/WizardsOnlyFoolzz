extends Node

## The blood-tree moves in the real Hunt (Greg, 24 September): Blade FEINT and
## COMBO, Meat RIPOSTE, Iron HIP COUNTER, Hush BACKSTAB. Each takes the
## defence away from one blow, and only once its node is bought.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func swing(hunt) -> void:
	hunt._attack_nearest_encounter_actor({"damage": 0.1, "impulse": 0.0, "damage_type": "cut", "range": 6.0, "weapon": "cleaver"})


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	hunt.third_person = true
	hunt.lock_target = ""
	var at: Vector3 = hunt.player + Vector3(0, -0.5, 2.0)
	hunt._spawn_encounter_actor({"instance_id": "moves_elite", "kind": "hostile", "tier": "elite"}, at)
	var elite: Dictionary = hunt.encounter_actors.back()
	elite.node.position = at
	await get_tree().physics_frame
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt._toggle_lock()
	hunt.player_unseen = false
	hunt._equip_weapon(0)
	for node_id in ["feint", "combo", "riposte", "hip_counter", "backstab"]:
		check(BloodTrees.NODES.has(node_id) and not str(BloodTrees.NODES[node_id].get("flag", "")).is_empty(), "the tree has %s" % node_id.to_upper())
	var ledger: BloodLedger = hunt.blood_ledger

	# FEINT: not without the node; with it, the wind-up is cancelled for stamina.
	hunt.strike_windup = 0.3
	hunt.pending_attack = {"kind": "melee"}
	check(not hunt.try_feint() and hunt.strike_windup > 0.0, "no feint before the node is bought")
	ledger.state.unlocked = ["first_cut", "feint", "combo", "knuckle", "riposte", "steady_hand", "hip_counter"]
	var stamina_before: float = hunt.stamina
	check(hunt.try_feint() and hunt.strike_windup < 0.0 and hunt.pending_attack.is_empty(), "guard in the wind-up feints: the swing never comes")
	check(hunt.stamina < stamina_before, "a feint costs stamina")
	check(bool(elite.get("baited", false)), "the fighter in reach bites")
	elite["attack_time"] = 0.0
	swing(hunt)
	check(int(hunt.fight_stats.get("baited", 0)) == 1 and not bool(elite.get("baited", false)), "the next blow finds them open, once")

	# RIPOSTE: after a parry the next blow cannot be stopped, one blow only.
	hunt._after_parry(elite, hunt.encounter_actors.find(elite))
	swing(hunt)
	check(int(hunt.fight_stats.get("riposte", 0)) == 1, "a riposte goes straight through")
	check(hunt.riposte_until < 0.0, "and it is spent")

	# COMBO: two clean hits, then the third quick one always lands.
	hunt.combo_chain = {"subject": "", "count": 0, "at": -99.0}
	var cycle: float = hunt._actor_attack_cycle(elite)
	for _hit in 2:
		elite["attack_time"] = cycle * 0.95
		swing(hunt)
	elite["attack_time"] = 0.0
	swing(hunt)
	check(int(hunt.fight_stats.get("combo", 0)) == 1, "the third quick hit is a combo")
	check(int(hunt.combo_chain.count) == 0, "and the chain starts over")
	# Out of an elite's swing, without a move, they still stop some.
	var stopped_before := int(hunt.fight_stats.get("they_blocked", 0)) + int(hunt.fight_stats.get("they_parried", 0))
	ledger.state.unlocked = []
	for _i in 12:
		elite["attack_time"] = 0.0
		swing(hunt)
	check(int(hunt.fight_stats.get("they_blocked", 0)) + int(hunt.fight_stats.get("they_parried", 0)) > stopped_before, "without the moves an elite still defends")

	# HIP COUNTER: a parry with a gun in hand shoots them, and spends a round.
	ledger.state.unlocked = ["steady_hand", "hip_counter"]
	hunt.arsenal.select_weapon("sidearm")
	var loaded := int(hunt.arsenal.ammo.sidearm.loaded)
	var wounds: int = elite.anatomy.wounds.size()
	hunt._after_parry(elite, hunt.encounter_actors.find(elite))
	check(int(hunt.arsenal.ammo.sidearm.loaded) == loaded - 1, "the counter spends a round")
	check(elite.anatomy.wounds.size() > wounds and int(hunt.fight_stats.get("hip_counter", 0)) == 1, "and it lands point blank")
	hunt.arsenal.select_weapon("sword")
	check(not hunt.hip_counter(elite, hunt.encounter_actors.find(elite)), "no counter with a blade in hand")

	# BACKSTAB: an unaware fighter, facing away, is taken down.
	hunt._spawn_encounter_actor({"instance_id": "moves_mark", "kind": "hostile", "tier": "elite"}, at + Vector3(20, 0, 0))
	var mark: Dictionary = hunt.encounter_actors.back()
	mark["tracking_player"] = false
	mark["tracking_light"] = false
	mark["state"] = "idle"
	elite.node.position = at + Vector3(40, 0, 40)
	mark.node.position = at
	await get_tree().physics_frame
	mark.node.look_at(mark.node.global_position + Vector3(0, 0, 5), Vector3.UP)
	check(hunt._unaware_and_behind(mark), "a fighter facing away who hasn't noticed you is open from behind")
	mark.node.look_at(mark.node.global_position + Vector3(0, 0, -5), Vector3.UP)
	check(not hunt._unaware_and_behind(mark), "facing you, they are not")
	mark.node.look_at(mark.node.global_position + Vector3(0, 0, 5), Vector3.UP)
	ledger.state.unlocked = ["soft_foot", "backstab"]
	hunt.lock_target = ""
	var mark_wounds: int = mark.anatomy.wounds.size()
	hunt._attack_nearest_encounter_actor({"damage": 20.0, "impulse": 10.0, "damage_type": "cut", "range": 6.0, "weapon": "cleaver"})
	check(int(hunt.fight_stats.get("backstab", 0)) == 1 and mark.anatomy.wounds.size() > mark_wounds, "the backstab lands")
	check(bool(mark.get("tracking_player", false)), "and now they know you are there")
	check(Engine.get_main_loop() != null and hunt.fight_summary(hunt.fight_stats).contains("MOVES"), "the fight readout counts the moves")
	print("BLOOD_MOVES_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
