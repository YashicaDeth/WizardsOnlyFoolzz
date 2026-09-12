extends Node

## O3.5 v2 audit. The checklist claims armour and plating are not in the
## damage resolution at all. anatomy_component.gd's apply_hit() reads
## installed.armor scaled by implant condition and reduces the applied
## damage by it — this checks whether that is actually true in practice, or
## whether it is dead code nothing ever reaches, the same way "stagger" and
## "cooldown" turned out to be for the enemy parry punish.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var bare := BaselineHuman.new()
	add_child(bare)
	bare.build("armor_bare", {})
	await get_tree().physics_frame

	var armored := BaselineHuman.new()
	add_child(armored)
	armored.build("armor_plated", {"cybernetics": {"torso": {"name": "ceramic sternum", "armor": 0.28}}})
	await get_tree().physics_frame

	check(armored.anatomy.installed_parts.has("torso"), "the armored rig actually has hardware installed in the zone being hit")

	var bare_health_before: float = bare.zone_health("torso")
	var armored_health_before: float = armored.zone_health("torso")
	bare.hit("torso", 40.0, 20.0, "blunt")
	armored.hit("torso", 40.0, 20.0, "blunt")
	var bare_loss: float = bare_health_before - bare.zone_health("torso")
	var armored_loss: float = armored_health_before - armored.zone_health("torso")
	check(armored_loss < bare_loss, "a plated torso actually takes less damage from the same blow (%.1f vs %.1f)" % [armored_loss, bare_loss])
	check(is_equal_approx(armored_loss, bare_loss * (1.0 - 0.28)), "and the reduction matches the plate's own armor value (%.1f expected %.1f)" % [armored_loss, bare_loss * 0.72])

	# A degraded plate should protect less than a fresh one.
	var fresh_plate := BaselineHuman.new()
	add_child(fresh_plate)
	fresh_plate.build("armor_fresh", {"cybernetics": {"torso": {"name": "ceramic sternum", "armor": 0.28}}})
	await get_tree().physics_frame
	var worn_plate := BaselineHuman.new()
	add_child(worn_plate)
	worn_plate.build("armor_worn", {"cybernetics": {"torso": {"name": "ceramic sternum", "armor": 0.28}}})
	await get_tree().physics_frame
	worn_plate.anatomy.damage_implant("torso", 140.0)
	var fresh_before: float = fresh_plate.zone_health("torso")
	var worn_before: float = worn_plate.zone_health("torso")
	fresh_plate.hit("torso", 40.0, 20.0, "blunt")
	worn_plate.hit("torso", 40.0, 20.0, "blunt")
	var fresh_loss: float = fresh_before - fresh_plate.zone_health("torso")
	var worn_loss: float = worn_before - worn_plate.zone_health("torso")
	check(worn_loss > fresh_loss, "a battered plate protects less than a fresh one of the same rating (%.1f vs %.1f)" % [worn_loss, fresh_loss])

	# The player's own opening-hand hardware is not exempt from any of this.
	var opening_rig := BaselineHuman.new()
	add_child(opening_rig)
	opening_rig.build("armor_player", {"cybernetics": {"right_arm": {"name": "salvaged torque arm", "armor": 0.22}}})
	await get_tree().physics_frame
	var arm_before: float = opening_rig.zone_health("right_arm")
	opening_rig.hit("right_arm", 40.0, 20.0, "blunt")
	var arm_loss: float = arm_before - opening_rig.zone_health("right_arm")
	check(is_equal_approx(arm_loss, 40.0 * (1.0 - 0.22)), "the opening's own torque arm reduces damage exactly like any other plate (%.1f)" % arm_loss)

	print("ARMOR_RESOLUTION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
