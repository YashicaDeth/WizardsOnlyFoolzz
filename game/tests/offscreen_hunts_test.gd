extends Node

const HUNTS := preload("res://systems/offscreen_hunts.gd")
const DERBY := preload("res://rift_derby.gd")

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "status": "active"})
	WorldHistory.register_subject("road_hunter", {"name": "ROAD HUNTER", "kind": "person", "status": "hunting"})
	var started := HUNTS.start("road_hunter", "player", "ashbloom_bone_yard")
	check(bool(started.get("ok", false)) and str(started.get("hunt_target", "")) == "player", "a hunt starts with one exact hunter, target and place")

	WorldClock.pass_time(0.5)
	check(HUNTS.advance("ashbloom_bone_yard").is_empty(), "time face-to-face at the hunt site is not counterfeit background progress")
	WorldClock.pass_time(14.0 / 60.0)
	check(HUNTS.advance("rift_derby_quarry").is_empty(), "less than one complete elsewhere turn changes nothing")
	WorldClock.pass_time(1.0 / 60.0)
	var first := HUNTS.advance("rift_derby_quarry")
	var after_first := WorldHistory.subject("road_hunter")
	check(first.size() == 1 and int(after_first.get("hunt_offscreen_turns", 0)) == 1 and str(after_first.get("hunt_phase", "")) == "searching", "fifteen world-minutes elsewhere advances the persisted hunt once")
	check(str((first[0].get("details", {}) as Dictionary).get("target_id", "")) == "player" and str((first[0].get("details", {}) as Dictionary).get("player_location", "")) == "rift_derby_quarry", "the background turn keeps exact target and the place the player was instead")

	WorldClock.pass_time(45.0 / 60.0)
	var catchup := HUNTS.advance("underground_colosseum")
	var after_catchup := WorldHistory.subject("road_hunter")
	check(catchup.size() == 1 and int((catchup[0].get("details", {}) as Dictionary).get("turns", 0)) == 3, "a long absence catches up in one bounded event rather than one event per missed frame")
	check(int(after_catchup.get("hunt_offscreen_turns", 0)) == 4 and str(after_catchup.get("hunt_phase", "")) == "closing", "the same hunt moves from searching to closing while its scene is unloaded")
	check(HUNTS.advance("underground_colosseum").is_empty(), "reading the same world minute twice cannot advance it twice")
	WorldHistory.amend_subject("road_hunter", {"status": "escaped"})
	WorldClock.pass_time(1.0)
	check(HUNTS.advance("rift_derby_quarry").is_empty(), "a resolved hunter stops running in the background")

	WorldHistory.register_subject("derby_hunter", {"name": "DERBY HUNTER", "kind": "person", "status": "hunting"})
	HUNTS.start("derby_hunter", "player", "ashbloom_bone_yard")
	WorldClock.pass_time(HUNTS.TURN_MINUTES / WorldClock.MINUTES_PER_HOUR)
	var derby := DERBY.new()
	derby._advance_world_time(0.0)
	check(int(WorldHistory.subject("derby_hunter").get("hunt_offscreen_turns", 0)) == 1 and str(WorldHistory.subject("derby_hunter").get("hunt_last_elsewhere", "")) == "rift_derby_quarry", "the production derby clock advances an unloaded Bone Yard hunt")
	derby.free()

	print("OFFSCREEN_HUNTS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
