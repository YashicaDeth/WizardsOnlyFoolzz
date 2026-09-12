extends Node

## O2.7 v3 verification. scale_for() only ever reached the encounter loop's
## actor_delta — the player's own cooldowns and the rig's own animation clock
## kept ticking at full speed through a hitstop they were the other half of.

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

	# --- baseline: cooldowns and animation tick at full speed with no hit ---
	hunt.attack_cooldown = 1.0
	hunt.dodge_cooldown = 1.0
	var motion_before: float = hunt.body_motion.elapsed
	hunt._physics_process(0.1)
	var baseline_cooldown_drop: float = 1.0 - float(hunt.attack_cooldown)
	var baseline_motion_gain: float = float(hunt.body_motion.elapsed) - motion_before
	check(is_equal_approx(baseline_cooldown_drop, 0.1), "with no hitstop, attack_cooldown ticks at the real rate")
	check(baseline_motion_gain > 0.08, "and the rig's own animation clock advances at the real rate too (%.3f)" % baseline_motion_gain)

	# --- a solid hit holds time for the player's own exchange too now -------
	hunt.impact_feel.strike(0.8, "cut", false)
	check(hunt.impact_feel.scale_for("player") < 1.0, "scale_for('player') actually reads the slowdown when nobody named the exchange")

	hunt.attack_cooldown = 1.0
	hunt.dodge_cooldown = 1.0
	var motion_before_hit: float = hunt.body_motion.elapsed
	hunt._physics_process(0.1)
	var held_cooldown_drop: float = 1.0 - float(hunt.attack_cooldown)
	var held_motion_gain: float = float(hunt.body_motion.elapsed) - motion_before_hit
	check(held_cooldown_drop < baseline_cooldown_drop * 0.5, "attack_cooldown ticks down slower during the player's own hitstop (%.4f vs %.4f)" % [held_cooldown_drop, baseline_cooldown_drop])
	check(held_motion_gain < baseline_motion_gain * 0.5, "and the rig's own animation clock slows with it (%.4f vs %.4f)" % [held_motion_gain, baseline_motion_gain])

	print("HITSTOP_SCOPE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
