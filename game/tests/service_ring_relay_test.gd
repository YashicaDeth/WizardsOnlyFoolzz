extends Node3D

const RELAY := preload("res://systems/service_ring_relay.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var relay = RELAY.new()
	relay.build(0)
	add_child(relay)
	await get_tree().process_frame
	check(relay.get_child_count() >= 6, "a relay is a physical authored assembly, not a marker")
	check(relay.advance_scan(0.0, relay.global_position + Vector3(10, 0, 0)) > 0.0, "the moving surveillance head can acquire a vehicle in its cone")
	var disabled_signals := [0]
	relay.relay_disabled.connect(func(_index, _cause): disabled_signals[0] += 1)
	relay.take_hit("cab_round")
	relay.take_hit("cab_round")
	check(not relay.disabled and relay.hits == 2, "two pistol hits visibly damage but do not disable the relay")
	relay.take_hit("ram")
	check(relay.disabled and relay.hits == relay.MAX_HITS, "the third physical hit disables it")
	check(disabled_signals[0] == 1, "disable emits once with no duplicate objective credit")
	check(relay.advance_scan(0.1, relay.global_position + Vector3(10, 0, 0)) == 0.0, "a disabled relay can no longer scan")
	relay.take_hit("cab_round")
	check(disabled_signals[0] == 1, "shooting dead hardware cannot farm the signal")
	print("SERVICE_RING_RELAY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
