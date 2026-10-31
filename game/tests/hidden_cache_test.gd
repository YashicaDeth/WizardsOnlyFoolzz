extends Node

## Greg, 26 September: stashes (meds and ammo) and secret doors, 5-8 in the
## first 30 minutes, found in K or J, opened with E, a faint seam for plain
## eyes. Walked in the vat room with real K; checked in every other scene.

const HIDDEN_CACHE := preload("res://systems/hidden_cache.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key(node, code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.pressed = true
	node._unhandled_input(press)


func items() -> Array:
	return WorldHistory.subject("inventory").get("items", [])


func has(label: String) -> Dictionary:
	for entry in items():
		if entry is Dictionary and str(entry.get("label", "")) == label:
			return entry
	return {}


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var total := 1  # the weak wall
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	vat.set_physics_process(false)
	await get_tree().process_frame
	if vat.intake != null:
		vat.intake.queue_free()
		vat.intake = null
	vat.phase = "aisle"
	vat.can_move = true
	vat.breakout_complete = true
	vat.sight.enabled = true
	total += vat.caches.size()
	var stash: Dictionary = vat.caches[0]
	vat.player.global_position = Vector3(-5.9, 0.9, -5.75)
	vat.yaw = PI * 0.5
	vat.pitch = 0.0
	vat.player.rotation.y = vat.yaw
	await get_tree().process_frame
	key(vat, KEY_E)
	check(not bool(stash.opened), "to plain eyes the hatch is wall: E does nothing")
	vat.sight.toggle_wizard()
	for _i in 4:
		await get_tree().process_frame
	check(bool(stash.found), "wizard eyes find the hatch")
	vat._update_hud()
	check(str(vat.prompt.text).contains("OPEN THE HATCH"), "the prompt offers it (%s)" % vat.prompt.text)
	key(vat, KEY_E)
	check(bool(stash.opened), "E opens it")
	check(not has("FIELD DRESSING").is_empty(), "a field dressing goes in the inventory")
	check(int(has("LOOSE ROUNDS").get("rounds", 0)) == HIDDEN_CACHE.ROUNDS, "and four loose rounds")
	vat.queue_free()
	await get_tree().process_frame

	var unit = load("res://support_unit.tscn").instantiate()
	add_child(unit)
	for _i in 3:
		await get_tree().process_frame
	total += unit.caches.size()
	var door: Dictionary = {}
	for record: Dictionary in unit.caches:
		HIDDEN_CACHE.mark_found(unit.caches, str(record.id))
		if str(record.kind) == "door":
			door = record
	check(not door.is_empty(), "the Support Unit has a secret door")
	var body: StaticBody3D = door.body
	unit.player.global_position = Vector3(door.at.x - 1.0, 0.9, door.at.z)
	check(unit.interact() == "secret_door", "E opens the secret door")
	await get_tree().process_frame
	check(not is_instance_valid(body), "the door is gone")
	# Walk into the closet: nothing solid left in the doorway.
	unit.player.global_position = Vector3(door.at.x - 0.8, 0.9, door.at.z)
	unit.yaw = -PI * 0.5
	Input.action_press("move_forward")
	for _i in 60:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	check(unit.player.global_position.x > door.at.x + 0.3, "you can walk into the closet (x %.2f)" % unit.player.global_position.x)
	check(unit.interact() == "stash", "the stash inside opens")
	check(int(has("LOOSE ROUNDS").get("rounds", 0)) == HIDDEN_CACHE.ROUNDS * 2, "its rounds join the loose ones")
	unit.queue_free()
	await get_tree().process_frame

	for path in ["res://old_drains.tscn", "res://service_arcade.tscn"]:
		var scene = load(path).instantiate()
		add_child(scene)
		for _i in 3:
			await get_tree().process_frame
		check(scene.caches.size() == 1 and scene.sight.hidden.size() >= 1, "%s has a stash registered with its K/J" % path.get_file())
		total += scene.caches.size()
		scene.queue_free()
		await get_tree().process_frame
	check(total >= 5 and total <= 8, "five to eight hidden things in the first 30 minutes (%d)" % total)
	check(WorldHistory.event_count("hidden_stash_opened") == 2 and WorldHistory.event_count("secret_door_opened") == 1, "every opening is on record")
	print("HIDDEN_CACHE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
