extends Node

## Skins and cases (Greg, 24 September): the CS-style ladder with gold at
## exactly 0.01%, every case able to give every tier, wear bands, the market
## paying more for rarer, cleaner and scarcer skins, and a skin that goes on
## its weapon and comes back off.

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
	var counts := {}
	for index in 10000:
		var tier := SkinCase.tier_for((float(index) + 0.5) / 10000.0)
		counts[tier] = int(counts.get(tier, 0)) + 1
	check(counts == {"issue": 7992, "contraband": 1598, "restricted": 320, "covert": 63, "relic": 26, "gold": 1}, "10,000 draws land 7992/1598/320/63/26 and exactly one gold: %s" % counts)
	check(SkinCase.tier_for(0.99995) == "gold" and SkinCase.tier_for(0.9998) != "gold", "gold is the top 0.01% of the draw")
	for case_id: String in SkinCase.CASES:
		var every := true
		for entry: Dictionary in WeaponSkins.TIERS:
			every = every and not SkinCase.pool(case_id, str(entry.id)).is_empty()
		check(every, "%s can give something at every tier" % case_id)
	var gold_pool := SkinCase.pool("fools_case", "gold")
	check(not gold_pool.is_empty() and str(WeaponSkins.TARGETS[WeaponSkins.SKINS[gold_pool[0]].target]["class"]) in ["gun", "blade"], "gold in any case is a gun or a knife")
	var receipt := SkinCase.open("wetwork_case", 0.99999, 0.5, 0.0, 7)
	check(bool(receipt.ok) and str(receipt.tier) == "gold" and str(receipt.label).contains("★"), "a gold roll mints a starred gold skin: %s" % receipt.get("label", ""))
	var fade := WeaponSkins.mint("sidearm_celloutz_fade", 1.0, 3)
	check(float(fade.wear) <= 0.08, "fades only come clean (%.3f)" % float(fade.wear))
	check(str(WeaponSkins.wear_band(0.03).label) == "VAT FRESH" and str(WeaponSkins.wear_band(0.9).label) == "BATTLE SCARRED", "wear bands name the float")

	var common := WeaponSkins.mint("sidearm_dry_falls", 0.5, 100)
	var covert := WeaponSkins.mint("shotgun_case_hardened", 0.5, 500)
	var gold := WeaponSkins.mint("sword_saints_tooth", 0.1, 500)
	check(SkinMarket.price(common) < SkinMarket.price(covert) and SkinMarket.price(covert) < SkinMarket.price(gold), "rarer sells for more (%d < %d < %d)" % [SkinMarket.price(common), SkinMarket.price(covert), SkinMarket.price(gold)])
	check(SkinMarket.price(gold) >= 100000, "gold sells for heaps (%d scrip)" % SkinMarket.price(gold))
	var clean := WeaponSkins.mint("shotgun_blood_rust", 0.0, 500)
	var scarred := WeaponSkins.mint("shotgun_blood_rust", 1.0, 500)
	check(SkinMarket.price(clean) > SkinMarket.price(scarred), "clean sells for more than scarred")
	var blue := WeaponSkins.mint("shotgun_case_hardened", 0.5, 3)
	check(SkinMarket.price(blue) > SkinMarket.price(covert), "a near-all-blue case-hardened seed is worth more")
	var before := SkinMarket.price(common)
	for _mint in 20:
		SkinMarket.register_mint(common)
	check(SkinMarket.price(common) < before, "a skin the world is full of sells for less")

	var carry := Carry.new()
	carry.items.append(SkinCase.case_item("abattoir_case"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var opened := SkinCase.open_into(carry, "", rng, 0)
	check(bool(opened.ok) and carry.items.size() == 1 and str(carry.items[0].kind) == "skin", "opening a carried case uses it up and bags the skin")
	var target := str(carry.items[0].target)
	var applied := SkinLoadout.apply(carry, 0)
	check(bool(applied.ok) and carry.items.is_empty() and not SkinLoadout.applied(target).is_empty(), "applying a skin puts it on its %s" % target)
	var worn_before := float(SkinLoadout.applied(target).wear)
	SkinLoadout.scuff(target, 0.05, 0.3, true)
	var after := SkinLoadout.applied(target)
	check(float(after.wear) > worn_before and float(after.blood) > 0.0 and int(after.kills) == 1, "a fight wears and bloods it and counts the kill")
	check(bool(SkinLoadout.remove(carry, target).ok) and carry.items.size() == 1, "taking it off gives it back")
	WorldHistory.update_subject("inventory", {"rust_scrip": 0})
	var sold := SkinMarket.sell(carry, 0)
	check(bool(sold.ok) and int(WorldHistory.subject("inventory").get("rust_scrip", 0)) == int(sold.paid) and carry.items.is_empty(), "selling on the Wire pays scrip (%d)" % int(sold.get("paid", 0)))
	var ledger := str(WorldHistory.subject("player_action_ledger"))
	check(ledger.contains("case_opened") and ledger.contains("skin_sold"), "the ledger remembers opening and selling")

	var gun := HeldGear.build_weapon("sidearm")
	add_child(gun)
	check(WeaponSkins.apply_to(gun, fade) > 0, "a skin paints the weapon's meshes")

	print("SKIN_CASE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
