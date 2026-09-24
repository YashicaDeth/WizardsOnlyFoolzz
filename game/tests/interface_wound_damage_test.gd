extends Node

## I4.3v2/I10.9. A wound damages only the instrument associated with that
## body region, derived from the live anatomy rather than a uniform vitality.

const HUNT := preload("res://bone_yard_hunt.tscn")
const HUD := preload("res://systems/gothic_field_hud.gd")
const RELIQUARY := preload("res://systems/held_item_reliquary.gd")

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
	var hunt = HUNT.instantiate()
	add_child(hunt)
	await get_tree().process_frame
	hunt.set_physics_process(false)
	var clean: Dictionary = hunt._interface_wound_regions()
	check(clean.values().all(func(value): return float(value) < 0.001), "a fresh body leaves all four instruments sound")

	var zones: Dictionary = hunt.player_rig.anatomy.zones
	zones.head.health = 0.0
	var head: Dictionary = hunt._interface_wound_regions()
	check(float(head.head) > 0.99 and float(head.torso) < 0.01 and float(head.arms) < 0.01 and float(head.legs) < 0.01, "a head wound selects only the portrait instrument")
	zones.head.health = AnatomyComponent.DEFAULT_ZONES.head.health
	zones.right_arm.health = 0.0
	var arm: Dictionary = hunt._interface_wound_regions()
	check(float(arm.arms) > 0.99 and float(arm.legs) < 0.01, "either arm selects the held-object instrument")
	zones.right_arm.health = AnatomyComponent.DEFAULT_ZONES.right_arm.health
	zones.left_leg.health = 0.0
	var leg: Dictionary = hunt._interface_wound_regions()
	check(float(leg.legs) > 0.99 and float(leg.head) < 0.01, "either leg selects the navigation instrument")
	zones.left_leg.health = AnatomyComponent.DEFAULT_ZONES.left_leg.health
	zones.torso.health = AnatomyComponent.DEFAULT_ZONES.torso.health * 0.4
	var torso: Dictionary = hunt._interface_wound_regions()
	check(is_equal_approx(float(torso.torso), 0.6), "torso degradation preserves the real wound ratio")

	var hud := HUD.new()
	add_child(hud)
	hud.set_state({"wound_regions": torso})
	check(is_equal_approx(hud.region_damage("torso"), 0.6), "the field interface accepts the region map without flattening it")
	check(hud.lung_linger > 0.0, "a torso wound makes the contextual anatomy instrument appear")
	var reliquary := RELIQUARY.new()
	add_child(reliquary)
	reliquary.set_arm_damage(0.72)
	check(is_equal_approx(reliquary.arm_damage, 0.72), "arm damage reaches only the held-object reliquary")

	print("INTERFACE_WOUND_DAMAGE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

