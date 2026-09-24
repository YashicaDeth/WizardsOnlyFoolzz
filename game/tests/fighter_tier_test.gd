extends Node

## The tiers are who you fight (Greg, 24 September), and each is measured:
## harder tiers defend more, telegraph later, swing faster, feint and read
## your guard more, and none of them is unbeatable.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var open := {}
	for tier in FighterTier.ORDER:
		open[tier] = FighterTier.expected_open(tier)
	check(open.scavenger > open.hunter and open.hunter > open.captain and open.captain > open.elite, "each tier lets fewer swings through: %s" % open)
	check(open.elite >= 0.35, "even an elite leaves over a third of swings open (%.2f): beatable" % open.elite)
	var faster := true
	var later := true
	for index in range(1, FighterTier.ORDER.size()):
		var a := FighterTier.spec(FighterTier.ORDER[index - 1])
		var b := FighterTier.spec(FighterTier.ORDER[index])
		faster = faster and float(b.cycle) < float(a.cycle)
		later = later and float(b.telegraph) > float(a.telegraph)
	check(faster and later, "each tier swings faster and shows its side later")
	check(FighterTier.defend("elite", "x", 3, true) == "open", "a fighter mid-swing is always open")
	check(FighterTier.defend("hunter", "same", 7, false) == FighterTier.defend("hunter", "same", 7, false), "the same fight goes the same way")
	var read := 0
	for index in 400:
		if FighterTier.choose_side("elite", "reader", index, "high") != "high":
			read += 1
	check(read > 330, "an elite mostly swings where you are not guarding (%d / 400)" % read)
	var feints := 0
	for index in 400:
		if not FighterTier.feint_side("captain", "feinter", index, "left").is_empty():
			feints += 1
	check(feints > 30 and feints < 100, "a captain feints now and then (%d / 400)" % feints)
	check(FighterTier.feint_side("scavenger", "s", 1, "left").is_empty(), "scavengers never feint")
	check(FighterTier.tier_for({"name": "Ashline Captain"}) == "captain" and FighterTier.tier_for({"role": "Yard salvage hand"}) == "scavenger" and FighterTier.tier_for({"name": "Bob"}) == "hunter" and FighterTier.tier_for({}, true) == "captain", "who they are decides their tier")
	print("FIGHTER_TIER_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
