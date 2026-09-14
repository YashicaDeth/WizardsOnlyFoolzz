extends Node

## N5.1. A real slot per site, not one slot per coarse damage zone. Before
## this, `installed_parts` was keyed directly by `BaselineHuman`'s six damage
## zones, so a spine cage and a chest plate could not both exist — installing
## the second silently overwrote the first, because both collapsed onto the
## single key "torso". `INSTALL_SITES` gives Greg's own named sites (spine,
## skull, chest, organ_bays, each limb) their own slot while still resolving
## to one of the six real zones for armor and damage.

const ANATOMY := preload("res://systems/anatomy_component.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var body: AnatomyComponent = ANATOMY.new()
	add_child(body)
	body.configure("sites_test")

	# --- three real, independent torso-adjacent sites -----------------------
	body.install_part("spine", {"id": "load-bearing spine cage"})
	body.install_part("chest", {"id": "ceramic sternum"})
	body.install_part("organ_bays", {"id": "blackbox liver"})
	check(body.installed_parts.has("spine") and body.installed_parts.has("chest") and body.installed_parts.has("organ_bays"), "all three install as their own real, distinct slots")
	check(not body.installed_parts.has("torso"), "and none of them silently overwrote a fourth, generic 'torso' slot")
	check(body.implant_condition("spine") > 0.0 and body.implant_condition("chest") > 0.0 and body.implant_condition("organ_bays") > 0.0, "each reports its own real condition")

	# --- and "skull" is a real, distinct slot from plain "head" too --------
	body.install_part("skull", {"id": "six-finger surgical crown"})
	body.install_part("head", {"id": "rangefinder eye"})
	check(body.installed_parts.has("skull") and body.installed_parts.has("head"), "skull and head hold separate hardware rather than one overwriting the other")

	# --- a torso hit answers to every site installed there, not just one ---
	var bare: AnatomyComponent = ANATOMY.new()
	add_child(bare)
	bare.configure("bare_torso")
	var armoured: AnatomyComponent = ANATOMY.new()
	add_child(armoured)
	armoured.configure("armoured_torso")
	armoured.install_part("spine", {"id": "load-bearing spine cage"})
	armoured.install_part("chest", {"id": "ceramic sternum"})
	var bare_result := bare.apply_hit("torso", 40.0, 0.0, "blunt")
	var armoured_result := armoured.apply_hit("torso", 40.0, 0.0, "blunt")
	check(float(armoured_result.get("absorbed", 0.0)) > float(bare_result.get("absorbed", 0.0)), "a torso hit is measurably absorbed more with two sites armoured than with none (%.2f vs %.2f)" % [armoured_result.get("absorbed", 0.0), bare_result.get("absorbed", 0.0)])

	var spine_before := armoured.implant_condition("spine")
	var chest_before := armoured.implant_condition("chest")
	armoured.apply_hit("torso", 60.0, 0.0, "puncture")
	check(armoured.implant_condition("spine") < spine_before, "the spine implant actually wears from a torso hit it did not used to be able to answer for on its own")
	check(armoured.implant_condition("chest") < chest_before, "and so does the chest implant, independently — both sites, not one shared number")

	# --- pulling one site never touches an unrelated one --------------------
	armoured.pull_part("spine", true)
	check(not armoured.installed_parts.has("spine"), "spine is genuinely gone")
	check(armoured.installed_parts.has("chest"), "chest is completely unaffected by pulling a different site at the same zone")

	# --- existing bare-zone callers still behave exactly as before ---------
	var legacy: AnatomyComponent = ANATOMY.new()
	add_child(legacy)
	legacy.configure("legacy")
	legacy.install_part("right_leg", {"id": "heel anchors"})
	check(legacy.installed_parts.has("right_leg"), "a plain limb zone is still a valid site on its own, unchanged")
	var pulled := legacy.pull_part("right_leg", true)
	check(bool(pulled.get("ok", false)), "and the existing single-site API still works exactly as it always did")

	print("INSTALL_SITES_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
