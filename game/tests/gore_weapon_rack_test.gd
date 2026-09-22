extends Node

## AF6.1. The range arsenal is made of objects in the room. This drives the
## actual E-action seam: out of reach it changes nothing; inside reach the same
## authored model leaves the rack and its live HunterArsenal weapon enters the
## player's hands.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var demo: Node = load("res://gore_demo.tscn").instantiate()
	add_child(demo)
	await get_tree().physics_frame

	var pickups: Array = demo.get("weapon_pickups")
	# The three issued weapons, and then the rifle. The rifle is deliberately
	# not in `SLOT_ORDER` -- `arsenal_test` asserts the hunter carries three,
	# and the rifle is found rather than issued -- but the range needs one on
	# the wall, because without it nothing in the sandbox can earn the X-ray
	# finisher and `KillShot` is unreachable in the one scene built to show it.
	#
	# The set is still pinned. The point of this check is that the rack cannot
	# quietly drift from the arsenal, and that holds just as well against a
	# list of four as against a list of three.
	var expected: Array[String] = []
	expected.assign(HunterArsenal.SLOT_ORDER)
	expected.append("sniper")
	check(pickups.size() == expected.size(), "the shed carries every issued weapon, and the found rifle")
	var identities: Array[String] = []
	for pickup: Dictionary in pickups:
		var weapon_id := str(pickup.get("weapon", ""))
		var model := pickup.get("model") as Node3D
		identities.append(weapon_id)
		check(model != null and is_instance_valid(model) and model.visible, "%s is a visible physical model on the rack" % weapon_id)
		check(model != null and model.get_node_or_null("anchor_grip") != null, "%s uses the authored HeldGear weapon, not a display substitute" % weapon_id)
	check(identities == expected, "the rack and HunterArsenal name the same complete set")

	var before := str(demo.get("arsenal").current_id)
	demo.set("eye", Vector3(20.0, 1.68, 20.0))
	check(not bool(demo.call("_take_nearest_weapon")), "a weapon cannot be selected from across the room")
	check(str(demo.get("arsenal").current_id) == before, "the refused distant take leaves the held weapon alone")

	var shotgun: Dictionary = pickups[HunterArsenal.SLOT_ORDER.find("shotgun")]
	var shotgun_model := shotgun.get("model") as Node3D
	demo.set("eye", shotgun_model.global_position + Vector3(0.0, 0.0, 1.0))
	check(bool(demo.call("_take_nearest_weapon")), "E's shared take action accepts a weapon inside physical reach")
	check(str(demo.get("arsenal").current_id) == "shotgun", "the taken rack object equips the live shotgun")
	check(not bool(shotgun.get("available", true)) and not shotgun_model.visible, "the exact shotgun leaves the rack when it enters the hands")
	var view_gear := demo.get("view_gear") as HeldGear
	check(view_gear != null and view_gear.weapon != null and view_gear.weapon.name == "shotgun_model", "the authored shotgun is visibly present in the player's hands")
	demo.call("_update_view_forearms")
	var right_forearm := view_gear.right_hand.get_node_or_null("FirstPersonForearm") as Node3D
	var left_forearm := view_gear.left_hand.get_node_or_null("FirstPersonForearm") as Node3D
	check(right_forearm != null and left_forearm != null and right_forearm.top_level and left_forearm.top_level,
		"both hands continue through visible first-person forearms")
	var right_sleeve := right_forearm.get_node_or_null("TaperedSleeve") as MeshInstance3D
	check(right_sleeve != null and (right_sleeve.mesh as CylinderMesh).height > 0.08,
		"the sleeve reaches from the frame edge to the live weapon wrist")

	demo.call("_reset")
	await get_tree().process_frame
	await get_tree().process_frame
	check(bool(shotgun.get("available", false)) and shotgun_model.visible, "resetting the drill restores the physical rack")

	print("GORE_WEAPON_RACK_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
