extends Node

## Bearings point the right way round, and threats vanish once an enemy stops
## winding up.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	# A camera looking down -Z with +X to its right (Godot's default basis).
	var basis := Basis.IDENTITY
	check(is_zero_approx(ThreatCompass.bearing(basis, Vector3.ZERO, Vector3(0, 0, -5))), "straight ahead is 0")
	check(is_equal_approx(absf(ThreatCompass.bearing(basis, Vector3.ZERO, Vector3(0, 0, 5))), PI), "behind is the bottom of the frame")
	check(is_equal_approx(ThreatCompass.bearing(basis, Vector3.ZERO, Vector3(5, 0, 0)), PI * 0.5), "to the right is to the right")
	check(is_equal_approx(ThreatCompass.bearing(basis, Vector3.ZERO, Vector3(-5, 0, 0)), -PI * 0.5), "to the left is to the left")
	check(is_zero_approx(ThreatCompass.bearing(basis, Vector3.ZERO, Vector3(0, 9, -5))), "height never changes the direction")
	var compass := ThreatCompass.new()
	add_child(compass)
	compass.report("a", Vector3(0, 0, 5), 0.5)
	compass.report("b", Vector3(5, 0, 0), 0.9)
	check(compass.active_count() == 2, "every winding-up enemy is shown")
	# Past HOLD (0.12 s): the hold keeps an arc from flickering on a skipped
	# report, so a dropped enemy has to stay silent longer than that.
	for i in 10:
		compass.report("a", Vector3(0, 0, 5), 0.6)
		compass._process(1.0 / 60.0)
	check(compass.active_count() == 1, "an enemy that stops winding up drops off")
	for i in 20:
		compass._process(1.0 / 60.0)
	check(compass.active_count() == 0, "nothing lingers once the fight stops")
	print("THREAT_COMPASS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
