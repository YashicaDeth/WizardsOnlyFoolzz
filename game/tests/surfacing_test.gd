extends Node
## Greg's playtest: surfacing is short, silent then wind, and the title drop
## plays once per save and cannot be skipped.

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _ready() -> void:
	WorldHistory.clear_history()
	var before := AudioServer.get_bus_volume_db(0)
	var first = load("res://systems/surfacing.gd").new()
	add_child(first)
	first.begin({})
	check(first.title_drop, "the first surfacing drops the title")
	check(AudioServer.get_bus_volume_db(0) <= -79.0, "the facility's sound cuts to silence")
	check(not first.has_method("_unhandled_input") and not first.has_method("_input"), "nothing in it listens for a key, so the title cannot be skipped")
	for _step in 40:
		first._process(0.1)
	check(absf(AudioServer.get_bus_volume_db(0) - before) < 0.01, "then the world and the wind come back (%.1f dB)" % AudioServer.get_bus_volume_db(0))
	check(first.KEYS_AT < 4.0, "keys are up inside four seconds")
	first.queue_free()
	var again = load("res://systems/surfacing.gd").new()
	add_child(again)
	again.begin({})
	check(not again.title_drop, "the second surfacing on this save does not drop it again")
	again.queue_free()
	AudioServer.set_bus_volume_db(0, before)
	print("SURFACING_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
