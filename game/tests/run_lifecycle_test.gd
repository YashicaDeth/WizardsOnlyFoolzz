extends Node

## T1.2. A permanent death must be a rich recorded event — where the run had
## reached, what was carried, where they stood — not a bare flag.

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

	check(RunLifecycle.record_death("nobody", "test").is_empty(), "a subject that does not exist records nothing")

	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "grudge": 12, "faction_id": "celloutz"})
	OpeningDirector.advance("woke")
	OpeningDirector.advance("entered_pit")
	var carry := Carry.new()
	carry.items.append({"label": "SEVERED LEFT ARM", "kind": "limb", "mass": 5.5, "perishes": true, "condition": 1.0})
	carry.save_to_history()

	var death := RunLifecycle.record_death("player", "crushed in the derby", {"location": "bone_yard_pit"})
	check(not death.is_empty(), "a real subject's death is recorded")
	check(str(death.get("cause", "")) == "crushed in the derby", "the real cause is recorded, not a generic flag")
	check(str(death.get("stage", "")) == "entered_pit", "where the run had actually reached is captured")
	check(death.get("carried", []).size() == 1 and str(death.carried[0]) == "SEVERED LEFT ARM", "what was actually being carried is captured")
	check(death.get("alignment", 0.0) < 0.0, "where they stood on the axis is captured (celloutz-aligned, %.2f)" % death.alignment)
	check(int(death.get("grudge", -1)) == 12, "their real grudge total is captured")
	check(str(death.get("location", "")) == "bone_yard_pit", "extra circumstance details pass through untouched")

	var events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "permanent_death")
	check(events.size() == 1, "it is a real recorded event, not just a return value (%d)" % events.size())

	var history := RunLifecycle.death_history()
	check(history.size() == 1 and str(history[0].get("subject_id", "")) == "player", "death_history() reads it back correctly")

	print("RUN_LIFECYCLE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
