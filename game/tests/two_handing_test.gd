extends Node

## AN2.5. "Two-handing changes the numbers, not just the pose." `held_gear.gd`
## carries `reach`, `damage_type` and `control` per grip, and the Hunt reads the
## active one into the arm's own reach and stiffness.
##
## The issued melee is now the hotline cleaver, not the longsword. It is a
## one-hand tool with no off-hand anchor and one grip in `HeldGear`, so `B` has
## nothing to cycle and must say so by name. The sword's grips still exist for
## the rooms and rigs that draw it, so they are asserted here on a bare
## `HeldGear` rather than through a Hunt that no longer carries a sword.

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
	await get_tree().physics_frame

	print("AN2.5 - the issued cleaver is one-hand, and B says so by name")
	hunt._equip_weapon(0)
	check(str(hunt.arsenal.current_id) == "cleaver", "slot 1 is the hotline cleaver the player is issued")
	check(not hunt.GRIP_CYCLE.has("cleaver"), "the cleaver is not advertised as having a grip cycle")
	check(hunt.current_grip == "one_hand", "the cleaver sits in the one-hand grip it is actually held in (%s)" % hunt.current_grip)
	var receipts_before := PlayerActionLedger.count("grip_changed")
	var grip_before: String = hunt.current_grip
	hunt._cycle_grip()
	check(hunt.current_grip == grip_before, "B leaves the cleaver's grip alone")
	check(PlayerActionLedger.count("grip_changed") == receipts_before, "and records no grip change that did not happen")
	var refusal := str(hunt.prompt.text)
	check("CLEAVER" in refusal.to_upper(), "the refusal names the weapon in the hand (%s)" % refusal)
	check(not ("SWORD" in refusal.to_upper()) and not ("1 FOR" in refusal.to_upper()),
		"the refusal no longer sends the player to the retired sword")
	var card_rows: Array = []
	for group: Dictionary in hunt.keys_card.groups:
		card_rows.append_array(group.get("rows", []) as Array)
	var grip_row: Array = card_rows.filter(func(row: Array) -> bool: return row[0] == "B")
	check(grip_row.size() == 1 and not ("CYCLE" in str(grip_row[0][1]).to_upper()),
		"the keys card does not advertise a cycle the cleaver cannot make (%s)" % (str(grip_row[0][1]) if not grip_row.is_empty() else "no B row"))

	print("AN2.5 - a weapon with no real grip choice ignores the key")
	hunt._equip_weapon(1) # shotgun
	var gun_grip: String = hunt.current_grip
	hunt._cycle_grip()
	check(hunt.current_grip == gun_grip, "cycling on a weapon GRIP_CYCLE has no entry for does nothing (%s)" % hunt.current_grip)
	check(not ("CLEAVER" in str(hunt.prompt.text).to_upper()),
		"the refusal follows the weapon actually held instead of naming the last one")
	hunt._equip_weapon(0)

	print("AN2.5 - the sword's grips still carry real numbers")
	var grips: Dictionary = HeldGear.GRIPS
	var two_hand_reach: float = float(grips["two_hand"]["reach"])
	var half_sword_reach: float = float(grips["half_sword"]["reach"])
	var one_hand_stiffness: float = float(grips["one_hand"]["control"])
	var two_hand_stiffness: float = float(grips["two_hand"]["control"])
	var half_sword_stiffness: float = float(grips["half_sword"]["control"])
	check(half_sword_reach < two_hand_reach,
		"half-swording measurably shortens reach (%.2f vs %.2f)" % [half_sword_reach, two_hand_reach])
	check(half_sword_stiffness > two_hand_stiffness and two_hand_stiffness > one_hand_stiffness,
		"half-swording is steadier than two hands, and one hand is wilder than both (%.2f > %.2f > %.2f)" % [half_sword_stiffness, two_hand_stiffness, one_hand_stiffness])
	check(str(grips["half_sword"]["damage_type"]) == "puncture", "half-swording reports puncture")
	check(str(grips["two_hand"]["damage_type"]) == "cut", "a two-handed cut still reports cut")

	print("AN2.5 - half-swording still moves the off hand onto the blade")
	var gear := HeldGear.new()
	add_child(gear)
	gear.take("sword", "two_hand")
	check(gear.grip == "two_hand", "a bare HeldGear still draws the sword two-handed")
	var left_hand := gear.left_hand
	var blade_anchor: Node3D = null
	if gear.weapon != null:
		blade_anchor = gear.weapon.get_node_or_null("anchor_blade_grip") as Node3D
	check(left_hand != null and blade_anchor != null, "the sword still builds both a left hand and a blade anchor")
	if left_hand != null and blade_anchor != null:
		var two_hand_position := left_hand.position
		gear.hold("half_sword")
		var blade_grip_position: Vector3 = (gear.weapon.transform * blade_anchor.transform).origin
		check(left_hand.position.distance_to(blade_grip_position) < 0.05 and left_hand.position.distance_to(two_hand_position) > 0.2,
			"half-swording visibly moves the off hand from the low grip onto the blade")
		check(str(gear.grip_effect()["damage_type"]) == "puncture", "and the held gear's own effect follows the grip")

	print("TWO_HANDING_RESULT failures=", failures.size())
	if failures.is_empty():
		print("two-handing: the issued cleaver is honest about its one grip, and the sword's grips still hold up")
		get_tree().quit(0)
	else:
		print("two-handing FAILURES: ", failures)
		get_tree().quit(1)
