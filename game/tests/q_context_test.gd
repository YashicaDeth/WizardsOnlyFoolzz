extends Node

const HUNT := preload("res://bone_yard_hunt.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _q(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_Q
	event.pressed = pressed
	return event


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt := HUNT.instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	var full_stamina: float = hunt.stamina
	var surge_before := PlayerActionLedger.count("prosthetic_surge_used")
	hunt._unhandled_input(_q(true))
	check(is_equal_approx(hunt.stamina, full_stamina),
		"pressing Q begins a possible scan without immediately spending stamina")
	hunt._update_xray(0.4, true)
	check(hunt.xray_active and hunt.handheld.radial.is_open,
		"holding Q keeps the X-ray active and opens its wheel")
	check(is_equal_approx(hunt.stamina, full_stamina),
		"the readable X-ray and wheel are not stamina-gated")
	hunt._update_xray(0.6, true)
	check(hunt.xray_active and hunt.handheld.radial.is_open,
		"the scan remains open for as long as Q remains held")
	hunt._unhandled_input(_q(false))
	hunt._update_xray(0.0, false)
	check(PlayerActionLedger.count("prosthetic_surge_used") == surge_before,
		"releasing a held scan does not also fire the prosthetic surge")
	check(not hunt.xray_active and not hunt.handheld.radial.is_open,
		"release closes both scan and wheel cleanly")

	# The same key still has a deliberate quick combat verb.
	hunt._unhandled_input(_q(true))
	hunt._update_xray(0.10, true)
	hunt._unhandled_input(_q(false))
	hunt._update_xray(0.0, false)
	check(is_equal_approx(hunt.stamina, full_stamina - 35.0),
		"a genuine tap spends the authored surge cost once")
	check(PlayerActionLedger.count("prosthetic_surge_used") == surge_before + 1,
		"tap-Q records one surge rather than a scan and surge together")

	print("Q_CONTEXT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
