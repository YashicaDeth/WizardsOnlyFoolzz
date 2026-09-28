extends Node

## Greg's walkthrough (2026-09-24): after slot 6 he could not get back to his
## weapons. A click with a smokeable in hand now draws the weapon, and the
## weapon key pressed again clears a smoke kept at the lips.

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
	for _f in 10:
		await get_tree().physics_frame
	hunt._cycle_smokeable()
	check(hunt.smoke_model != null, "slot 6 puts a smokeable in hand")
	hunt._attack(false)
	var sword = hunt.arsenal.models.get(str(hunt.arsenal.current_id))
	check(hunt.smoke_model == null and sword.visible, "a click pockets it and draws the weapon")

	hunt._cycle_smokeable()
	hunt.smoke_index = hunt.SMOKEABLE_ORDER.find("cigarette") - 1
	hunt._cycle_smokeable()
	hunt._toggle_mouth_hold()
	hunt._equip_weapon(0)
	check(hunt.smoke_model != null and hunt.smoke_weapon_drawn, "the weapon key draws with the smoke kept at the lips")
	hunt._equip_weapon(0)
	check(hunt.smoke_model == null, "the same key again puts the smoke away")
	print("SMOKE_RELEASE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
