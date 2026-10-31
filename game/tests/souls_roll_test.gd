extends Node3D

const ROLL := preload("res://systems/souls_roll.gd")
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
	var roll = ROLL.new()
	check(not roll.start(Vector3.RIGHT, ROLL.STAMINA_COST - 0.01), "a roll cannot begin without its full stamina cost")
	check(not roll.start(Vector3.ZERO, 100.0), "a directionless roll is refused")
	check(roll.start(Vector3.RIGHT, ROLL.STAMINA_COST), "a funded directional roll begins")
	check(roll.is_rolling() and not roll.is_invulnerable(), "the opening anticipation is not invulnerable")
	check(roll.velocity().dot(Vector3.RIGHT) > 0.0 and absf(roll.velocity().y) < 0.001, "roll velocity follows the caller's flat movement frame")
	roll.tick(ROLL.I_FRAME_START + 0.01)
	check(roll.is_invulnerable(), "i-frames begin only inside the authored window")
	roll.tick(ROLL.I_FRAME_END - ROLL.I_FRAME_START)
	check(not roll.is_invulnerable() and roll.is_rolling(), "i-frames end before physical travel ends")
	roll.tick(ROLL.DURATION - ROLL.I_FRAME_END + 0.01)
	check(not roll.is_rolling() and roll.recovering() and roll.velocity().is_zero_approx(), "travel hands off to a vulnerable recovery")
	roll.tick(ROLL.RECOVERY)
	check(not roll.recovering(), "recovery ends deterministically")

	print("SOULS ROLL - the existing body now tucks, turns once, and returns upright")
	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("souls_roll_pose", {})
	var motion = MOTION.new()
	add_child(motion)
	motion.configure(rig)
	motion.set_roll_pose(0.5)
	motion.update(0.0, Vector3.ZERO, true, false, false, false)
	var halfway_pitch := absf(wrapf(rig.parts.torso.rotation.x, -PI, PI))
	check(halfway_pitch > PI * 0.80, "halfway through, the torso has turned through the inverted half of a full roll")
	check(rig.parts.head.position.y < rig.parts.head.get_meta("rest_position", rig.parts.head.position).y, "the head tucks inside the silhouette")
	motion.set_roll_pose(1.0)
	motion.update(0.0, Vector3.ZERO, true, false, false, false)
	check(absf(wrapf(rig.parts.torso.rotation.x, -PI, PI)) < 0.01, "the full rotation ends upright rather than leaving accumulated pitch")
	motion.clear_roll_pose()

	print("SOULS_ROLL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
