extends Node

## The tiers in the real Hunt (Greg, 24 September): enemies carry a tier by
## who they are, show their swing side as a telegraph, defend by tier, are
## always open mid-swing, and a quiet fight ends in a readout.

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
	hunt.third_person = true
	hunt.lock_target = ""
	var at: Vector3 = hunt.player + Vector3(0, -0.5, 2.0)
	hunt._spawn_encounter_actor({"instance_id": "tier_elite", "kind": "hostile", "tier": "elite"}, at)
	var elite: Dictionary = hunt.encounter_actors.back()
	elite.node.position = at
	check(str(elite.get("tier", "")) == "elite", "an encounter can name its tier")
	hunt._spawn_encounter_actor({"instance_id": "plain_hostile", "kind": "hostile"}, at + Vector3(30, 0, 30))
	check(str(hunt.encounter_actors.back().get("tier", "")) == "hunter", "an ordinary hostile fights as a hunter")
	await get_tree().physics_frame
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt._toggle_lock()
	hunt.player_unseen = false
	# The telegraph shows only once the wind-up passes the tier's point.
	var cycle: float = hunt._actor_attack_cycle(elite)
	elite["attack_side"] = "left"
	elite["attack_time"] = cycle * 0.3
	hunt._show_telegraph(elite, elite.node, false)
	var mark = elite.get("telegraph_mark")
	check(mark == null or not mark.visible, "no telegraph early in an elite's wind-up")
	hunt._show_telegraph(elite, elite.node, true)
	mark = elite.get("telegraph_mark")
	check(mark != null and str(mark.text).contains("LEFT"), "the telegraph names the side (%s)" % (mark.text if mark else "none"))
	# Mid-swing an elite is open: the blow lands every time.
	elite["attack_time"] = cycle * 0.95
	var wounds: int = elite.anatomy.wounds.size()
	hunt._equip_weapon(0)
	hunt._attack_nearest_encounter_actor({"damage": 20.0, "impulse": 10.0, "damage_type": "cut", "range": 6.0, "weapon": "cleaver"})
	check(elite.anatomy.wounds.size() > wounds and int(hunt.fight_stats.get("punished", 0)) == 1, "a fighter caught mid-swing takes the blow")
	# Out of their swing, an elite stops some: over many swings, fewer land.
	elite["attack_time"] = 0.0
	var landed_before := int(hunt.fight_stats.get("landed", 0))
	for _swing in 20:
		hunt._attack_nearest_encounter_actor({"damage": 0.1, "impulse": 0.0, "damage_type": "cut", "range": 6.0, "weapon": "cleaver"})
	var stopped := int(hunt.fight_stats.get("they_blocked", 0)) + int(hunt.fight_stats.get("they_parried", 0))
	check(stopped > 0 and int(hunt.fight_stats.landed) - landed_before < 20, "an elite blocks or turns some swings (%d of 20 stopped)" % stopped)
	# The fight goes quiet: a readout.
	hunt._fight_quiet = 0.01
	hunt._tick_fight(0.05)
	check(hunt.fight_readout != null and hunt.fight_readout.visible and hunt.fight_readout.text.contains("FIGHT OVER"), "a quiet fight ends in a readout")
	check(WorldHistory.event_count("fight_summarised") == 1, "and the world keeps it")
	if hunt.fight_readout != null:
		print(hunt.fight_readout.text)
	print("COMBAT_TIERS_HUNT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
