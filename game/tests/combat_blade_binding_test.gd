extends Node

## Regression coverage for the input-to-model seams BladeRead cannot prove by
## itself: free first person samples the live arm at contact, lock/third person
## keep release direction, and the Hunt's existing parry clock now respects the
## mouse-selected guard side.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("-- contact-time direction reaches the Hunt --")
	var released := {"kind": "melee", "released_side": BladeRead.HIGH}
	hunt.third_person = false
	hunt.lock_target = ""
	hunt.arm.velocity = Vector3(5.0, 0.0, 0.0)
	check(hunt._committed_attack_side(released) == BladeRead.LEFT,
		"free first person reads the physical arm again at contact")
	check(bool(hunt.last_blade_read.get("first_person", false)),
		"the recorded read identifies the steerable first-person register")

	hunt.lock_target = "commit_probe"
	check(hunt._committed_attack_side(released) == BladeRead.HIGH,
		"a lock commits the release side even before a camera blend completes")
	hunt.lock_target = ""
	hunt.third_person = true
	check(hunt._committed_attack_side(released) == BladeRead.HIGH,
		"third person also keeps the release side")

	print("-- the existing parry clock is directional now --")
	hunt.guarding = true
	hunt.guard_side = BladeRead.LEFT
	hunt.guard_raised = 0.05
	var wrong: Dictionary = hunt.guard_absorb(20.0, Vector3.INF, BladeRead.RIGHT)
	check(not bool(wrong.blocked) and is_equal_approx(float(wrong.damage), 20.0),
		"the wrong mouse guard soaks nothing")
	var parry: Dictionary = hunt.guard_absorb(20.0, Vector3.INF, BladeRead.LEFT)
	check(bool(parry.parried) and is_zero_approx(float(parry.damage)),
		"the matching side inside PARRY_WINDOW is a full parry")
	check(hunt.parry_spark_count == 1 and is_instance_valid(hunt.last_parry_spark),
		"a timed parry has a real contact spark rather than only a damage outcome")
	hunt.guard_raised = BladeRead.PARRY_WINDOW + 0.1
	var block: Dictionary = hunt.guard_absorb(20.0, Vector3.INF, BladeRead.LEFT)
	check(bool(block.blocked) and not bool(block.parried) and float(block.damage) > 0.0,
		"the same side held too long is only a leaking block")
	hunt.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	print("-- sandbox contact is delayed, not an instant rig.hit --")
	var demo = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await get_tree().physics_frame
	demo.arsenal.select_slot(HunterArsenal.SLOT_ORDER.find("sword"))
	demo.arm.velocity = Vector3(0.0, -5.0, 0.0)
	demo._melee_swing()
	check(not demo.pending_melee.is_empty() and demo.melee_windup > 0.0,
		"the sandbox queues a physical swing through its weapon wind-up")
	check(str(demo.pending_melee.get("released_side", "")) == BladeRead.HIGH,
		"and stores the release read for committed third-person contact")

	print("COMBAT_BLADE_BINDING_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
