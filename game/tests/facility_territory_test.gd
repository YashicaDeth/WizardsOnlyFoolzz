extends Node

const FACILITY := preload("res://systems/facility_territory.gd")
const QUANTUM := preload("res://systems/quantum_saves.gd")

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

	var fresh := FACILITY.overview()
	check(fresh.sectors.size() == 4, "the facility authority owns four authored sectors")
	check(str(fresh.sectors[0].state) == FACILITY.CONTROLLED, "a fresh facility is still corporate-controlled")

	FACILITY.apply_event("opening_woke")
	check(bool(FACILITY.sector("growing_floor").revealed), "waking reveals the Growing Floor")
	FACILITY.apply_event("opening_entered_pit")
	check(str(FACILITY.sector("pit").state) == FACILITY.SURVEYED, "entering the pit surveys rather than liberates it")

	FACILITY.apply_event("derby_round_won")
	check(str(FACILITY.sector("pit").state) == FACILITY.LIBERATED, "winning the real heat liberates the colosseum sector")
	check(int(FACILITY.overview().liberated_count) == 1, "liberation is counted once")
	check(not WorldHistory.subject("facility:underground_colosseum").is_empty(), "liberation unlocks the colosseum INDEX record")
	check(str(WorldHistory.subject(FACILITY.REACTION_SUBJECT).status) == "circulating", "CellOutz posts a persistent repossession order")
	check(WorldHistory.event_count("celloutz_repossession_order_posted") == 1, "the corporate reaction is idempotent")
	var true_position := Vector2(31, -77)
	var ping := FACILITY.publish_target_ping(true_position)
	var ping_centre := Vector2(float(ping.x), float(ping.z))
	check(not ping.is_empty() and ping_centre != true_position, "the Black Mirror publishes a coarse target area rather than exact coordinates")
	check(ping_centre.distance_to(true_position) <= float(ping.radius), "the real target remains inside CellOutz's published uncertainty radius")
	check(WorldHistory.event_count("celloutz_target_area_published") == 1, "the first acquisition cell emits one bounty ping")
	FACILITY.publish_target_ping(Vector2(35, -70))
	check(WorldHistory.event_count("celloutz_target_area_published") == 1, "movement inside the same coarse area cannot spam the bounty ledger")
	var moved_ping := FACILITY.publish_target_ping(Vector2(150, -70))
	check(int(moved_ping.sequence) == 2 and WorldHistory.event_count("celloutz_target_area_published") == 2, "crossing a large acquisition boundary publishes the next persisted area")
	FACILITY.apply_event("derby_round_won")
	check(WorldHistory.event_count("celloutz_repossession_order_posted") == 1, "replaying a win cannot duplicate the bounty")

	var branch := QUANTUM.save_current(0, "FACILITY WON")
	check(not branch.is_empty(), "the liberated facility saves into a quantum branch")
	WorldHistory.clear_history()
	check(str(FACILITY.sector("pit").state) == FACILITY.CONTROLLED, "a new universe starts with the pit controlled")
	check(QUANTUM.enter(0), "the saved facility branch can be re-entered")
	check(str(FACILITY.sector("pit").state) == FACILITY.LIBERATED, "quantum restore returns liberation state")
	check(str(WorldHistory.subject(FACILITY.REACTION_SUBJECT).status) == "circulating", "quantum restore returns the bounty with it")
	check(int(FACILITY.target_area().get("sequence", 0)) == 2, "quantum restore returns the last published target area")

	print("FACILITY_TERRITORY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
