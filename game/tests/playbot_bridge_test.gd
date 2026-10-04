extends Node

## PlayBot bridge (`tools/playbot.gd`) on a stub room:
##   0. without ATG_PLAYBOT=1 it is not there at all;
##   1. one cmd.json is executed through real input -- walking, a rate-capped
##      look, an E press -- and state.json comes back with the same seq;
##   2. events.jsonl records an invisible wall, a script error, a loading
##      screen with its seconds, a stuck spot and a scene change.

const PLAYBOT := preload("res://tools/playbot.gd")
const STUB := preload("res://tests/playbot_stub.tscn")

var failures: Array[String] = []
var dir := ""


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	dir = "P:/GameDev/Temp/playbot_test_%d" % Time.get_ticks_usec()

	# 0. Gate.
	OS.set_environment("ATG_PLAYBOT", "")
	var off := PLAYBOT.new()
	add_child(off)
	await get_tree().process_frame
	check(not is_instance_valid(off) or not off.active, "without ATG_PLAYBOT=1 the bot does nothing")

	OS.set_environment("ATG_PLAYBOT", "1")
	OS.set_environment("ATG_PLAYBOT_DIR", dir)
	var stub: Node3D = STUB.instantiate()
	add_child(stub)
	var bot: Node = PLAYBOT.new()
	bot.scene_override = stub
	add_child(bot)
	for i in 5:
		await get_tree().process_frame
	var ready_state := _read_state()
	check(ready_state.get("seq", -1) == 0, "state.json is written on start with seq 0")

	# 1. One command.
	var started := Time.get_ticks_msec()
	_write_cmd({"seq": 1, "actions": [
		{"hold": "move_forward", "s": 2.0},
		{"look": [90, 0]},
		{"press": "interact"},
		{"wait": 0.2},
	]})
	await get_tree().create_timer(0.5).timeout
	push_error("playbot test: a deliberate script error")
	var state := await _wait_seq(1, 15.0)
	var took := (Time.get_ticks_msec() - started) / 1000.0
	print("state=", JSON.stringify(state))
	check(state.get("seq", -1) == 1, "state.json comes back with the command's seq")
	check(str(state.get("scene", "")) == "res://tests/playbot_stub.tscn", "state names the scene")
	var position: Array = state.get("position", [0, 0, 0]) if state.get("position") is Array else [0, 0, 0]
	check(float(position[2]) < -3.0, "holding move_forward walked the body forward (z=%s)" % position[2])
	check(absf(float(state.get("yaw_deg", 0.0)) + 90.0) < 1.0, "look [90,0] turned the view 90 degrees right")
	check(took >= 2.0 + 90.0 / PLAYBOT.LOOK_RATE, "the look was rate-capped, not instant (%.2f s)" % took)
	check(stub.interacts == 1 and str(state.get("prompt", "")) == "KNOCKED 1", "press interact reached code that reads KEY_E")
	check(str(state.get("objective", "")).contains("REACH THE WALL"), "state carries the objective text")
	check(state.get("health") == 87, "state carries health")
	check(state.has("fps") and state.get("interstitial_travelling") == false and state.has("dialogue"), "state carries fps, the Interstitial flag and dialogue")
	var log_lines: Array = state.get("log", [])
	check(log_lines.size() > 0 and log_lines.size() <= 20, "state carries up to 20 log lines")
	check(state.get("screenshot") == null and state.has("screenshot_note"), "headless says it has no screenshot instead of writing a blank one")

	# 2. Loading screen, stuck, scene change.
	var interstitial := get_node_or_null("/root/Interstitial")
	bot.stuck_after = 1.0
	_write_cmd({"seq": 2, "actions": [{"look": [-90, 0]}, {"hold": "move_forward", "s": 2.0}]})
	if interstitial != null:
		interstitial.travelling = true
	await get_tree().create_timer(0.6).timeout
	if interstitial != null:
		interstitial.travelling = false
	await _wait_seq(2, 15.0)
	stub.queue_free()
	var other: Node3D = STUB.instantiate()
	add_child(other)
	bot.scene_override = other
	other.scene_file_path = "res://tests/playbot_stub_two.tscn"
	await get_tree().process_frame
	await get_tree().process_frame

	var events := _events()
	var types: Array = events.map(func(row: Dictionary) -> String: return str(row.get("type")))
	print("events=", types)
	check(types.has("invisible_wall"), "walking into the bare wall logs invisible_wall")
	check(_find(events, "script_error").get("text", "").contains("deliberate"), "a script error is logged")
	var loading := _find(events, "loading_end")
	check(interstitial != null and types.has("loading_start") and float(loading.get("seconds", 0.0)) >= 0.5, "a loading screen logs start and end with its seconds")
	check(types.has("stuck"), "acting with no progress logs stuck")
	check(str(_find(events, "scene_change").get("to", "")) == "res://tests/playbot_stub_two.tscn", "a scene change is logged")

	bot.queue_free()
	OS.set_environment("ATG_PLAYBOT", "")
	print("PLAYBOT_BRIDGE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _write_cmd(cmd: Dictionary) -> void:
	var file := FileAccess.open(dir.path_join("cmd.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(cmd))
	file.close()


func _read_state() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("state.json")))
	return parsed if parsed is Dictionary else {}


func _wait_seq(seq: int, timeout: float) -> Dictionary:
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		var state := _read_state()
		if int(state.get("seq", -1)) >= seq:
			return state
		await get_tree().process_frame
	return {}


func _events() -> Array:
	var out := []
	for line in FileAccess.get_file_as_string(dir.path_join("events.jsonl")).split("\n", false):
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary:
			out.append(row)
	return out


func _find(events: Array, type: String) -> Dictionary:
	for row: Dictionary in events:
		if row.get("type") == type:
			return row
	return {}
