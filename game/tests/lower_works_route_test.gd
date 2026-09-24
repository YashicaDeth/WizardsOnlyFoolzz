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

	# The optional arcade tool is the direct, riskier answer to the same
	# pressure beat.  Check it in a fresh district so the fuse has not already
	# switched the sentinel off.
	WorldHistory.record_event("service_arcade_breach_tool_taken", {"location": "service_arcade"})
	# Lower Works reads the tool from Carry now, so a death can take it away.
	var carry := Carry.new()
	carry.items.append({"label": "BREACH TOOL", "kind": "tool", "mass": 4.0, "perishes": false, "age": 0.0})
	carry.save_to_history()
	var combat_city: Variant = load("res://buried_city.tscn").instantiate()
	add_child(combat_city)
	await get_tree().physics_frame
	combat_city.player.global_position = combat_city.patrol.global_position + Vector3(0, 0, 5.0)
	combat_city._discharge_breach_tool()
	check(combat_city.breach_tool_ready, "the arcade breach tool carries into Lower Works")
	check(combat_city.patrol_disabled and combat_city.sentinel_disable_reason == "breach_interrupted", "the breach tool can interrupt the live sentinel at close range")
	check(WorldHistory.event_count("lower_works_sentinel_breached") == 1, "the direct encounter records its actual resolution")
	combat_city.queue_free()

	# Standing at the elevator you can see is enough to be offered the way down.
	city.player.global_position = city.LIFT_AT + Vector3(0, 0.9, 3.2)
	city._update_hud()
	check(city.prompt.text.contains("DESCEND"), "the elevator you can see offers the descent (%s)" % city.prompt.text)

	city._record_pit_entry()
	check(OpeningDirector.reached("entered_pit"), "the elevator handoff records the derby stage")
	check(WorldHistory.event_count("lower_works_entered_pit") == 1, "and creates one attributable exit event")

	print("LOWER_WORKS_ROUTE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
