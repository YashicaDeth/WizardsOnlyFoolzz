extends Node

## Greg, 26 September: the first hidden thing is a weak wall in the Growing
## Floor, a shortcut found with wizard eyes. To plain eyes it is wall; K shows
## it; E shoulders through; the crawlway lands you in the Service Arcade past
## its pressure gate, where the exit onward is open to you.

const SERVICE_ARCADE := preload("res://service_arcade.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key(vat, code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.pressed = true
	vat._unhandled_input(press)
	if vat.sight != null:
		vat.sight._unhandled_input(press)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	vat.set_physics_process(false)
	await get_tree().process_frame
	# Past intake: the form is filed and gone, as it is by the time you walk.
	if vat.intake != null:
		vat.intake.queue_free()
		vat.intake = null
	vat.phase = "aisle"
	vat.can_move = true
	vat.breakout_complete = true
	vat.sight.enabled = true
	check(vat.weak_wall_body != null and vat.weak_wall_body.name == "WeakWall", "the weak panel is its own piece of the left wall")

	# Stand in the aisle facing it.
	vat.player.global_position = Vector3(-6.2, 0.9, vat.WEAK_WALL_AT.z)
	vat.yaw = PI * 0.5
	vat.pitch = 0.0
	vat.player.rotation.y = vat.yaw
	await get_tree().process_frame
	key(vat, KEY_E)
	check(not vat.weak_wall_broken, "to plain eyes it is wall: E does nothing")
	for _i in 5:
		await get_tree().process_frame
	check(not vat.weak_wall_found, "not found without the modes")

	key(vat, KEY_K)
	for _i in 5:
		await get_tree().process_frame
	check(vat.sight.mode == "wizard", "K: wizard eyes")
	check(vat.weak_wall_found, "wizard eyes show the hollow wall")
	check(WorldHistory.event_count("signal_sight_found_hidden") == 1, "the find is recorded")
	vat._update_hud()
	check(str(vat.prompt.text).contains("HOLLOW WALL"), "the prompt offers it (%s)" % vat.prompt.text)
	key(vat, KEY_K)

	key(vat, KEY_E)
	await get_tree().process_frame
	check(vat.weak_wall_broken, "E shoulders through")
	check(not is_instance_valid(vat.weak_wall_body) or vat.weak_wall_body.is_queued_for_deletion(), "the panel is gone")
	check(WorldHistory.event_count("growing_floor_weak_wall_broken") == 1, "the break is recorded")

	# Walk into the crawlway.
	vat.set_physics_process(true)
	Input.action_press("move_forward")
	var t := 0.0
	while not vat.shortcut_taken and t < 6.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_forward")
	check(vat.shortcut_taken, "walking into the duct takes the shortcut (%.1fs)" % t)
	check(SERVICE_ARCADE.arrive_by_duct, "the arcade is told you are coming by the duct")
	check(WorldHistory.event_count("growing_floor_shortcut_taken") == 1, "the shortcut is recorded")
	vat.queue_free()
	await get_tree().process_frame

	var arcade = load("res://service_arcade.tscn").instantiate()
	add_child(arcade)
	await get_tree().process_frame
	check(not SERVICE_ARCADE.arrive_by_duct, "the arrival is spent")
	check(arcade.player.global_position.z < arcade.GATE_AT.z - 2.0, "you arrive past the pressure gate (%s)" % str(arcade.player.global_position))
	check(not arcade.gate_open, "the gate itself was never opened")
	arcade.player.global_position = arcade.EXIT_AT + Vector3(0, 1.0, 1.0)
	check(arcade._onward_open(), "and the way on to Lower Works is open to you")
	arcade.queue_free()
	await get_tree().process_frame

	var plain = load("res://service_arcade.tscn").instantiate()
	add_child(plain)
	await get_tree().process_frame
	check(plain.player.global_position.distance_to(plain.ENTRY) < 0.5, "an ordinary entry still starts at the front")
	print("WEAK_WALL_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
