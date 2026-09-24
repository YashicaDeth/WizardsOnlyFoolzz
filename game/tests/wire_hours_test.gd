extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func report_count(posts: Array) -> int:
	return posts.filter(func(post: Dictionary): return str(post.get("kind", "")) == "report").size()


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	for faction_id in ["celloutz", "ashline_wreckers", "gate_lanterns"]:
		WorldHistory.register_subject(faction_id, {"kind": "faction", "name": faction_id})
	WorldHistory.register_subject("night_worker", {
		"kind": "person", "name": "Night Worker", "faction_id": "ashline_wreckers",
		"faction": "Ashline Wreckers", "status": "active",
	})
	WorldHistory.register_subject("day_worker", {
		"kind": "person", "name": "Day Worker", "faction_id": "gate_lanterns",
		"faction": "Gate Lanterns", "status": "active",
	})
	WorldHistory.register_subject("switchboard", {
		"kind": "person", "name": "Switchboard", "faction_id": "celloutz",
		"faction": "CellOutz", "status": "active",
	})
	for index in 8:
		WorldHistory.record_event("hourly_report", {"subject_id": "night_worker", "index": index})

	var wire := WireNet.new()
	check(wire.faction_activity("ashline_wreckers", 23.0) > 0.6, "Ashline traffic is live during its night shift")
	check(wire.faction_activity("ashline_wreckers", 12.0) == WireNet.QUIET_ACTIVITY, "Ashline traffic falls to residue at noon")
	check(wire.faction_activity("gate_lanterns", 12.0) > 0.6, "Gate Lantern traffic is live through its day shift")
	check(wire.faction_activity("gate_lanterns", 1.0) == WireNet.QUIET_ACTIVITY, "Gate Lantern traffic is quiet overnight")
	check(wire.faction_activity("celloutz", 3.0) == 1.0 and wire.faction_activity("celloutz", 15.0) == 1.0, "CellOutz automation never closes")

	WorldHistory.world_minute = 12.0 * WorldClock.MINUTES_PER_HOUR
	var noon := WireNet.new()
	check(str(noon.account("night_worker").last_seen).begins_with("QUIET UNTIL"), "an off-shift account says when its faction returns")
	check(str(noon.account("day_worker").last_seen) == "ONLINE NOW", "an on-shift active account remains visibly online")

	# Find aggregate extrema rather than assuming these schedules overlap at an
	# authored hour forever. Feed density follows the same aggregate.
	var low_hour := 0
	var high_hour := 0
	var low_activity := 2.0
	var high_activity := -1.0
	for hour in 24:
		WorldHistory.world_minute = float(hour) * WorldClock.MINUTES_PER_HOUR
		var probe := WireNet.new()
		var activity := probe.network_activity()
		if activity < low_activity:
			low_activity = activity
			low_hour = hour
		if activity > high_activity:
			high_activity = activity
			high_hour = hour
	print("traffic extrema low=", low_hour, ":", low_activity, " high=", high_hour, ":", high_activity)
	WorldHistory.world_minute = float(low_hour) * WorldClock.MINUTES_PER_HOUR
	var quiet := WireNet.new()
	var quiet_activity := quiet.network_activity()
	var quiet_reports := report_count(quiet.feed(24))
	var quiet_band := quiet.activity_band()
	WorldHistory.world_minute = float(high_hour) * WorldClock.MINUTES_PER_HOUR
	var crowded := WireNet.new()
	var crowded_activity := crowded.network_activity()
	var crowded_reports := report_count(crowded.feed(24))
	var crowded_band := crowded.activity_band()
	check(crowded_activity > quiet_activity, "the shared clock produces genuinely different network traffic")
	check(crowded_reports > quiet_reports, "a crowded Wire carries more live world reports than quiet hours")
	check(crowded_band != quiet_band, "the visible traffic register changes with faction hours")

	print("WIRE_HOURS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
