extends Node

## Greg, 29 September: a weapon in a hand is a weapon. A sparring body strikes
## with what it holds (fists if nothing); your guard reads the blow; a parry
## knocks an armed hand open and the weapon lands as a pickup you can take and
## fight with; world bodies no longer wear the placeholder coat slab.

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
	var demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	for _i in 3:
		await get_tree().process_frame
	var armed: Dictionary = demo.bodies[1]
	var bare: Dictionary = demo.bodies[0]
	check(demo._holds_weapon(armed) and not demo._holds_weapon(bare), "odd bodies hold the cleaver, even ones hold nothing")
	var slabs := 0
	for entry: Dictionary in demo.bodies:
		for piece in ["Coat_Front", "Torque_Strap"]:
			slabs += (entry.rig as Node).find_children(piece, "", true, false).size()
	check(slabs == 0, "no placeholder coat slab or strap over their clothes (%d)" % slabs)

	demo.spar_level = 2
	demo.guarding = false
	demo.simulation_health = 100
	armed["swing"] = BladeRead.LEFT
	demo._enemy_strike(armed, armed.holder)
	check(demo.simulation_health == 56, "an open blow lands the cleaver's own 44 (%d)" % demo.simulation_health)
	demo.simulation_health = 100
	bare["swing"] = BladeRead.LEFT
	demo._enemy_strike(bare, bare.holder)
	check(demo.simulation_health == 92, "an empty hand is fists: 8 (%d)" % demo.simulation_health)

	demo.guarding = true
	demo.guard_aim = Vector2(-1, 0)
	demo.guard_held = 1.0
	demo.simulation_health = 100
	demo._enemy_strike(armed, armed.holder)
	check(demo.simulation_health == 92 and demo._holds_weapon(armed), "the right guard held late blocks: most of it stopped, the weapon stays in hand")

	demo.guard_held = 0.05
	demo.simulation_health = 100
	var sparks: int = demo.parry_spark.bursts
	demo._enemy_strike(armed, armed.holder)
	var dropped: Array = demo.weapon_pickups.filter(func(p: Dictionary) -> bool: return bool(p.get("dropped", false)))
	check(demo.simulation_health == 100 and demo.parry_spark.bursts > sparks, "a parry turns it: no damage, and the bind sparks")
	check(not demo._holds_weapon(armed) and dropped.size() == 1, "and knocks the weapon out of the hand onto the floor")

	demo.parry_spark.bursts = 0
	for _i in 30:
		await get_tree().process_frame
	demo.eye = (dropped[0].model as Node3D).global_position + Vector3(0, 1.0, 0)
	check(demo._take_nearest_weapon() and str(demo.arsenal.current_id) == "sword", "E takes it off the floor and you hold the cleaver")

	demo.guarding = false
	demo.simulation_health = 100
	armed["swing"] = BladeRead.LEFT
	demo._enemy_strike(armed, armed.holder)
	check(demo.simulation_health == 92, "disarmed, they are down to fists")

	await demo._reset()
	var left: Array = demo.weapon_pickups.filter(func(p: Dictionary) -> bool: return bool(p.get("dropped", false)))
	check(left.is_empty() and demo._holds_weapon(demo.bodies[1]), "R: dropped weapons go, the new bodies come holding their own")

	print("FIGHT_SANDBOX_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
