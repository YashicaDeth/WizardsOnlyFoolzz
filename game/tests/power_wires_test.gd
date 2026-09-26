extends Node

## Greg, 26 September: the vision modes reveal "wires and power". Seen in K,
## a power line can be cut with E at its junction: a vat-room bay goes dark,
## a Support Unit camera goes blind, quietly.

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


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
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
	var wires: Array = vat.sight.wires
	check(wires.size() == vat.strip_lights.size() and wires.size() >= 5, "every bay's strip light has a power line (%d)" % wires.size())
	var wire: Dictionary = wires[2]
	var junction: Vector3 = wire.points[0]
	var strip: OmniLight3D = vat.strip_lights[2]
	vat.player.global_position = Vector3(-5.9, 0.9, junction.z)
	vat.yaw = PI * 0.5
	vat.pitch = 0.0
	vat.player.rotation.y = vat.yaw
	await get_tree().process_frame
	key(vat, KEY_E)
	check(strip.visible and not bool(wire.get("cut", false)), "unseen, the line cannot be cut")
	vat.sight.toggle_wizard()
	for _i in 4:
		await get_tree().process_frame
	check(bool(wire.get("seen", false)), "wizard eyes show the line")
	vat._update_hud()
	check(str(vat.prompt.text).contains("CUT THE POWER LINE"), "the prompt offers the cut (%s)" % vat.prompt.text)
	key(vat, KEY_E)
	check(bool(wire.get("cut", false)) and not strip.visible, "E cuts it and that bay goes dark")
	check(WorldHistory.event_count("power_wire_cut") == 1, "the cut is recorded")
	vat.queue_free()
	await get_tree().process_frame

	var unit = load("res://support_unit.tscn").instantiate()
	add_child(unit)
	for _i in 3:
		await get_tree().process_frame
	var feeds: Array = unit.sight.wires
	check(feeds.size() == unit.cameras.size() and feeds.size() > 0, "every camera has a feed line (%d)" % feeds.size())
	var feed: Dictionary = feeds[0]
	var lens = unit.cameras[0]
	feed["seen"] = true
	var at: Vector3 = feed.points[0]
	unit.player.global_position = Vector3(at.x - signf(at.x) * 0.9, 0.9, at.z)
	check(unit.interact() == "wire", "E at the junction cuts the camera feed")
	check(lens.broken, "and the camera is blind")
	check(str(WorldHistory.subject(lens.camera_id).get("broken_by", "")) == "wire_cut", "broken by the wire, on record")
	print("POWER_WIRES_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
