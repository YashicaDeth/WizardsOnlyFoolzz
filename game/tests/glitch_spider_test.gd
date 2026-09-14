extends Node

## "Reality Misfire" never made reality visibly misfire. The burst has to
## actually ramp up fast and fade slower rather than a symmetric pulse, has
## to actually turn itself off rather than staying lit forever (the same
## failure storm_weather.gd's flash light already taught this build to test
## for), and has to actually reach the psychedelic rig when handed one.

const GLITCH_SPIDER := preload("res://systems/glitch_spider.gd")
const RIG := preload("res://systems/psychedelic_rig.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var spider: Node3D = GLITCH_SPIDER.new()
	add_child(spider)
	check(not spider.visible, "inert until triggered")

	var rig: Control = RIG.new()
	add_child(rig)

	spider.trigger(Vector3(5, 0, 0), Vector3.ZERO, rig)
	check(spider.visible, "a trigger actually shows the burst")
	check(spider.global_position == Vector3(5, 0, 0), "at the position it was pointed at")

	spider._process(0.01)
	var early_intensity: float = spider._material.get_shader_parameter("intensity")
	check(early_intensity > 0.0 and early_intensity < 1.0, "the attack ramps up rather than snapping to full (%.2f)" % early_intensity)
	check(rig.dial("cut_intensity") > 0.0, "and the psychedelic rig actually feels it too")

	# Through the peak.
	spider._process(GLITCH_SPIDER.BURST_DURATION * GLITCH_SPIDER.ATTACK_FRACTION)
	var peak_intensity: float = spider._material.get_shader_parameter("intensity")
	check(peak_intensity > early_intensity, "and keeps climbing to a real peak (%.2f)" % peak_intensity)

	# Well past the end.
	spider._process(GLITCH_SPIDER.BURST_DURATION * 2.0)
	check(not spider.visible, "the burst actually turns itself off rather than staying lit forever")
	check(absf(float(spider._material.get_shader_parameter("intensity"))) < 0.01, "and reaches true zero, not just invisible while still \"on\"")
	check(absf(rig.dial("cut_intensity")) < 0.001, "the psychedelic pulse lets go too")
	check(absf(rig.dial("chromatic_offset")) < 0.001, "both dials it touched, not just one")

	# A degenerate look_from (same point as the burst) must not crash.
	spider.trigger(Vector3(1, 1, 1), Vector3(1, 1, 1))
	check(spider.visible, "and a degenerate look_from does not stop it from triggering")

	if failures.is_empty():
		print("glitch spider: reality actually misfires now")
		get_tree().quit(0)
	else:
		print("glitch spider FAILURES: ", failures)
		get_tree().quit(1)
