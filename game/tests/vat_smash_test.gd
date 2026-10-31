extends Node

## Greg, 24 September: "make sure you're able to smash the glass and let the
## liquid and the yangas out of the vats post creation". Driven through the
## real click, not the helper.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func click(vat) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	vat._unhandled_input(press)


func face(vat, tank: Dictionary) -> void:
	var at: Vector3 = tank.at
	var side := -signf(at.x)
	vat.player.global_position = at + Vector3(side * 1.5, 0.9, 0.0)
	var to: Vector3 = at + Vector3(0, 1.5, 0) - vat.camera.global_position
	vat.yaw = atan2(-to.x, -to.z)
	vat.pitch = 0.0
	vat.player.rotation.y = vat.yaw
	vat.camera.rotation = Vector3(0, 0, 0)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	vat.set_physics_process(false)
	await get_tree().process_frame
	var smash = vat.vat_smash
	check(smash != null and smash.tanks.size() >= 8, "every other tank on the floor can be broken (%d)" % (smash.tanks.size() if smash else 0))
	var tank: Dictionary = smash.tanks[3]
	face(vat, tank)
	await get_tree().process_frame
	click(vat)
	check(int(tank.hits) == 0, "not before creation: still in your own tank, a click breaks nothing")

	# Out of the tank.
	vat.intake._finish_filing()
	await get_tree().process_frame
	vat._breach()
	vat.phase = "aisle"
	vat.can_move = true
	face(vat, tank)
	await get_tree().process_frame
	check(smash.aimed(vat.camera) == 3, "looking at a tank up close picks it")
	vat._update_hud()
	check(vat.prompt.text.contains("SMASH THE GLASS"), "and the prompt says so (%s)" % vat.prompt.text)
	var needed: int = smash.blows_needed(vat.doctor_route.held_weapon())
	for blow in needed - 1:
		click(vat)
	check(int(tank.hits) == needed - 1 and not bool(tank.broken), "each blow cracks it (%d to break, with %s)" % [needed, vat.doctor_route.held_weapon()])
	check((tank.root as Node3D).get_node_or_null("Cracks") != null and (tank.root as Node3D).get_node("Cracks").get_child_count() > 0, "and you can see the cracks")
	click(vat)
	check(bool(tank.broken) and not (tank.glass as Node3D).visible, "the last blow breaks the glass out")
	await get_tree().process_frame
	check((tank.root as Node3D).get_node_or_null("Cracks") == null, "and the cracks go with it")
	check(WorldHistory.event_count("growing_floor_vat_smashed") == 1, "the world records the smashed tank")
	for _step in 30:
		smash.step(0.1)
	var medium := tank.medium as MeshInstance3D
	check(medium.scale.y < 0.1, "the liquid drains out (level %.2f)" % medium.scale.y)
	check(tank.puddle != null and (tank.puddle as Node3D).scale.x > 0.8, "and spreads across the grating")
	var loose = tank.freed
	check(loose != null and is_instance_valid(loose) and loose.state == "loose", "the subject inside climbs out, loose")
	check(loose.attitude in ["friendly", "hostile"], "friendly or hostile by its own roll (%s)" % loose.attitude)
	var record := WorldHistory.subject("growing_floor_subject_%d" % int(tank.seed))
	check(str(record.get("status", "")) == "loose" and str(record.get("place", "")) == "growing_floor", "and the world knows it was freed from the Growing Floor")
	var curled = tank.curled
	check(curled == null or not (curled as Node3D).visible, "nothing is left floating in the empty tank")
	check(smash.aimed(vat.camera) != 3, "a broken tank can't be broken again")
	check(smash.blows_needed("restraint") < smash.blows_needed(""), "the restraint breaks glass faster than fists")
	print("VAT_SMASH_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
