extends Node

const ARSENAL := preload("res://systems/hunter_arsenal.gd")
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func make_arsenal(subject_id: String) -> HunterArsenal:
	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build(subject_id)
	var result := ARSENAL.new() as HunterArsenal
	add_child(result)
	result.configure(rig)
	return result


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var arsenal := make_arsenal("customized_holder")
	check(arsenal.weapon_customization("sidearm").is_empty(), "a fresh sidearm has no invented holder upgrades")
	check(not arsenal.install_customization("sword", "sight", {"id": "wrong_object"}), "a firearm part cannot become a perk on the holder's sword")
	check(not arsenal.install_customization("sidearm", "stock", {"id": "wrong_slot"}), "a part must fit a slot the weapon actually owns")

	arsenal.select_slot(2)
	arsenal.shot_serial = 4
	var bare_definition: Dictionary = arsenal.current()
	var bare_direction: Vector3 = arsenal.shot_directions(Vector3.FORWARD, Vector3.UP)[0]
	var optic := {
		"id": "test_reflex_sight",
		"label": "TEST REFLEX SIGHT",
		"from": "range_bench",
		"modifiers": {"spread_scale": 0.5, "damage_scale": 9.0, "unknown_holder_bonus": 99.0},
	}
	check(arsenal.install_customization("sidearm", "sight", optic), "a compatible part installs on the sidearm")
	var fitted: Dictionary = arsenal.weapon_customization("sidearm")
	check(str((fitted.sight as Dictionary).from) == "range_bench", "the weapon keeps the fitted part's identity and provenance")
	check(is_equal_approx(float((fitted.sight.modifiers as Dictionary).damage_scale), 2.0) and not (fitted.sight.modifiers as Dictionary).has("unknown_holder_bonus"), "weapon modifiers are clamped and unknown holder perks are discarded")

	var fitted_definition: Dictionary = arsenal.current()
	arsenal.shot_serial = 4
	var fitted_direction: Vector3 = arsenal.shot_directions(Vector3.FORWARD, Vector3.UP)[0]
	check(is_equal_approx(float(fitted_definition.spread), float(bare_definition.spread) * 0.5), "the installed sight changes this weapon's live spread")
	check(fitted_direction.angle_to(Vector3.FORWARD) < bare_direction.angle_to(Vector3.FORWARD), "the shared projectile cone reads the fitted weapon")
	var attack: Dictionary = arsenal.begin_attack()
	check(is_equal_approx(float(attack.damage), float(bare_definition.damage) * 2.0), "the shared firing report reads the fitted weapon too")
	check((arsenal.state().customization as Dictionary).has("sight"), "the weapon reports its installed part to any holder UI")
	check((arsenal.models.sidearm as Node3D).get_meta("weapon_customization", {}).has("sight"), "the physical weapon mount receives the same attachment record")

	arsenal.tick(1.0)
	arsenal.select_slot(1)
	check(arsenal.weapon_customization("shotgun").is_empty() and is_equal_approx(float(arsenal.current().damage), float(ARSENAL.WEAPONS.shotgun.damage)), "customization does not leak onto another weapon in the same hands")
	arsenal.select_slot(2)
	check((arsenal.state().customization as Dictionary).has("sight"), "the part stays on the sidearm after holstering and drawing it")

	var other_holder := make_arsenal("fresh_holder")
	other_holder.select_slot(2)
	check(other_holder.weapon_customization().is_empty() and is_equal_approx(float(other_holder.current().damage), float(bare_definition.damage)), "another holder's fresh sidearm does not inherit a global upgrade")

	var removed: Dictionary = arsenal.remove_customization("sidearm", "sight")
	check(str(removed.get("id", "")) == "test_reflex_sight" and arsenal.weapon_customization("sidearm").is_empty(), "removing the part returns that same part and restores the bare weapon")
	check(is_equal_approx(float(arsenal.current().spread), float(bare_definition.spread)), "removing customization recovers the authored firing numbers")

	print("WEAPON_CUSTOMIZATION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
