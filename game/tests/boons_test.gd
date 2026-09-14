extends Node

## E4. Boosts must always end (E4.1), must cost the body or standing rather
## than money (E4.2), and must cost more the second time (E4.3).

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "bond": 40})

	# --- E4.1: nothing here can be permanent ---------------------------------
	var permanent := Boons.grant("player", "iron_nerve", "pain_resist", 0.4, 0.0, "blood", 100.0)
	check(not bool(permanent.get("ok", false)), "a zero-duration request is refused outright, not granted forever")

	# --- E4.2: the cost actually lands on the body ---------------------------
	var before_blood := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	var granted := Boons.grant("player", "iron_nerve", "pain_resist", 0.4, 999.0, "blood", 300.0)
	check(bool(granted.get("ok", false)), "granted, paid in blood")
	var after_blood := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	check(after_blood < before_blood, "blood actually dropped (%.0f -> %.0f)" % [before_blood, after_blood])
	check(is_equal_approx(Boons.stat_bonus("player", "pain_resist"), 0.4), "the boost is live and readable by stat")

	var organ_grant := Boons.grant("player", "borrowed_grip", "combat_power", 0.3, 999.0, "organ", 6.0, "liver")
	check(bool(organ_grant.get("ok", false)), "granted, paid in an organ")
	var liver_health := float(WorldHistory.subject("player").get("anatomy_state", {}).get("organs", {}).get("liver", {}).get("health", -1.0))
	check(liver_health > 0.0 and liver_health < 40.0, "the liver actually lost health (%.1f of 40)" % liver_health)

	var limb_grant := Boons.grant("player", "borrowed_speed", "move_speed", 0.2, 999.0, "limb", 10.0, "left_leg")
	check(bool(limb_grant.get("ok", false)), "granted, paid in a limb")
	var leg_health := float(WorldHistory.subject("player").get("anatomy_state", {}).get("zones", {}).get("left_leg", {}).get("health", -1.0))
	check(leg_health > 0.0 and leg_health < 75.0, "the leg actually lost health (%.1f of 75)" % leg_health)

	var standing_grant := Boons.grant("player", "called_favour", "reach", 0.5, 999.0, "standing", 15.0)
	check(bool(standing_grant.get("ok", false)), "granted, paid in standing")
	check(is_equal_approx(float(WorldHistory.subject("player").get("bond", 0)), 25.0), "standing actually dropped (40 -> 25)")

	# --- refused rather than lethal when the ledger is already empty --------
	WorldHistory.register_subject("bled_out", {"name": "Empty", "kind": "person", "anatomy_state": {"blood": 200.0, "blood_capacity": 5000.0}})
	var refused := Boons.grant("bled_out", "iron_nerve", "pain_resist", 0.4, 60.0, "blood", 300.0)
	check(not bool(refused.get("ok", false)), "refused rather than driving blood below the floor")

	# --- E4.3: the same boost costs more the second time --------------------
	var second := Boons.grant("player", "iron_nerve", "pain_resist", 0.4, 999.0, "blood", 300.0)
	check(float(second.get("cost_paid", 0.0)) > float(granted.get("cost_paid", 0.0)), "the second iron_nerve costs more than the first (%.0f > %.0f)" % [second.get("cost_paid", 0.0), granted.get("cost_paid", 0.0)])

	# --- taking the same boost again refreshes it rather than stacking it ---
	check(is_equal_approx(Boons.stat_bonus("player", "pain_resist"), 0.4), "retaking the same boost refreshes it instead of stacking (still 0.4, not 0.8)")

	# --- E4.1 again: it actually ends ----------------------------------------
	var expiring := Boons.grant("player", "flash_courage", "aggression", 0.6, 0.05, "standing", 2.0)
	check(bool(expiring.get("ok", false)), "a short boost is still granted")
	check(Boons.active_boons("player").any(func(b): return str((b as Dictionary).get("id", "")) == "flash_courage"), "and is active immediately")
	# Backdate the stored grant instead of waiting on wall time. Headless runs
	# may not advance their frame clock while booting project autoloads, and this
	# test is about expiry/pruning, not the engine's timer implementation.
	var subject := WorldHistory.subject("player")
	var active: Array = (subject.get("active_boons", []) as Array).duplicate(true)
	for raw in active:
		var boon: Dictionary = raw
		if str(boon.get("id", "")) == "flash_courage":
			boon["granted_msec"] = int(boon.get("granted_msec", 0)) - int(boon.get("duration_msec", 0)) - 1
	WorldHistory.amend_subject("player", {"active_boons": active})
	check(not Boons.active_boons("player").any(func(b): return str((b as Dictionary).get("id", "")) == "flash_courage"), "and is gone once its duration has actually passed")

	print("BOONS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
