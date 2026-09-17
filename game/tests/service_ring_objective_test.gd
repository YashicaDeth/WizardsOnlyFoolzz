extends Node

const FACILITY := preload("res://systems/facility_territory.gd")

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
	FACILITY.apply_event("opening_entered_pit")
	var derby: Node = load("res://underground_colosseum.tscn").instantiate()
	add_child(derby)
	await get_tree().process_frame
	check(derby.service_relays.size() == 3, "the three real tunnel chambers each contain one relay")
	check(derby._service_relays_disabled() == 0, "all three begin as live surveillance")
	derby.round_state = "active"
	derby.disabled_count = 8
	check(not derby._try_finish_colosseum_objective(), "eight wreckers alone no longer skips the Service Ring")
	check(derby.round_state == "active", "the emptied bowl remains driveable while the ring is live")

	for index in 2:
		derby.service_relays[index].take_hit("test", 3.0)
	check(derby.round_state == "active", "two disabled relays do not counterfeit liberation")
	check(str(FACILITY.sector("service_ring").state) != FACILITY.LIBERATED, "territory still reports the Service Ring as occupied")
	derby.service_relays[2].take_hit("test", 3.0)
	check(derby.round_state == "won", "the final relay completes the compound derby objective")
	check(str(FACILITY.sector("service_ring").state) == FACILITY.LIBERATED, "the playable act liberates the Service Ring")
	check(not WorldHistory.subject("facility:service_ring").is_empty(), "liberation unlocks its INDEX record")
	check(str(WorldHistory.subject(FACILITY.REACTION_SUBJECT).status) == "priority", "CellOutz escalates its response when the ring goes dark")
	check(WorldHistory.event_count("celloutz_service_ring_retaliation") == 1, "the escalation is written exactly once")
	derby.service_relays[2].take_hit("test", 3.0)
	check(WorldHistory.event_count("celloutz_service_ring_retaliation") == 1, "dead hardware cannot duplicate the corporate reaction")

	print("SERVICE_RING_OBJECTIVE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
