extends Node

## AN1.9. A grapple, a shove and a bare hand are the same object with a
## different mass. Holding somebody takes both hands regardless of what is
## holstered, so it pre-empts the weapon and the bare-hand state; pushing for
## advantage during the hold commits the whole body's weight, which is why
## it is even heavier than just holding on.

const HUNT := preload("res://bone_yard_hunt.tscn")

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
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	hunt._equip_weapon(0)
	hunt._carry_current_weapon()
	check(is_equal_approx(hunt.arm.mass, hunt.ARM_WEIGHTS.sword.mass), "holding the sword carries the sword's own mass (%.2f)" % hunt.arm.mass)

	hunt._spawn_encounter_actor({"instance_id": "grapple_mass_probe", "kind": "hostile"}, hunt.player + Vector3(0, -0.5, 1))
	var actor: Dictionary = hunt.encounter_actors.back()
	hunt.grapple_target = str(actor.subject_id)

	hunt.grapple_pushing_override = false
	hunt.grapple_pushing_now = false
	hunt._carry_current_weapon()
	check(is_equal_approx(hunt.arm.mass, hunt.ARM_WEIGHTS.grapple.mass), "just holding on carries the grapple's own mass, not the sword's (%.2f)" % hunt.arm.mass)
	check(hunt.ARM_WEIGHTS.grapple.mass > hunt.ARM_WEIGHTS.bare.mass, "and that mass is real weight over an empty fist")

	hunt.grapple_pushing_now = true
	hunt._carry_current_weapon()
	check(is_equal_approx(hunt.arm.mass, hunt.ARM_WEIGHTS.shove.mass), "pushing for advantage carries the heavier shove mass (%.2f)" % hunt.arm.mass)
	check(hunt.ARM_WEIGHTS.shove.mass > hunt.ARM_WEIGHTS.grapple.mass, "forcing your weight into it outweighs just holding on")

	hunt._break_grapple()
	check(not hunt.grapple_pushing_now, "breaking the hold clears the pushing state too")
	hunt._carry_current_weapon()
	check(is_equal_approx(hunt.arm.mass, hunt.ARM_WEIGHTS.sword.mass), "letting go hands the arm back to whatever was actually equipped (%.2f)" % hunt.arm.mass)

	hunt._put_the_weapons_down()
	hunt._carry_current_weapon()
	check(is_equal_approx(hunt.arm.mass, hunt.ARM_WEIGHTS.bare.mass), "and bare hands still carry their own lighter mass, unrelated to any of this (%.2f)" % hunt.arm.mass)

	if failures.is_empty():
		print("grapple mass: a hold, a push and a fist all answer through the same arm")
		get_tree().quit(0)
	else:
		print("grapple mass FAILURES: ", failures)
		get_tree().quit(1)
