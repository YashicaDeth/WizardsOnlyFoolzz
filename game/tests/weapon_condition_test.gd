extends Node

## AN2.4. The weapon's own condition rides on the same object — a bent blade
## swings wrong. Every connecting hit wears the current weapon a little,
## hitting something resistant (AN2.3's own `absorbed`) wears it more, and
## the arm's real stiffness (what `_carry_current_weapon()` hands
## `LimbMomentum`) actually drops as condition does. Bare hands and a
## carried limb are not in this system at all.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## AN2.5 landed alongside this test: a weapon on `GRIP_CYCLE` also carries its
## current grip's own `control` multiplier on top of condition. Read live
## rather than hardcoded, so a retuned grip value cannot make this test lie
## about what "full stiffness" actually means.
func expected_stiffness(hunt, weapon_id: String, condition: float) -> float:
	var base: float = hunt.WEAPON_BASE_STIFFNESS * lerpf(0.45, 1.0, condition)
	if hunt.GRIP_CYCLE.has(weapon_id):
		var grip_spec: Dictionary = HeldGear.GRIPS.get(hunt.current_grip, {})
		base *= float(grip_spec.get("control", 1.0))
	return base


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	hunt._equip_weapon(0)
	hunt._carry_current_weapon()
	check(is_equal_approx(hunt.arsenal.weapon_condition("sword"), 1.0), "a fresh sword starts at full condition")
	check(is_equal_approx(hunt.arm.stiffness, expected_stiffness(hunt, "sword", 1.0)), "and swings at full stiffness (%.2f)" % hunt.arm.stiffness)

	hunt.player_body.position = Vector3(175, 0.9, 125)
	hunt.player = hunt.player_body.position + Vector3.UP * 0.6
	hunt.yaw = 0.0
	hunt.pitch = 0.0

	# A bare, unarmoured hit: only the baseline wear, no `absorbed` on top.
	hunt._spawn_encounter_actor({"instance_id": "wear_bare", "kind": "hostile"}, hunt.player + Vector3(0, -0.5, 3))
	var bare: Dictionary = hunt.encounter_actors.back()
	bare.node.position = hunt.player + Vector3(0, -0.5, 3)
	await get_tree().physics_frame
	hunt._attack_nearest_encounter_actor({"damage": 20.0, "impulse": 10.0, "damage_type": "cut", "range": 9.0, "weapon": "sword"})
	var after_bare: float = hunt.arsenal.weapon_condition("sword")
	check(after_bare < 1.0, "a connecting hit actually wears the sword (%.4f)" % after_bare)
	check(is_equal_approx(hunt.arm.stiffness, expected_stiffness(hunt, "sword", after_bare)), "and the arm's real stiffness reflects that condition immediately")

	# The same blow through real plate wears it further than the bare hit did.
	var wear_from_bare_hit: float = 1.0 - after_bare
	hunt._spawn_encounter_actor({"instance_id": "wear_armoured", "kind": "hostile"}, hunt.player + Vector3(0, -0.5, 2))
	var armoured: Dictionary = hunt.encounter_actors.back()
	armoured.node.position = hunt.player + Vector3(0, -0.5, 2)
	var hit_zone := str((bare.anatomy.wounds.back() as Dictionary).get("zone", "torso"))
	armoured.anatomy.install_part(hit_zone, {"id": "test plate", "zone": hit_zone, "armor": 0.4, "max_condition": 100.0, "condition": 100.0})
	await get_tree().physics_frame
	hunt._attack_nearest_encounter_actor({"damage": 20.0, "impulse": 10.0, "damage_type": "cut", "range": 9.0, "weapon": "sword"})
	var wear_from_armoured_hit: float = after_bare - hunt.arsenal.weapon_condition("sword")
	check(wear_from_armoured_hit > wear_from_bare_hit, "hitting real plate wears the edge more than hitting nothing did (%.4f vs %.4f)" % [wear_from_armoured_hit, wear_from_bare_hit])

	# Bare hands and a carried limb are outside this system entirely.
	var before_fists: float = hunt.arsenal.weapon_condition("sword")
	hunt._put_the_weapons_down()
	hunt._wear_current_weapon("hands", 0.5)
	check(is_equal_approx(hunt.arsenal.weapon_condition("sword"), before_fists), "throwing a fist does not wear the sword sitting unused")

	if failures.is_empty():
		print("weapon condition: a bent blade actually swings wrong")
		get_tree().quit(0)
	else:
		print("weapon condition FAILURES: ", failures)
		get_tree().quit(1)
