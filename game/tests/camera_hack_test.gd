extends Node

## Greg, 24 September: cameras can be hacked "later", by look and hold, once
## earned. Earned = the soul seized the chip in the breakout.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var unit = load("res://support_unit.tscn").instantiate()
	add_child(unit)
	await get_tree().physics_frame
	var lens: SecurityCamera = unit.cameras[0]
	check(not bool(lens.hack().accepted), "a camera cannot be hacked before the implant is seized")
	WorldHistory.amend_subject("player", {"implant_seized": true})
	check(SecurityCamera.hack_earned(), "seizing the chip earns it")
	check(bool(lens.hack().accepted) and lens.is_looped(), "then the look loops its feed")
	var in_view := lens.eye() + lens.forward() * 4.0
	for _i in 100:
		lens.step(0.1, in_view, null, false)
	check(not lens.tracking and lens.lock == 0.0, "a looped camera films nothing while it plays back the empty corridor")
	for _i in 110:
		lens.step(0.1, in_view, null, false)
	check(not lens.is_looped(), "and after twenty seconds it is back")
	check(WorldHistory.event_count("support_camera_looped") == 1, "the loop is on the record")
	var numbered := str(WorldHistory.subject(unit.guards[0].subject_id).get("name", ""))
	check(numbered.begins_with("CELLOUTZ SECURITY ") and numbered.right(2).is_valid_int(), "guards are numbers, not names (%s)" % numbered)
	print("CAMERA_HACK_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
