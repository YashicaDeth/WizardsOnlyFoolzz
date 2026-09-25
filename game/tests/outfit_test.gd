extends Node

## The jester set as parts (Greg, 24 September): forced on with the collar
## locked, nothing comes off until the lock is broken, then each part comes
## off into the bag and goes back on, and a cloth skin paints its zones.

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
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("outfit_test", BaselineHuman.config_from_subject({}))
	var carry := Carry.new()
	Outfit.dress(rig)
	check((rig.wardrobe.get("parts", {}) as Dictionary).size() == 4 and bool(rig.wardrobe.locked), "a new world dresses you in all four parts, collar locked")
	check(rig.parts.head.get_node_or_null("GarmentExtra_bell_cap") != null and rig.parts.torso.get_node_or_null("GarmentExtra_ruff") != null, "the cap and the ruff are built on the body")
	check(rig.parts.left_leg.get_node_or_null("GarmentExtra_shoe") != null and rig.parts.right_arm.get_node_or_null("GarmentExtra_cuff") != null, "the shoes and cuffs are built on the body")
	check(str((rig.wardrobe.styles as Dictionary).get("torso", "")) == "jester", "each zone knows its part's style")
	var refused := Outfit.take_off(rig, carry, "jester_cap")
	check(not bool(refused.ok) and str(refused.reason) == "THE COLLAR IS LOCKED", "the locked collar holds the set on")
	check(not bool(Outfit.break_lock(rig, "").ok), "the lock needs something to break it with")
	check(bool(Outfit.break_lock(rig, "sword").ok) and not bool(Outfit.worn().locked), "the cleaver breaks the lock")
	var lock := rig.parts.torso.find_child("CollarLock", true, false) as Node3D
	check(lock != null and not lock.visible, "the broken lock is gone from the collar")
	check(bool(Outfit.take_off(rig, carry, "jester_cap").ok) and carry.items.size() == 1 and str(carry.items[0].kind) == "garment", "the cap comes off into the bag")
	check(rig.parts.head.get_node_or_null("GarmentExtra_bell_cap") == null and float(rig.wardrobe.get("head", 0.0)) <= 0.0, "and the head is bare")
	check(bool(Outfit.put_on(rig, carry, 0).ok) and carry.items.is_empty() and (Outfit.worn().parts as Dictionary).has("jester_cap"), "it goes back on")
	var skin := WeaponSkins.mint("jester_doublet_wine", 0.2, 11)
	carry.items.append(skin)
	check(bool(SkinLoadout.apply(carry, 0).ok), "a cloth skin applies to the doublet")
	Outfit.dress(rig)
	var shell := rig.parts.torso.get_node_or_null("Garment") as MeshInstance3D
	check(shell != null and shell.material_override is ShaderMaterial, "and the doublet wears it")
	check(str(WorldHistory.subject("player_action_ledger")).contains("collar_lock_broken"), "the ledger remembers the lock breaking")
	print("OUTFIT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
