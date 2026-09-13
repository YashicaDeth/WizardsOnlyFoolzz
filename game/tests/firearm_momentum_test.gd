extends Node

## AN1.7. "Firearms run through the same object — the barrel swivels toward
## where you look and carries past it." `limb_momentum.gd`'s `ARM_WEIGHTS`
## already listed a shotgun and a sidearm alongside the sword, and
## `_carry_current_weapon()`/`_pose_weapon()` in `bone_yard_hunt.gd` already
## read `arsenal.current_id` generically rather than branching on melee vs
## firearm — this was wired the same day as the sword, not added for this
## segment. What had never been exercised is whether it actually reaches a
## firearm's own viewmodel: `_pose_weapon()` only ever touched
## `arsenal.models[current_id]` for whichever weapon has been equipped in a
## real playthrough, and every existing momentum test drives `LimbMomentum`
## in isolation with hand-picked mass/reach rather than through an equipped
## gun.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## Equips the given slot, throws the arm with a hard sideways look, and
## returns [mass after carrying it, reach after carrying it, how far the
## weapon's own model actually moved off its authored rest position].
func _swing(hunt: Node, slot: int) -> Array:
	hunt._equip_weapon(slot)
	# Reset to a clean rest state first — `carry()` swaps mass/reach but
	# deliberately never touches `at`/`velocity` (a weapon change mid-swing
	# should not un-throw the arm), so without this a later weapon would
	# inherit whatever the previous one's swing left behind.
	hunt.arm.at = hunt.arm.anchor
	hunt.arm.velocity = Vector3.ZERO
	hunt.arm.spin = Vector2.ZERO
	hunt.arm.tilt = Vector2.ZERO
	hunt._advance_arm(1.0 / 60.0) # lets _carry_current_weapon() re-carry before the throw
	hunt.apply_look(Vector2(0.22, 0.0))
	hunt._advance_arm(1.0 / 60.0)
	var model: Node3D = hunt.arsenal.models.get(str(hunt.arsenal.current_id)) as Node3D
	var rest: Vector3 = model.get_meta("rest_position")
	var displacement := model.position.distance_to(rest)
	return [hunt.arm.mass, hunt.arm.reach, displacement]


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	var sword := _swing(hunt, 0)
	check(is_equal_approx(float(sword[0]), 1.45) and is_equal_approx(float(sword[1]), 0.62), "equipping the sword carries its authored mass and reach onto the arm (%s/%s)" % [str(sword[0]), str(sword[1])])
	check(float(sword[2]) > 0.001, "and a hard turn visibly displaces the sword's own model off its rest pose (%.4fm)" % float(sword[2]))

	var shotgun := _swing(hunt, 1)
	check(is_equal_approx(float(shotgun[0]), 3.2) and is_equal_approx(float(shotgun[1]), 0.5), "switching to the shotgun re-carries the arm with the shotgun's own mass and reach (%s/%s)" % [str(shotgun[0]), str(shotgun[1])])
	check(float(shotgun[2]) > 0.001, "and the same hard turn visibly displaces the shotgun's own model, not just the sword's (%.4fm)" % float(shotgun[2]))

	var sidearm := _swing(hunt, 2)
	check(is_equal_approx(float(sidearm[0]), 0.95) and is_equal_approx(float(sidearm[1]), 0.22), "switching to the sidearm re-carries the arm with the sidearm's own mass and reach (%s/%s)" % [str(sidearm[0]), str(sidearm[1])])
	check(float(sidearm[2]) > 0.001, "and the sidearm's own model displaces too (%.4fm)" % float(sidearm[2]))

	# The whole point of AN1.5's per-weapon mass: a heavier gun should not
	# swing exactly like a light one. The shotgun is more than three times the
	# sidearm's mass, so thrown by the identical turn it should lag further
	# behind, not travel the same distance by coincidence of the numbers above.
	check(float(shotgun[2]) > float(sidearm[2]), "the heavier shotgun lags further off-anchor than the lighter sidearm under the identical turn (%.4fm vs %.4fm)" % [float(shotgun[2]), float(sidearm[2])])

	if failures.is_empty():
		print("firearm momentum: the swivel and the lag are the one object, for every weapon")
		get_tree().quit(0)
	else:
		print("firearm momentum FAILURES: ", failures)
		get_tree().quit(1)
