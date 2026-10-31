extends Node

## AN2.5. "Two-handing changes the numbers, not just the pose." `held_gear.gd`
## carries `reach`, `damage_type` and `control` per grip, and the Hunt reads the
## active one into the arm's own reach and stiffness.
##
## The issued melee is the hotline cleaver: one hand on the handle for reach,
## or choked up on the blade heel for control, and `B` cycles those two. The
## sword's grips still exist for the rooms and rigs that draw it, so they are
## asserted here on a bare `HeldGear` rather than through a Hunt that no longer
## carries a sword.

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

	print("AN2.5 - the issued cleaver has two real grips")
	hunt._equip_weapon(0)
	check(str(hunt.arsenal.current_id) == "cleaver", "slot 1 is the hotline cleaver the player is issued")
	check(hunt.GRIP_CYCLE.get("cleaver", []) == ["one_hand", "choke_up"], "B cycles the cleaver between one_hand and choke_up")
	check(hunt.current_grip == "one_hand", "a fresh draw starts on the handle (%s)" % hunt.current_grip)
	var cleaver := hunt.arsenal.models.get("cleaver") as Node3D
	check(cleaver != null, "the cleaver model is mounted")
	var right_hand: Node3D = null
	var cleaver_weapon: Node3D = null
	if cleaver != null:
		right_hand = cleaver.get_node_or_null("RightGripHand") as Node3D
		cleaver_weapon = cleaver.get_node_or_null("cleaver_model") as Node3D
	var choke_anchor: Node3D = null
	if cleaver_weapon != null:
		choke_anchor = cleaver_weapon.get_node_or_null("anchor_choke") as Node3D
	check(right_hand != null and choke_anchor != null, "the cleaver models a working hand and a choke anchor at the bolster")
	var one_hand_position := Vector3.ZERO
	if right_hand != null:
		one_hand_position = right_hand.position
	var receipts_before := PlayerActionLedger.count("grip_changed")
	hunt._cycle_grip()
	check(hunt.current_grip == "choke_up", "B moves the cleaver to its choke-up")
	check(PlayerActionLedger.count("grip_changed") == receipts_before + 1, "an accepted grip change records exactly one receipt")
	if right_hand != null and cleaver_weapon != null and choke_anchor != null:
		var choke_position: Vector3 = (cleaver_weapon.transform * choke_anchor.transform).origin
		check(right_hand.position.distance_to(choke_position) < 0.05 and right_hand.position.distance_to(one_hand_position) > 0.04,
			"the working hand visibly moves up the handle against the bolster")
	hunt._cycle_grip()
	check(hunt.current_grip == "one_hand", "and B wraps back to the handle")
	if right_hand != null:
		check(right_hand.position.distance_to(one_hand_position) < 0.02, "the hand returns to the grip it started on")

	print("AN2.5 - choking up changes the numbers, not just the hand")
	hunt.current_grip = "one_hand"
	hunt._carry_current_weapon(true)
	var cleaver_one_reach: float = hunt.arm.reach
	var cleaver_one_stiffness: float = hunt.arm.stiffness
	hunt.current_grip = "choke_up"
	hunt._carry_current_weapon(true)
	check(hunt.arm.reach < cleaver_one_reach,
		"the choke-up measurably shortens reach (%.3f vs %.3f)" % [hunt.arm.reach, cleaver_one_reach])
	check(hunt.arm.stiffness > cleaver_one_stiffness,
		"and measurably steadies the arm (%.2f vs %.2f)" % [hunt.arm.stiffness, cleaver_one_stiffness])

	hunt._equip_weapon(1)
	hunt._equip_weapon(0)
	check(hunt.current_grip == "one_hand", "a fresh draw resets to the handle rather than the last stance")
	var card_rows: Array = []
	for group: Dictionary in hunt.keys_card.groups:
		card_rows.append_array(group.get("rows", []) as Array)
	var grip_row: Array = card_rows.filter(func(row: Array) -> bool: return row[0] == "B")
	check(grip_row.size() == 1 and "CHOKE-UP" in str(grip_row[0][1]).to_upper(),
		"the keys card advertises the cleaver's second grip (%s)" % (str(grip_row[0][1]) if not grip_row.is_empty() else "no B row"))

	print("AN2.5 - a weapon with no real grip choice ignores the key")
	hunt._equip_weapon(1) # shotgun
	var gun_grip: String = hunt.current_grip
	var gun_receipts := PlayerActionLedger.count("grip_changed")
	hunt._cycle_grip()
	check(hunt.current_grip == gun_grip, "cycling on a weapon GRIP_CYCLE has no entry for does nothing (%s)" % hunt.current_grip)
	check(PlayerActionLedger.count("grip_changed") == gun_receipts, "and records no receipt for a grip it cannot take")
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
		print("two-handing: the cleaver's two grips are real, and the sword's still hold up")
		get_tree().quit(0)
	else:
		print("two-handing FAILURES: ", failures)
		get_tree().quit(1)
