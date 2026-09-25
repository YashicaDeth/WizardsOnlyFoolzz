extends Node

## The ledger in the real Hunt: a real swing and a real death pay the weapon in
## hand, the popup shows it, 7 opens the tree, and an unlock reaches the swing.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	var ledger: BloodLedger = hunt.blood_ledger
	check(ledger != null and ledger.is_inside_tree(), "the Hunt builds a blood ledger")
	check(ledger.readout != null and ledger.readout.get_parent() == hunt.get_node("HUD"), "the popup lives on the Hunt's HUD")
	hunt.third_person = true
	hunt.lock_target = ""
	var at: Vector3 = hunt.player + Vector3(0, -0.5, 2.0)
	hunt._spawn_encounter_actor({"instance_id": "blood_mark", "kind": "hostile"}, at)
	var actor: Dictionary = hunt.encounter_actors.back()
	actor.node.position = at
	await get_tree().physics_frame
	hunt.yaw = 0.0
	hunt.pitch = 0.0
	hunt._toggle_lock()
	# Physics is off here, so perception never ran: say plainly the body in
	# front of you has seen you, or the blow would also count as unseen.
	hunt.player_unseen = false
	hunt._equip_weapon(0)
	check(str(hunt.arsenal.current_id) == "sword", "the cleaver is in hand")
	var before := ledger.weapon_blood("sword")
	# Enemies block by tier now (Greg, 24 September); caught mid-wind-up they
	# cannot, so this blow is struck into their swing and always lands.
	actor["attack_time"] = hunt._actor_attack_cycle(actor) * 0.95
	var swing: Dictionary = hunt.arsenal.begin_attack()
	swing["range"] = 9.0
	check(hunt._attack_nearest_encounter_actor(swing), "the swing lands on the marked body")
	var after_hit := ledger.weapon_blood("sword")
	check(after_hit > before, "a real Hunt hit pays the cleaver (%d -> %d)" % [before, after_hit])
	check(ledger.readout.active_count() >= 1 and ledger.readout.text_of(ledger.readout.active_count() - 1).ends_with("// ASHLINE CLEAVER"), "the popup names the weapon: %s" % ledger.readout.text_of(ledger.readout.active_count() - 1))
	hunt._kill_encounter_actor(hunt.encounter_actors.find(actor), "test")
	check(ledger.weapon_blood("sword") == after_hit + int(BloodTrees.RATES.kill), "the real death pays the cleaver the kill (%d)" % ledger.weapon_blood("sword"))

	var seven := InputEventKey.new()
	seven.keycode = KEY_7
	seven.pressed = true
	hunt._unhandled_input(seven)
	check(ledger.tree_view.visible, "7 opens the blood tree in the Hunt")
	hunt._unhandled_input(seven)
	check(not ledger.tree_view.visible, "7 closes it again")

	# Enough blood for FIRST CUT, then the Hunt's own swing report carries it.
	ledger.credit("sword", 40, "hit")
	var base := float(HunterArsenal.WEAPONS.sword.damage)
	check(ledger.is_unlocked("first_cut"), "FIRST CUT opens by itself in the Hunt")
	hunt.arsenal.cooldown = 0.0
	var learned: Dictionary = hunt.arsenal.begin_attack()
	check(is_equal_approx(float(learned.damage), base * 1.10), "the Hunt's next swing carries the learned damage (%.2f)" % float(learned.damage))

	print("BLOOD_LEDGER_HUNT_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
