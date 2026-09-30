extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var knockback := Knockback.new()
	var light_attack := {"attack": "light_1", "knockback_multiplier": 1.0, "poise_multiplier": 1.0}
	var light := knockback.apply(10.0, Vector3.LEFT, light_attack)
	check(not bool(light.knockdown), "one light strike does not break full poise")
	check((light.shove as Vector3).x < 0.0 and is_zero_approx((light.shove as Vector3).z), "shove follows the incoming horizontal direction")
	var second := knockback.apply(10.0, Vector3.LEFT, light_attack)
	var third := knockback.apply(10.0, Vector3.LEFT, light_attack)
	check(not bool(second.knockdown) and bool(third.knockdown), "three lights break poise while two do not")

	var comparison := Knockback.new()
	var light_distance := (comparison.apply(10.0, Vector3.FORWARD, light_attack).shove as Vector3).length()
	comparison.reset()
	var running_distance := (comparison.apply(10.0, Vector3.FORWARD, {"attack": "running_attack", "knockback_multiplier": 2.4, "poise_multiplier": 1.8}).shove as Vector3).length()
	comparison.reset()
	var heavy_distance := (comparison.apply(10.0, Vector3.FORWARD, {"attack": "heavy", "knockback_multiplier": 3.6, "poise_multiplier": 3.0}).shove as Vector3).length()
	check(light_distance < running_distance and running_distance < heavy_distance, "light, running, and heavy attacks have distinct shove distances")
	check(is_equal_approx(light_distance, 0.25) and is_equal_approx(running_distance, 0.60) and is_equal_approx(heavy_distance, 0.90), "default sword impulses use the agreed 0.25 m, 0.60 m, and 0.90 m shoves")

	comparison.reset()
	comparison.apply(10.0, Vector3.RIGHT, light_attack)
	var first_tick := comparison.tick(1.0 / 60.0).length()
	var later_tick := 0.0
	for index in 30:
		later_tick = comparison.tick(1.0 / 60.0).length()
	check(first_tick > later_tick and later_tick > 0.0, "ground friction eases shove rather than stopping it in one frame")

	comparison.reset()
	comparison.apply(10.0, Vector3.RIGHT, light_attack)
	var wounded_poise := comparison.poise
	comparison.tick(2.0)
	check(comparison.poise > wounded_poise and comparison.poise <= Knockback.MAX_POISE, "poise regenerates over time without exceeding its ceiling")

	print("KNOCKBACK - multipliers belong to the attack packet")
	var table_driven := Knockback.new()
	var plain := table_driven.apply(10.0, Vector3.FORWARD, {"attack": "made_up", "knockback_multiplier": 0.5, "poise_multiplier": 0.25})
	check(is_equal_approx((plain.shove as Vector3).length(), 0.125), "Knockback reads shove multiplier from the attack rather than an id list")
	check(is_equal_approx(float(plain.poise_damage), 8.5), "Knockback reads poise multiplier from the attack packet")
	table_driven.reset()
	var uncharged := table_driven.apply(28.0, Vector3.FORWARD, {"attack": "heavy", "knockback_multiplier": 1.0, "poise_multiplier": 1.0})
	check(not bool(uncharged.knockdown), "an uncharged heavy does not break full poise")
	table_driven.reset()
	var charged := table_driven.apply(28.0, Vector3.FORWARD, {"attack": "charged_heavy", "knockback_multiplier": 1.0, "poise_multiplier": 1.0, "breaks_poise": true})
	check(bool(charged.knockdown), "a charged heavy explicitly breaks full poise")

	print("KNOCKBACK_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
