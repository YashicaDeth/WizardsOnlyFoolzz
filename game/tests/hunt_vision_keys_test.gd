extends Node

## Greg, 26 September: in the Hunt, the inventory is on Tab, K tapped is
## wizard eyes, J held is the depth scan, and K held re-decants.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key(hunt, code: int, pressed: bool, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
	hunt._unhandled_input(event)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _f in 5:
		await get_tree().physics_frame
	check(hunt.sight != null and hunt.sight.enabled and not hunt.sight.handle_keys, "the Hunt carries K/J vision and reads the keys itself")

	key(hunt, KEY_TAB, true)
	key(hunt, KEY_TAB, false)
	check(hunt.panel_mode == "inventory", "Tab opens the inventory")
	key(hunt, KEY_TAB, true)
	key(hunt, KEY_TAB, false)
	check(hunt.panel_mode.is_empty(), "and Tab closes it")

	key(hunt, KEY_K, true)
	await get_tree().physics_frame
	key(hunt, KEY_K, false)
	check(hunt.sight.mode == "wizard", "a tap of K opens wizard eyes")
	key(hunt, KEY_K, true)
	key(hunt, KEY_K, false)
	check(hunt.sight.mode == "", "another tap closes them")

	key(hunt, KEY_J, true)
	check(hunt.sight.mode == "depth", "holding J is the depth scan")
	key(hunt, KEY_J, false)
	check(hunt.sight.mode == "", "letting go ends it")

	key(hunt, KEY_K, true)
	var t := 0.0
	while t < hunt.REDECANT_HOLD_SECONDS + 0.3:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	check(hunt._k_fired, "holding K past %.1fs fires the re-decant" % hunt.REDECANT_HOLD_SECONDS)
	key(hunt, KEY_K, false)
	check(hunt.sight.mode == "", "and the release after a hold does not toggle wizard eyes")
	print("HUNT_VISION_KEYS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
