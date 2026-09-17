extends Node

## O3.1 verification. Mara's `enemy_health` used to be a flat counter that
## dropped by a fixed number per hit regardless of where — or, for the
## prosthetic surge, whether — the blow touched her rig. This checks the
## fight now actually reads her body: a devastated zone stops paying out, a
## fresh one does not, and every attack that lands leaves a real wound.

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

	check(is_equal_approx(hunt._rig_health_ratio(hunt.enemy_rig), 1.0), "an untouched body reads as fully intact")

	hunt._begin_canonical_encounter()
	check(hunt.enemy_health == hunt.enemy_health_max, "the encounter starts at full derived health")

	# --- a real melee hit lands on her rig and enemy_health follows it -----
	hunt.player = hunt.enemy.global_position + Vector3(0, 0, 2.5)
	hunt.yaw = PI
	hunt.pitch = 0.0
	hunt._resolve_strike()
	var expected: int = roundi(float(hunt.enemy_health_max) * hunt._rig_health_ratio(hunt.enemy_rig))
	check(hunt.enemy_health == expected, "enemy_health after a real hit matches her actual body ratio (%d vs %d)" % [hunt.enemy_health, expected])
	check(hunt.enemy_rig.anatomy.wounds.size() > 0, "the hit left a real wound on her rig, not just a number change")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0 and not bool(WorldHistory.get("_ledger_batch_dirty")), "the rival wound, memory and landed swing close as one outcome")

	# --- the prosthetic surge now wounds her too, instead of a silent -30 --
	var wounds_before: int = hunt.enemy_rig.anatomy.wounds.size()
	hunt.stamina = 100.0
	hunt._use_prosthetic_surge()
	check(hunt.enemy_rig.anatomy.wounds.size() > wounds_before, "the prosthetic surge leaves a wound on her body now")
	var expected_after_surge: int = roundi(float(hunt.enemy_health_max) * hunt._rig_health_ratio(hunt.enemy_rig))
	check(hunt.enemy_health == expected_after_surge, "and enemy_health still reads off the real ratio afterward")

	# --- diminishing returns on a zone that is already gone ----------------
	hunt.enemy_rig.anatomy.zones["left_arm"]["health"] = 0.0
	var ratio_arm_gone: float = hunt._rig_health_ratio(hunt.enemy_rig)
	hunt.enemy_rig.hit("left_arm", 40.0, 20.0, "blunt")
	var ratio_after_same_zone: float = hunt._rig_health_ratio(hunt.enemy_rig)
	check(is_equal_approx(ratio_arm_gone, ratio_after_same_zone), "hitting an already-destroyed zone again changes nothing further (%.4f vs %.4f)" % [ratio_arm_gone, ratio_after_same_zone])
	hunt.enemy_rig.hit("head", 20.0, 12.0, "blunt")
	var ratio_after_fresh_zone: float = hunt._rig_health_ratio(hunt.enemy_rig)
	check(ratio_after_fresh_zone < ratio_after_same_zone, "but spreading the damage to a fresh zone still costs her (%.4f vs %.4f)" % [ratio_after_fresh_zone, ratio_after_same_zone])

	print("RIVAL_BODY_HEALTH_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
