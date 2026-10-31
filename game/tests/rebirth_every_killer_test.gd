extends Node

## Every killer in minutes 0-30 sends you to the vat (Greg, 24 September):
## the Lower Works sentinel, the drain bingyanger and a wreck in the derby,
## not just Hollis. Each leaves your old body where you fell, holding what
## you carried and the jester parts you wore; E beside it takes them back.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	# --- the sentinel ---------------------------------------------------------
	WorldHistory.clear_history()
	var carry := Carry.new()
	carry.items.append({"label": "LIFT FUSE", "kind": "tool", "mass": 0.2, "perishes": false, "age": 0.0})
	carry.save_to_history()
	var works = load("res://buried_city.tscn").instantiate()
	add_child(works)
	works.set_physics_process(false)
	await get_tree().process_frame
	works.blood = 5.0
	works.player.global_position = works.patrol.global_position + Vector3(0.8, 0, 0)
	works.patrol_attack_cooldown = 0.0
	works._patrol_step(0.016)
	check(works.blood <= 0.0 and VatRebirth.is_pending(), "the sentinel can kill you now, and a vat is growing the next body")
	var remains := VatRebirth.remains_at("lower_works")
	check(remains.size() == 1 and (remains[0].items as Array).size() == 1, "your old body lies in the Lower Works holding the fuse")
	check(((remains[0].get("outfit", {})) as Dictionary).is_empty(), "and no jester parts: those are only put on in the Hunt")
	works.queue_free()
	VatRebirth.complete()
	var again = load("res://buried_city.tscn").instantiate()
	add_child(again)
	again.set_physics_process(false)
	await get_tree().process_frame
	var body := again.rebirth_site.get_node_or_null(str(remains[0].id)) as Node3D
	check(body != null, "coming back, the old body is lying there")
	again.player.global_position = body.global_position + Vector3(0.5, 0, 0)
	check(not again.rebirth_site.nearest().is_empty(), "and it is in reach")
	check(again.rebirth_site.try_recover().contains("1 THINGS"), "E takes back the fuse")
	again.queue_free()

	# --- dying in the jester set ----------------------------------------------
	WorldHistory.clear_history()
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("jester_death", BaselineHuman.config_from_subject({}))
	Outfit.dress(rig)
	Outfit._save(Outfit.forced_jester())
	var death := VatRebirth.die("bone_yard", "test", "", Vector3.ZERO)
	var left := WorldHistory.subject(str(death.remains_id))
	check(((left.get("outfit", {})) as Dictionary).size() == 4, "dying in the jester set leaves all four parts on the body")
	check((Outfit.worn().parts as Dictionary).is_empty(), "and the new body comes out of the vat bare")
	VatRebirth.recover(str(death.remains_id))
	var garments := 0
	for item in Carry.new().items:
		garments += 1 if str(item.get("kind", "")) == "garment" else 0
	check(garments == 4, "looting the old body gives the four parts back as clothing to put on")

	# --- the drains -----------------------------------------------------------
	WorldHistory.clear_history()
	var drains = load("res://old_drains.tscn").instantiate()
	add_child(drains)
	drains.set_physics_process(false)
	await get_tree().process_frame
	drains.stalker.blood = 6.0
	drains.stalker.global_position = drains.player.global_position + Vector3(0.6, 0, 0)
	drains.stalker._cooldown = 0.0
	drains.stalker._try_strike()
	check(drains.stalker.blood <= 0.0 and VatRebirth.is_pending(), "the bingyanger can kill you now, and you wake in a vat")
	check(VatRebirth.remains_at("old_drains").size() == 1, "your old body stays in the drains")
	drains.queue_free()

	# --- the derby ------------------------------------------------------------
	WorldHistory.clear_history()
	var derby = load("res://rift_derby.tscn").instantiate()
	add_child(derby)
	await get_tree().process_frame
	derby.round_state = "active"
	derby.integrity = 5
	derby._take_hull(8)
	derby._finish_round("lost")
	check(not VatRebirth.is_pending() and derby.derby_rebirth.is_empty(), "a wreck finished off gently is a capture, not a death (Greg)")
	derby.queue_free()
	WorldHistory.clear_history()
	derby = load("res://rift_derby.tscn").instantiate()
	add_child(derby)
	await get_tree().process_frame
	derby.round_state = "active"
	derby.integrity = 5
	derby._take_hull(34)
	derby._finish_round("lost")
	check(derby.crushed() and VatRebirth.is_pending() and not derby.derby_rebirth.is_empty(), "a car crushed far past zero is a death")
	check(str(derby.derby_rebirth.get("scene", "")) != "", "and the Captain's claim decides whose vat grows you back (%s)" % str(derby.derby_rebirth.get("claimant", "")))
	derby.queue_free()

	print("REBIRTH_EVERY_KILLER_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
