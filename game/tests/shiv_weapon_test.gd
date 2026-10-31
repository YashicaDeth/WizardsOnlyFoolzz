extends Node

## Greg, 28 September: the den's shiv is a real Hunt weapon: fast, it makes
## wounds bleed, weak against armour.

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
	WorldHistory.update_subject("inventory", {"items": [{"label": "SHIV", "kind": "weapon", "weapon": "shiv"}]}, "carry_changed")
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for i in 5:
		await get_tree().physics_frame
	var arsenal = hunt.arsenal
	check(arsenal.carried().has("shiv"), "carrying the shiv from the den puts it in your hands in the Hunt")
	var slot: int = arsenal.carried().find("shiv")
	hunt._equip_weapon(slot)
	check(arsenal.current_id == "shiv", "it can be drawn")
	check(arsenal.models.has("shiv"), "with its own model")
	var shiv: Dictionary = arsenal.WEAPONS.shiv
	var sword: Dictionary = arsenal.WEAPONS.sword
	check(float(shiv.cooldown) < float(sword.cooldown) and float(shiv.windup) < float(sword.windup), "faster than the cleaver")
	check(str(shiv.damage_type) == "puncture", "it punctures, so wounds bleed")
	check(float(shiv.impulse) < float(sword.impulse) * 0.5, "and it carries little weight against armour")
	hunt._attack()
	check(not hunt.pending_attack.is_empty(), "a click stabs")
	hunt.queue_free()
	await get_tree().process_frame
	WorldHistory.clear_history()
	var plain = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(plain)
	await get_tree().physics_frame
	check(not plain.arsenal.carried().has("shiv"), "without it, no shiv")
	print("SHIV_WEAPON_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
