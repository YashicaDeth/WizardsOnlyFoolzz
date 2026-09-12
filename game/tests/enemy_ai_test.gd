extends Node

## O4.1/O4.2 verification. Neither was a tuning question — there was no
## commitment punishment and no spacing at all, just every hostile walking
## straight to the same 3 m ring and standing there on its own clock.

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

	# O4.1. A fresh actor already in range advances its own attack clock at a
	# fixed rate; a player mid-swing cannot cancel or guard, so that same actor
	# should press the opening instead.
	hunt._spawn_encounter_actor({"instance_id": "presser", "kind": "hostile"}, hunt.player + Vector3(0, -0.5, 2.0))
	var presser: Dictionary = hunt.encounter_actors.back()
	presser.node.position = hunt.player + Vector3(0, -0.5, 2.0)
	await get_tree().physics_frame

	hunt.strike_windup = -1.0
	presser.attack_time = 0.0
	hunt._update_encounter_actors(0.2)
	var baseline: float = float(presser.attack_time)
	check(is_equal_approx(baseline, 0.2), "an unpressured hostile advances its attack clock at the normal rate (%.2f)" % baseline)

	hunt.strike_windup = 0.1
	presser.attack_time = 0.0
	hunt._update_encounter_actors(0.2)
	var pressed: float = float(presser.attack_time)
	check(pressed > baseline * 1.5, "the player committing to a swing makes the same hostile press harder (%.2f vs %.2f)" % [pressed, baseline])
	presser.attack_time = 0.0
	hunt.strike_windup = -1.0

	# O4.2. A second hostile arriving while the first already holds the melee
	# opening should orbit at a stand-off distance rather than stacking into
	# the same 3 m ring.
	hunt._spawn_encounter_actor({"instance_id": "outer", "kind": "hostile"}, hunt.player + Vector3(6, -0.5, 6))
	var outer: Dictionary = hunt.encounter_actors.back()
	outer.node.position = hunt.player + Vector3(6, -0.5, 6)
	check(hunt._melee_slot_taken(), "the first hostile already holding melee range is read as the taken slot")

	for _tick in 240:
		hunt._update_encounter_actors(0.05)
	var final_gap: float = hunt.player.distance_to(outer.node.global_position)
	check(final_gap > 4.2, "the second hostile settles at a stand-off distance rather than stacking on the first (%.2fm)" % final_gap)
	check(hunt.player.distance_to(presser.node.global_position) <= 3.0, "the actor already holding the opening is undisturbed by the second one orbiting")

	print("ENEMY_AI_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
