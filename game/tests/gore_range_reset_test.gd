extends Node

## AF6.3. R is a drill reset, not a scene reload. Damage one production body,
## leave debris and counters behind, press the public input, and prove the same
## range node replaces all seven rigs with fresh anatomy in place.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var demo: Node3D = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await get_tree().physics_frame

	var scene_id := demo.get_instance_id()
	var before: Array = demo.get("bodies")
	var old_rig := (before[0] as Dictionary).get("rig") as BaselineHuman
	var old_ids: Array[int] = []
	for entry: Dictionary in before:
		old_ids.append((entry.get("rig") as BaselineHuman).get_instance_id())
	var full_torso := old_rig.zone_health("torso")
	old_rig.hit("torso", 28.0, 4.0, "blunt")
	demo.set("spent", 9)
	demo.set("severed_total", 3)
	check(old_rig.zone_health("torso") < full_torso, "the drill contains a genuinely damaged production body before reset")

	var reset_key := InputEventKey.new()
	reset_key.keycode = KEY_R
	reset_key.pressed = true
	Input.parse_input_event(reset_key)
	for _frame in 4:
		await get_tree().process_frame

	var after: Array = demo.get("bodies")
	check(demo.get_instance_id() == scene_id, "R keeps the same range scene alive")
	check(after.size() == demo.BODY_COUNT, "the complete seven-body drill is restored")
	check(not is_instance_valid(old_rig), "the damaged rig is retired rather than cosmetically healed")
	var all_new := true
	var all_fresh := true
	for entry: Dictionary in after:
		var rig := entry.get("rig") as BaselineHuman
		all_new = all_new and rig.get_instance_id() not in old_ids
		for zone: String in AnatomyComponent.DEFAULT_ZONES:
			var expected := float((AnatomyComponent.DEFAULT_ZONES[zone] as Dictionary).health)
			all_fresh = all_fresh and is_equal_approx(rig.zone_health(zone), expected)
	check(all_new, "every target is a newly built body, not a stale entry left in the array")
	check(all_fresh, "every restored body has fresh anatomy in every canonical zone")
	check(int(demo.get("spent")) == 0 and int(demo.get("severed_total")) == 0, "the drill counters reset with the bodies")

	print("GORE_RANGE_RESET_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
