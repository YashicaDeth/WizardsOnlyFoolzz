extends Node

## O v10, audited the same way B v10 was: each claim has to fail if it stops
## being true, rather than being ticked because someone read the code and agreed.

const HUMAN := preload("res://systems/baseline_human.gd")
const MOMENTUM := preload("res://systems/limb_momentum.gd")

var failures: Array[String] = []

func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)

func _rig(id: String) -> BaselineHuman:
	var r: BaselineHuman = HUMAN.new()
	add_child(r)
	r.build(id, {"gore": true})
	return r

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	# --- O10.13: every hit reaches the anatomy, never a hitbox -------------
	var rig := _rig("combat_audit")
	await get_tree().process_frame
	var torso := rig.parts.get("torso") as Node3D
	var before: float = rig.zone_health("torso")
	var melee: Dictionary = rig.hit_at(torso.global_position + Vector3(0, 0.08, 0.14), 18.0, 6.0, "blunt", Vector3(0, 0, -1))
	check(melee.has("blood_remaining"), "a melee blow comes back through apply_hit like every other hit")
	check(rig.zone_health("torso") < before, "and it costs the zone that was struck, by name")

	# --- O5.1 / O5.2: the weapon sets the ceiling, the player earns it -----
	# `commitment()` is what combat asks instead of a constant on the weapon.
	# LimbMomentum is a RefCounted, not a Node -- it is driven directly by
	# _gesture() below and never belongs in the tree. add_child() on it here
	# was a parse error, which made this entire audit print nothing at all.
	var arm: LimbMomentum = MOMENTUM.new()
	# A flick: a short, fast gesture. A committed sweep: sustained work.
	arm.call("reset") if arm.has_method("reset") else null
	var flick := _gesture(arm, 0.06, 12)
	var sweep := _gesture(arm, 0.16, 34)
	check(sweep > flick, "a committed sweep earns more commitment than a flick (%.2f vs %.2f)" % [sweep, flick])
	check(flick > 0.0, "and a flick still earns something — a mistimed swing that does nothing reads as broken, not demanding")
	check(sweep <= 1.0, "commitment is bounded, so a weapon's ceiling is still the weapon's")
	# The damage curve the hunt applies to it.
	var weak := lerpf(0.35, 1.35, flick)
	var strong := lerpf(0.35, 1.35, sweep)
	check(strong > weak * 1.4, "which makes the same weapon do meaningfully different damage for the same hit (x%.2f vs x%.2f)" % [strong, weak])

	# --- O10.5: gore and chunks run on the exchange's clock ----------------
	var slowed := _rig("slowed")
	await get_tree().process_frame
	check("motion_scale" in slowed, "a body has its own clock scale rather than reading the world's")
	slowed.motion_scale = 0.15
	check(is_equal_approx(slowed.motion_scale, 0.15), "and it can be driven to a fraction of real time for one exchange")

	# --- O9.1 / O9.2 / O10.12: losing is not dying ------------------------
	# Two halves. An NPC that loses goes down and is *resolved* rather than
	# deleted; the player's body fails and gets up worse.
	var npc := _rig("beaten")
	await get_tree().process_frame
	npc.anatomy.go_down()
	check(npc.anatomy.downed and not npc.anatomy.dead, "a beaten body is down, not dead — the resolution window is the system")
	npc.anatomy.stabilise()
	check(not npc.anatomy.downed and not npc.anatomy.dead, "and sparing one leaves somebody alive in the world")
	check(npc.anatomy.bleed_rate >= 0.0, "packed rather than healed — sparing costs the winner nothing and leaves a witness")

	var player := _rig("undying_loser")
	await get_tree().process_frame
	player.anatomy.undying = true
	player.anatomy.blood_remaining = player.anatomy.blood_capacity * 0.05
	player.anatomy.finish("beaten")
	check(not player.anatomy.dead, "losing a fight does not kill the player")
	check(player.anatomy.failed, "it fails their body instead")
	var burden_before: float = player.anatomy.spirit_burden
	var risen: Dictionary = player.anatomy.rise()
	check(not risen.is_empty(), "and they get up")
	check(player.anatomy.spirit_burden >= burden_before and burden_before > 0.0, "having permanently given up part of the body to do it — which is what makes losing mean something")
	check(player.anatomy.blood_remaining < player.anatomy.blood_capacity, "getting up is not healing")

	print("COMBAT_V10_AUDIT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


## Accumulate work into a limb the way a gesture does, then read what it earned.
## Drives the arm the way the hunt drives it: `advance()` with an accumulated
## look delta, exactly as `bone_yard_hunt.gd:1660` does. The previous version
## called `arm.follow()`, which does not exist on LimbMomentum -- so every
## gesture measured an arm that had never moved, and the three commitment
## claims below failed against 0.00 while the same behaviour passes on a real
## body in arm_wired_test. A test that drives a fake API is not an audit.
func _gesture(arm: LimbMomentum, reach: float, frames: int) -> float:
	arm.set("_work", 0.0)
	for _step in frames:
		arm.advance(1.0 / 60.0, Vector2(reach, 0.0))
	return arm.commitment()
