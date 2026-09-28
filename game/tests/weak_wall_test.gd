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
	check(WorldHistory.event_count("signal_sight_found_hidden") >= 1, "the find is recorded (the den's stash can be noticed too)")
	vat._update_hud()
	check(str(vat.prompt.text).contains("HOLLOW WALL"), "the prompt offers it (%s)" % vat.prompt.text)
	key(vat, KEY_K)

	key(vat, KEY_E)
	await get_tree().process_frame
	check(vat.weak_wall_broken, "E shoulders through")
	check(not is_instance_valid(vat.weak_wall_body) or vat.weak_wall_body.is_queued_for_deletion(), "the panel is gone")
	check(WorldHistory.event_count("growing_floor_weak_wall_broken") == 1, "the break is recorded")

	# Greg, 28 September: behind the wall is a hidden den, not a shortcut.
	vat.player.global_position = vat.den_centre + Vector3(1.0, vat.BODY_HALF_HEIGHT + 0.05, 0.6)
	await get_tree().physics_frame
	check(vat._in_den(), "through the hole is a room")
	check(vat.get_node_or_null("DenRemains") != null, "someone died on a bedroll in there")
	check((vat.sight.get("spirits") as Array).size() >= 2, "and K shows their spirit where they lay")
	vat.player.global_position = Vector3(-7.85 - 1.1, vat.BODY_HALF_HEIGHT + 0.05, vat.WEAK_WALL_AT.z + vat.DEN_HALF - 1.2)
	vat._interact()
	check(vat.den_notes_read, "E reads their notes (still unreadable: Greg names them later)")
	var shiv: Node3D = vat.get_node("DenShiv")
	vat.player.global_position = shiv.global_position + Vector3(0.6, vat.BODY_HALF_HEIGHT, 0)
	vat._interact()
	check(not shiv.visible and VatRebirth.carries(vat.DEN_WEAPON_LABEL), "E takes the shiv they made")
	var stash_found := false
	for record: Dictionary in vat.caches:
		if str(record.id) == "growing_floor_den_stash":
			stash_found = true
	check(stash_found, "and a stash is hidden in there")
	check(not vat.shortcut_taken, "no shortcut any more")
	vat.queue_free()
	await get_tree().process_frame
	print("WEAK_WALL_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
