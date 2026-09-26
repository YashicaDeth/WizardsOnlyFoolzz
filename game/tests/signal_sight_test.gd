extends Node

## Greg, 26 September: camera signals are invisible except in the K and J
## modes. K toggles wizard eyes, J holds the depth scan, both from the brain
## hack on; staying in strains the view; only hacked cameras notice.

const SIGHT := preload("res://systems/signal_sight.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key(target, code: Key, down := true) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = down
	target._unhandled_input(e)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var sight = vat.sight
	check(sight != null, "the Growing Floor has the vision modes")
	key(sight, KEY_K)
	check(sight.mode == "", "K does nothing before the brain hack")
	vat._on_hack_finished(false)
	key(sight, KEY_K)
	check(sight.mode == "wizard", "after the hack, K opens wizard eyes")
	check(sight.spirits.size() >= 1, "and there is a spirit where the failed subject died")
	key(sight, KEY_J)
	check(sight.mode == "depth", "holding J is the depth scan")
	key(sight, KEY_J, false)
	check(sight.mode == "wizard", "letting go of J goes back to wizard eyes")
	for i in 30:
		sight._process(1.0)
	check(sight.strain >= 1.0, "staying in strains the view to the full (%.2f)" % sight.strain)
	key(sight, KEY_K)
	check(sight.mode == "", "K again closes wizard eyes")
	for i in 10:
		sight._process(1.0)
	check(sight.strain <= 0.0, "and the strain clears")
	check(WorldHistory.event_count("signal_sight_used") >= 2, "using the modes is recorded")
	var lens: SecurityCamera = vat.watchers.cameras[0]
	check(not lens.cone.visible, "a wall camera's cone stays invisible either way")
	lens.looped_for = 10.0
	key(sight, KEY_J)
	check(lens.looped_for == 0.0 and WorldHistory.event_count("hacked_camera_noticed_sight") == 1, "a hacked camera notices, and its loop breaks")
	key(sight, KEY_J, false)
	vat.queue_free()
	await get_tree().process_frame

	var unit = load("res://support_unit.tscn").instantiate()
	add_child(unit)
	await get_tree().process_frame
	check(unit.sight != null and unit.sight.enabled, "the Support Unit has them, enabled")
	check(unit.sight.bodies.call().size() >= 2, "the depth scan sees its guards and cells through the walls")
	unit.queue_free()
	await get_tree().process_frame
	var drains = load("res://old_drains.tscn").instantiate()
	add_child(drains)
	await get_tree().process_frame
	check(drains.sight != null and drains.sight.bodies.call().size() == 1, "the drains' scan sees the stalker")
	print("SIGNAL_SIGHT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
