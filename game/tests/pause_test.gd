extends Node

## Escape had no pause behind it in any scene. This asserts the gate exists,
## that it actually stops the tree, that the mixer it exposes reaches real
## audio buses, and that settings survive being closed — a volume that resets
## when you resume is not a setting.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var gate := get_node_or_null("/root/PauseGate")
	check(gate != null, "the pause gate is autoloaded into every scene")
	if gate == null:
		get_tree().quit(1)
		return

	check(gate.process_mode == Node.PROCESS_MODE_ALWAYS, "it keeps running while the tree is paused")

	# G5.1: the buses exist so there is something to turn down.
	for bus_name in gate.BUSES:
		check(AudioServer.get_bus_index(bus_name) != -1, "bus %s exists" % bus_name)

	gate.open_gate()
	check(gate.open and get_tree().paused, "opening stops the tree")
	gate.close()
	check(not gate.open and not get_tree().paused, "closing starts it again")

	# Toggle is what Escape calls, so it has to be symmetric.
	gate.toggle()
	check(get_tree().paused, "toggle pauses")
	gate.toggle()
	check(not get_tree().paused, "toggle resumes")

	# The mixer writes through to the bus and persists.
	gate._set_volume("Music", 0.25)
	var index := AudioServer.get_bus_index("Music")
	check(not is_equal_approx(AudioServer.get_bus_volume_db(index), 0.0), "a volume change reaches the bus")
	check(is_equal_approx(float(WorldHistory.subject("settings").get("volume_music", -1.0)), 0.25), "and is stored on the settings subject")
	gate._set_volume("Music", 0.0)
	check(AudioServer.is_bus_mute(index), "zero mutes rather than leaving an inaudible floor")
	gate._set_volume("Music", 0.8)
	check(not AudioServer.is_bus_mute(index), "and comes back")

	# The violence tier is the same setting the warning card writes.
	var before := str(WorldHistory.subject("settings").get("gore", "FULL"))
	gate._cycle_gore()
	check(str(WorldHistory.subject("settings").get("gore", "")) != before, "violence cycles from the pause menu too")

	# Rows are the menu; settings has to be reachable from root.
	gate.page = "root"
	gate._build_rows()
	var root_ids: Array = []
	for row in gate._rows:
		root_ids.append(str(row.id))
	check(root_ids.has("resume") and root_ids.has("settings") and root_ids.has("menu"), "root offers resume, settings and leaving")
	gate.page = "settings"
	gate._build_rows()
	check(gate._rows.size() >= gate.BUSES.size() + 2, "settings lists every bus plus violence and back")

	print("PAUSE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
