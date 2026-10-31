extends Node

## Greg, 26 September: "you can't jump out of here in the sewers, it's dumb."
## Dropped in the channel or the deep cistern, SPACE facing the edge climbs
## you out; on open floor it jumps. Driven with input actions and yaw only
## after placing the player in the water.

var failures: Array[String] = []
var drains


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func settle(frames := 20) -> void:
	for i in frames:
		await get_tree().physics_frame


func space() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.pressed = true
	drains._unhandled_input(e)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	drains = load("res://old_drains.tscn").instantiate()
	add_child(drains)
	await settle(5)

	# In the gallery channel, facing the walkway on the right.
	drains.player.global_position = Vector3(0.3, 0.6, -10.0)
	drains.yaw = -PI * 0.5
	await settle()
	var before: float = drains.player.global_position.y
	check(before < 0.6, "standing in the channel (%.2f)" % before)
	space()
	await settle(40)
	var at: Vector3 = drains.player.global_position
	check(at.y > 0.8 and at.x > 1.0, "SPACE at the channel wall climbs onto the walkway (%s)" % str(at))

	# In the deep cistern, beside the causeway.
	drains.player.global_position = Vector3(1.9, -0.2, -35.0)
	drains.yaw = PI * 0.5
	await settle()
	check(drains.player.global_position.y < -0.2, "standing in the deep water (%.2f)" % drains.player.global_position.y)
	space()
	await settle(40)
	at = drains.player.global_position
	check(at.y > 0.8 and absf(at.x) < 1.3, "SPACE at the causeway climbs out of the cistern (%s)" % str(at))
	check(WorldHistory.event_count("drains_climbed_out") == 2, "both climbs recorded")

	# On the causeway, nothing ahead to climb: an ordinary jump.
	drains.yaw = 0.0
	await settle()
	var floor_y: float = drains.player.global_position.y
	check(drains.jump_or_climb() == "jump", "open floor: SPACE jumps")
	var peak := floor_y
	for i in 30:
		await get_tree().physics_frame
		peak = maxf(peak, drains.player.global_position.y)
	check(peak > floor_y + 0.4, "and leaves the ground (%.2f up)" % (peak - floor_y))
	await settle(30)
	check(absf(drains.player.global_position.y - floor_y) < 0.1, "and lands")

	# Then on to the grate on input alone.
	Input.action_press("move_forward")
	var t := 0.0
	while drains.player.global_position.distance_to(drains.EXIT_AT) > 3.5 and t < 30.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Input.action_release("move_forward")
	check(drains.player.global_position.distance_to(drains.EXIT_AT) <= 3.5, "and walk on to the grate (%.1fs)" % t)
	print("OLD_DRAINS_CLIMB_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
