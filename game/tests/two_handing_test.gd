extends Node

## AN2.5. "Two-handing changes the numbers, not just the pose." `held_gear.gd`
## already carried `reach`, `damage_type` and now `control` per grip, and its
## own header comment named this exact claim — nothing outside that file ever
## read any of the three. `B` now cycles the sword through its three real
## grips (`two_hand`, `one_hand`, `half_sword`), and `_carry_current_weapon()`
## reads the active one into the arm's own reach and stiffness; a swing's own
## `damage_type` follows it too, which is what lets a half-sworded thrust
## answer armour differently through the AN2.3 `strike()` path a plain cut
## already does.

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

	print("AN2.5 - the sword actually has a real choice to cycle through")
	hunt._equip_weapon(0) # sword
	check(hunt.current_grip == "two_hand", "a fresh draw starts at HeldGear's own default (two_hand)")
	hunt._cycle_grip()
	check(hunt.current_grip == "one_hand", "cycling once moves to one_hand")
	hunt._cycle_grip()
	check(hunt.current_grip == "half_sword", "cycling again reaches half_sword")
	hunt._cycle_grip()
	check(hunt.current_grip == "two_hand", "and wraps back around")

	print("AN2.5 - the reach and the stiffness actually differ, not just the label")
	hunt.current_grip = "two_hand"
	hunt._carry_current_weapon(true)
	var two_hand_reach: float = hunt.arm.reach
	var two_hand_stiffness: float = hunt.arm.stiffness
	hunt.current_grip = "half_sword"
	hunt._carry_current_weapon(true)
	var half_sword_reach: float = hunt.arm.reach
	var half_sword_stiffness: float = hunt.arm.stiffness
	check(half_sword_reach < two_hand_reach, "half-swording measurably shortens reach (%.3f vs %.3f)" % [half_sword_reach, two_hand_reach])
	check(half_sword_stiffness > two_hand_stiffness, "...and measurably steadies the arm (%.2f vs %.2f)" % [half_sword_stiffness, two_hand_stiffness])
	hunt.current_grip = "one_hand"
	hunt._carry_current_weapon(true)
	check(hunt.arm.stiffness < two_hand_stiffness, "one-handing a longsword is measurably wilder than two-handing it (%.2f vs %.2f)" % [hunt.arm.stiffness, two_hand_stiffness])

	print("AN2.5 - a weapon with no real grip choice ignores the key")
	hunt._equip_weapon(1) # shotgun
	var before_grip: String = hunt.current_grip
	hunt._cycle_grip()
	check(hunt.current_grip == before_grip, "cycling on a weapon GRIP_CYCLE has no entry for does nothing (%s)" % hunt.current_grip)

	print("AN2.5 - the grip actually reaches a resolved swing's own damage_type")
	hunt._equip_weapon(0) # sword, back to two_hand per the reset above
	hunt.attack_cooldown = 0.0
	hunt.arsenal.cooldown = 0.0
	hunt._attack()
	check(str(hunt.pending_attack.get("damage_type", "")) == "cut", "two-handed swings report cut (%s)" % str(hunt.pending_attack.get("damage_type", "")))
	hunt.pending_attack = {}
	hunt.attack_cooldown = 0.0
	hunt.arsenal.cooldown = 0.0
	hunt._cycle_grip()
	hunt._cycle_grip()
	check(hunt.current_grip == "half_sword", "cycled to half_sword for the live attempt")
	hunt._attack()
	check(str(hunt.pending_attack.get("damage_type", "")) == "puncture", "a half-sworded swing reports puncture instead (%s)" % str(hunt.pending_attack.get("damage_type", "")))

	if failures.is_empty():
		print("two-handing: the grip is a real choice with real numbers behind it")
		get_tree().quit(0)
	else:
		print("two-handing FAILURES: ", failures)
		get_tree().quit(1)
