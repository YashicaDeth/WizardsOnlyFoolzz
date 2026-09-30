extends Node

const MOVESET := preload("res://systems/sword_moveset.gd")
const MOTION := preload("res://systems/hunter_body_motion.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var moveset = MOVESET.new()
	var light: Dictionary = moveset.attack_definition("light_1")
	var heavy: Dictionary = moveset.attack_definition("heavy")
	check(float(heavy.stamina_cost) > float(light.stamina_cost), "a heavy attack costs more stamina than a light")
	check(float(heavy.windup) > float(light.windup), "a heavy attack hits later than a light")
	check(not moveset.request_heavy(float(heavy.stamina_cost) - 0.01).accepted, "an attack cannot begin without its stamina cost")

	print("SWORD MOVESET - weapon and stance tables are genuinely distinct")
	var sword_one := moveset.attack_definition("light_1")
	moveset.configure("sword", "two_hand")
	var sword_two := moveset.attack_definition("light_1")
	check(float(sword_two.windup) > float(sword_one.windup) and float(sword_two.stamina_cost) > float(sword_one.stamina_cost), "two-hand sword is slower and costs more stamina")
	check(float(sword_two.poise_multiplier) > float(sword_one.poise_multiplier) and float(sword_two.knockback_multiplier) > float(sword_one.knockback_multiplier), "two-hand sword carries more poise and knockback")
	moveset.configure("shiv", "one_hand")
	var shiv := moveset.attack_definition("light_1")
	check(float(shiv.reach) < float(sword_one.reach) and float(shiv.windup) < float(sword_one.windup) and float(shiv.poise_multiplier) < float(sword_one.poise_multiplier), "shiv is shorter, faster and lower-poise than the cleaver")
	check(str(shiv.motion) == "thrust", "shiv light chain is authored as thrusts rather than sword slashes")
	moveset.configure("fists", "one_hand")
	var fists := moveset.attack_definition("light_1")
	var shove := moveset.attack_definition("heavy")
	check(float(fists.reach) < float(shiv.reach) and str(fists.motion) == "jab" and str(fists.damage_type) == "blunt", "bare hands use short blunt jabs")
	check(bool(shove.breaks_poise) and not bool(shove.cuts), "the bare-hand shove breaks poise but cannot cut")
	moveset.configure("sword", "one_hand")

	print("SWORD MOVESET - releasing R2 selects the authored charged attack")
	var uncharged_release := moveset.request_heavy_release(MOVESET.CHARGED_HEAVY_SECONDS - 0.01, 100.0)
	check(uncharged_release.accepted and uncharged_release.attack == "heavy", "short R2 hold releases the ordinary heavy")
	moveset.reset()
	var charged_release := moveset.request_heavy_release(MOVESET.CHARGED_HEAVY_SECONDS + 0.01, 100.0)
	check(charged_release.accepted and charged_release.attack == "charged_heavy", "held R2 releases the charged heavy")
	check(bool(moveset.current_definition().breaks_poise), "charged heavy packet declares a full poise break")
	moveset.reset()

	print("SWORD MOVESET - late recovery accepts exactly one buffered roll")
	var start: Dictionary = moveset.request_light(100.0)
	check(start.accepted and start.attack == "light_1", "the light chain starts at light one")
	var before_buffer := float(light.windup) + float(light.active) + float(light.recovery) - MOVESET.INPUT_BUFFER_WINDOW * 0.5
	var recovery_report: Dictionary = moveset.tick(before_buffer)
	check(recovery_report.phase == "recovery", "the fixture reaches late recovery before buffering")
	check(moveset.buffer_roll(Vector3.RIGHT), "a roll input is buffered during late recovery")
	var still_recovering: Dictionary = moveset.tick(MOVESET.INPUT_BUFFER_WINDOW * 0.2)
	check(still_recovering.roll_direction == Vector3.ZERO, "the buffered roll does not cancel remaining recovery")
	var freed: Dictionary = moveset.tick(MOVESET.INPUT_BUFFER_WINDOW)
	check(freed.started_buffered and (freed.roll_direction as Vector3).dot(Vector3.RIGHT) > 0.99, "the buffered roll fires on the first free frame")

	print("SWORD MOVESET - the light chain expires rather than looping forever")
	moveset.reset()
	moveset.request_light(100.0)
	moveset.tick(float(light.windup) + float(light.active) + float(light.recovery) + 0.01)
	var second: Dictionary = moveset.request_light(100.0)
	check(second.attack == "light_2", "a timely follow-up advances the chain")
	var second_def: Dictionary = moveset.attack_definition("light_2")
	moveset.tick(float(second_def.windup) + float(second_def.active) + float(second_def.recovery) + MOVESET.CHAIN_WINDOW + 0.02)
	var reset_chain: Dictionary = moveset.request_light(100.0)
	check(reset_chain.attack == "light_1", "the chain resets to light one after its window")

	print("SWORD MOVESET - damage arcs rotate with the body, not the camera")
	var origin := Vector3(4.0, 0.0, 7.0)
	moveset.reset()
	moveset.request_light(100.0)
	var active_frame: Dictionary = moveset.tick(float(light.windup) + float(light.active) * 0.5, origin, 0.0)
	check(not (active_frame.hit_points as PackedVector3Array).is_empty() and active_frame.side == BladeRead.RIGHT,
		"each active frame returns swept hit_at points and its committed BladeRead side")
	var yaw_zero := moveset.full_arc_points("light_1", origin, 0.0)
	var front_zero := Vector3.FORWARD
	var all_front_zero := not yaw_zero.is_empty()
	for point: Vector3 in yaw_zero:
		var flat := point - origin
		flat.y = 0.0
		all_front_zero = all_front_zero and flat.dot(front_zero) > 0.0
	check(all_front_zero, "every yaw-zero arc point sits in front of the body")
	var quarter_turn := PI * 0.5
	var body_front := Basis(Vector3.UP, quarter_turn) * Vector3.FORWARD
	var yaw_quarter := moveset.full_arc_points("light_1", origin, quarter_turn)
	var all_front_quarter := not yaw_quarter.is_empty()
	for point: Vector3 in yaw_quarter:
		var flat := point - origin
		flat.y = 0.0
		all_front_quarter = all_front_quarter and flat.dot(body_front) > 0.0
	check(all_front_quarter, "the same arc follows a body turned through PI/2")

	print("SWORD MOVESET - authored phases drive the existing anatomical body")
	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("sword_moveset_pose", {})
	var motion = MOTION.new()
	add_child(motion)
	motion.configure(rig)
	motion.update(0.0, Vector3.ZERO, true, false, false, false)
	var rest_z: float = rig.parts.right_arm.rotation.z
	motion.set_moveset_pose("windup", 1.0, BladeRead.RIGHT, "heavy")
	motion.update(0.0, Vector3.ZERO, true, false, false, false)
	check(absf(rig.parts.right_arm.rotation.z - rest_z) > 0.8, "a heavy windup visibly commits the weapon arm")
	motion.set_moveset_pose("recovery", 1.0, BladeRead.RIGHT, "heavy")
	motion.update(0.0, Vector3.ZERO, true, false, false, false)
	check(absf(rig.parts.right_arm.rotation.z - rest_z) < 0.01, "the authored recovery returns the arm to its underlying locomotion pose")
	motion.clear_moveset_pose()

	print("SWORD_MOVESET_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
