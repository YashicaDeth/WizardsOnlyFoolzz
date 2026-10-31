extends Node

## The readout reports the locked body's real zones, never invents one, and
## shows nothing when nothing is locked.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var readout := LockReadout.new()
	add_child(readout)
	var defaults: Dictionary = AnatomyComponent.DEFAULT_ZONES
	readout.show_for(Vector2(400, 300), "Rook Sable", {"left_arm": {"health": 0.0}, "head": {"health": 22.5}}, defaults)
	check(readout.shown, "locking shows the body")
	check(is_zero_approx(readout.zone_ratio("left_arm")), "a destroyed arm reads as gone")
	check(is_equal_approx(readout.zone_ratio("head"), 0.5), "a half-broken head reads as half")
	check(is_equal_approx(readout.zone_ratio("torso"), 1.0), "an untouched zone reads whole")
	readout.show_for(Vector2.ZERO, "X", {"torso": {"health": 999.0}}, defaults)
	check(readout.zone_ratio("torso") <= 1.0, "never more than whole")
	readout.hide_readout()
	check(not readout.shown, "unlocking hides it")
	print("LOCK_READOUT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
