extends Node

## The Lower Works is an actual opening beat, not a backdrop between two scene
## swaps.  Exercise its physical route directly so a changed interaction radius
## or a future scene refactor cannot leave the player holding the fuse in a
## room that has no usable exit.

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
	var city: Variant = load("res://buried_city.tscn").instantiate()
	add_child(city)
	await get_tree().physics_frame
	await get_tree().physics_frame

	check(not city.fuse_taken, "the lift begins unpowered")
	check(not city.shortcut_open, "and the safer west route begins sealed")
	check(not city.patrol_disabled, "with its sentinel relay live")

	city.player.global_position = city.FUSE_AT
	city._interact()
	check(city.fuse_taken, "the physical fuse can be collected")
	check(not city.fuse_visual.visible, "and disappears from its bracket")

	city.player.global_position = city.SHORTCUT_AT
	city._interact()
	check(city.shortcut_open, "the fuse powers the service shortcut")
	check(city.patrol_disabled, "and disables the sentinel relay")
	check(city.shortcut_gate.is_queued_for_deletion(), "the shortcut collision gate is removed")
	city._physics_process(0.1)
	check(not city.patrol_alert, "a disabled sentinel cannot re-engage")

	city._record_pit_entry()
	check(OpeningDirector.reached("entered_pit"), "the elevator handoff records the derby stage")
	check(WorldHistory.event_count("lower_works_entered_pit") == 1, "and creates one attributable exit event")

	print("LOWER_WORKS_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
