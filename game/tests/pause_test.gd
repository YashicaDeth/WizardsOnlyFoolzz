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

	# Y1.1. Controls are rebindable, reachable from the same settings page.
	var settings_ids: Array = []
	for row in gate._rows:
		settings_ids.append(str(row.id))
	check(settings_ids.has("controls"), "settings offers a way into controls")

	gate.page = "controls"
	gate._build_rows()
	var control_ids: Array = []
	for row in gate._rows:
		control_ids.append(str(row.id))
	for action in gate.CONTROL_ACTIONS:
		check(control_ids.has("bind_%s" % action), "controls lists %s" % action)
	check(control_ids.has("ctrl_reset") and control_ids.has("ctrl_back"), "controls offers reset and a way back")

	var default_crouch: int = int(gate._default_binds.get("crouch", -1))
	check(default_crouch != -1, "the crouch default was captured before any rebind")
	var rebind_event := InputEventKey.new()
	rebind_event.physical_keycode = KEY_C
	gate._apply_rebind("crouch", rebind_event)
	var bound: Array = InputMap.action_get_events("crouch")
	check(bound.size() == 1 and (bound[0] as InputEventKey).physical_keycode == KEY_C, "rebinding crouch actually changes the InputMap")
	check(int(WorldHistory.subject("settings").get("keybind_crouch", -1)) == KEY_C, "and the rebind is stored on the settings subject")
	gate._reset_keybinds()
	var restored: Array = InputMap.action_get_events("crouch")
	check(restored.size() == 1 and (restored[0] as InputEventKey).physical_keycode == default_crouch, "reset to default puts crouch back")
	check(int(WorldHistory.subject("settings").get("keybind_crouch", -1)) == default_crouch, "and the reset is stored too")

	print("PAUSE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
