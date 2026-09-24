extends Node

const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

## D1, D2, D4, D5, D6, D8. The claims worth bounding are the ones the design
## makes: every route lands in the same sheet, the chart is a distribution
## rather than a bonus, the budget actually constrains, the questionnaire is
## load-bearing, and the sheet the world holds can disagree with the one you
## filled in.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func spread(values: Dictionary) -> float:
	var low := 99.0
	var high := 0.0
	for key in values:
		low = minf(low, float(values[key]))
		high = maxf(high, float(values[key]))
	return high - low


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	# --- D5: the chart is real where it claims to be -------------------------
	var sheet := CharacterSheet.new()
	sheet.birth = {"year": 2007, "month": 1, "day": 11, "hour": 2, "minute": 30}
	check(sheet.sun_sign() == "CAPRICORN", "11 January is Capricorn (got %s)" % sheet.sun_sign())
	sheet.birth = {"year": 2007, "month": 8, "day": 14, "hour": 12, "minute": 0}
	check(sheet.sun_sign() == "LEO", "14 August is Leo, not Libra (got %s)" % sheet.sun_sign())
	sheet.birth = {"year": 2007, "month": 3, "day": 25, "hour": 9, "minute": 0}
	check(sheet.sun_sign() == "ARIES", "25 March is Aries (got %s)" % sheet.sun_sign())
	check(sheet.modality() == "cardinal", "Aries is cardinal (got %s)" % sheet.modality())

	sheet.birth = {"year": 2007, "month": 1, "day": 11, "hour": 2, "minute": 30}
	var night := sheet.ascendant()
	sheet.birth = {"year": 2007, "month": 1, "day": 11, "hour": 14, "minute": 30}
	check(night != sheet.ascendant(), "birth time moves the ascendant (%s vs %s)" % [night, sheet.ascendant()])
	check(sheet.ruling_house() == sheet.ascendant(), "the skill wheel starts at the rising sign")

	# --- the chart distributes rather than inflates ---------------------------
	var even := CharacterSheet.new()
	even.birth = {"year": 2007, "month": 1, "day": 11, "hour": 2, "minute": 30}
	var spike := CharacterSheet.new()
	# Sun and ascendant in the same element makes a specialist.
	spike.birth = {"year": 2007, "month": 8, "day": 14, "hour": 6, "minute": 0}
	var even_total := 0.0
	for key in even.attributes():
		even_total += float(even.attributes()[key])
	var spike_total := 0.0
	for key in spike.attributes():
		spike_total += float(spike.attributes()[key])
	check(absf(even_total - spike_total) < 1.2, "two charts hand out about the same total (%.1f vs %.1f)" % [even_total, spike_total])
	check(spread(spike.attributes()) > spread(even.attributes()), "but a concentrated chart is peakier (%.1f vs %.1f)" % [spread(spike.attributes()), spread(even.attributes())])

	# --- D2: the budget constrains -------------------------------------------
	var budget := CharacterSheet.new()
	check(budget.points_left() == CharacterSheet.BASE_POINTS, "you start with the full budget")
	check(budget.toggle_trait("hospital_strength"), "a positive trait can be taken")
	check(budget.points_left() == CharacterSheet.BASE_POINTS - 3, "and it costs (%d left)" % budget.points_left())
	check(budget.toggle_trait("the_tube_stayed_in"), "a negative trait can be taken")
	check(budget.points_left() > CharacterSheet.BASE_POINTS - 3, "and it refunds (%d left)" % budget.points_left())
	check(budget.toggle_trait("famous_for_something"), "a third trait fits")
	check(budget.toggle_trait("hospital_strength"), "taking it again removes it")
	check(not budget.traits.has("hospital_strength"), "and it is gone")

	# --- N1.3: overspending is now possible, not blocked --------------------
	# A fresh sheet, all three positive-cost traits, none of the refund ones —
	# the only way to actually reach negative with today's roster (max spend
	# 3+3+1=7 against a 6-point budget).
	var overspender := CharacterSheet.new()
	overspender.toggle_trait("hospital_strength")
	overspender.toggle_trait("famous_for_something")
	check(overspender.points_left() == 0, "exactly on budget after these two (%d left)" % overspender.points_left())
	check(not overspender.is_affordable("no_pain_receptors"), "is_affordable() still says no at zero left")
	check(overspender.toggle_trait("no_pain_receptors"), "but toggle_trait() lets you take it anyway")
	check(overspender.points_left() == -1, "and the budget actually goes negative (%d left)" % overspender.points_left())

	# --- N2: broken runs, honestly labelled, derived from the numbers -------
	check(overspender.overspent_by() == 1, "overspent_by() reads the real deficit, not a flag")
	check(overspender.is_broken_build(), "a build this overspent reads as broken")
	var in_budget := CharacterSheet.new()
	in_budget.toggle_trait("hospital_strength")
	check(not in_budget.is_broken_build(), "a build within budget is not")

	# --- traits and races move real numbers ----------------------------------
	var plain := CharacterSheet.new()
	var strong := CharacterSheet.new()
	strong.toggle_trait("hospital_strength")
	check(float(strong.attributes().physical) > float(plain.attributes().physical), "HOSPITAL STRENGTH is stronger")
	check(float(strong.attributes().composure) < float(plain.attributes().composure), "and worse at holding it together")
	var cut := CharacterSheet.new()
	cut.race = "marrow_cut"
	var old := CharacterSheet.new()
	old.race = "unreset"
	check(float(cut.attributes().physical) > float(old.attributes().physical), "MARROW-CUT outmuscles UNRESET")
	check(float(old.attributes().presence) > float(cut.attributes().presence), "and UNRESET is read better")
	check(cut.tree_pull() < old.tree_pull(), "race sets a Tree baseline before anything happens")

	# --- D6: the questionnaire is load-bearing -------------------------------
	var dark := CharacterSheet.new()
	dark.score_instrument([1, 1, 1, 0.5, 0.5, 0.5, 1, 0.5, 1, 1])
	var decent := CharacterSheet.new()
	decent.score_instrument([0, 0, 0, 0.5, 0.5, 0.5, 0, 0.5, 0, 0])
	check(dark.dark_triad() > decent.dark_triad(), "the dark triad scores apart (%.2f vs %.2f)" % [dark.dark_triad(), decent.dark_triad()])
	check(dark.aptitude_verdict().contains("FIT"), "and the instrument gives a verdict")
	check(decent.aptitude_verdict().contains("PROCEEDING REGARDLESS"), "a decent answer is decanted anyway")
	check(float(dark.attributes().presence) > float(decent.attributes().presence), "answering honestly and decently costs you presence")
	check(dark.tree_pull() < decent.tree_pull(), "and the triad drags the Tree axis down")

	# --- D8: modifiers trade ---------------------------------------------------
	var laced := CharacterSheet.new()
	laced.modifiers.append("mast_tithe")
	check(laced.starting_reach() > CharacterSheet.new().starting_reach(), "the mast tithe buys reach")
	var famous := CharacterSheet.new()
	famous.toggle_trait("famous_for_something")
	check(famous.starting_reach() > 900, "FAMOUS FOR SOMETHING starts you with a real audience")

	# --- D1.2/D1.3: it writes into the world, and comes back ------------------
	var filed := CharacterSheet.new()
	filed.display_name = "SUBJECT 44"
	filed.race = "roadborn"
	filed.toggle_trait("doomscroller")
	filed.birth = {"year": 2007, "month": 1, "day": 11, "hour": 2, "minute": 30}
	var state := filed.apply_to_world()
	check(str(state.get("race", "")) == "roadborn", "the sheet writes a real player subject")
	check((state.get("attributes", {}) as Dictionary).has("physical"), "with attributes on it")
	check(str(WorldHistory.subject("player").get("name", "")) == "SUBJECT 44", "and the world holds it")
	var filed_events := WorldHistory.events.filter(func(event: Dictionary) -> bool: return str(event.get("type", "")) == "sheet_filed")
	check(filed_events.size() == 1 and PLAYER_ACTION_LEDGER.count("sheet_filed") == 1 and str((filed_events[0].get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"), "the sheet and its intake consequences share one identified filing action")
	var reloaded := CharacterSheet.new()
	check(reloaded.load_from_world(), "it can be read back")
	check(reloaded.race == "roadborn" and reloaded.traits.has("doomscroller"), "with the same race and traits")

	# --- D2.3: the handler writes it down wrong ------------------------------
	var honest := CharacterSheet.new()
	honest.display_name = "SUBJECT 45"
	honest.birth = {"year": 2007, "month": 1, "day": 11, "hour": 2, "minute": 30}
	honest.race = "lantern_born"
	var truth := honest.attributes()
	honest.toggle_trait("clerical_error")
	var filed_wrong := honest.apply_to_world()
	var differs := str(filed_wrong.get("race", "")) != "lantern_born"
	differs = differs or str(filed_wrong.get("sun_sign", "")) != honest.sun_sign()
	differs = differs or str((filed_wrong.get("anatomy", {}) as Dictionary).get("blood_type", "")) != "O-RUST"
	for key in truth:
		if absf(float((filed_wrong.get("attributes", {}) as Dictionary).get(key, 0.0)) - float(truth[key])) > 0.01:
			differs = true
	check(differs, "CLERICAL ERROR makes the filed sheet disagree with the real one")
	check(str(filed_wrong.get("transcription", "")) == "unverified", "and the record admits it is unverified")

	# --- the lottery ------------------------------------------------------
	var lottery := CharacterSheet.new()
	lottery.randomise(4242)
	check(CharacterSheet.RACES.has(lottery.race), "a random decanting still produces a valid race")
	# N1.3/N2: the lottery calls toggle_trait() directly, same as a player
	# would, so it can now land on a genuinely overspent, broken build —
	# that is the point, not a bug to guard against. Sweep seeds rather than
	# assert on one, since a single seed proves nothing about the shape of
	# the possibility space.
	var any_broken := false
	var any_honest := false
	for seed_value in range(1, 400):
		var roll := CharacterSheet.new()
		roll.randomise(seed_value)
		if roll.is_broken_build():
			any_broken = true
			check(roll.overspent_by() == -roll.points_left(), "overspent_by() matches the actual deficit on a broken lottery roll (seed %d)" % seed_value)
		else:
			any_honest = true
	check(any_broken, "the lottery can actually produce a broken, overspent build")
	check(any_honest, "and can still produce an honest, in-budget one — it is not always broken")

	# --- N2.1/N2.2: the filed sheet marks a broken run in the world's own record
	WorldHistory.clear_history()
	var broken_sheet := CharacterSheet.new()
	broken_sheet.toggle_trait("hospital_strength")
	broken_sheet.toggle_trait("famous_for_something")
	broken_sheet.toggle_trait("no_pain_receptors")
	var broken_filed := broken_sheet.apply_to_world()
	check(bool(broken_filed.get("broken_run", false)), "an overspent sheet files as broken_run")
	check(int(broken_filed.get("overspent_by", 0)) == 1, "and records the real deficit, not just true/false")
	var achievement_events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "achievement_run_started")
	check(not achievement_events.is_empty(), "a broken run is recorded in the achievement-run register, not silently")
	check(PLAYER_ACTION_LEDGER.count("sheet_filed") == 1 and int(WorldHistory.get("_ledger_batch_depth")) == 0, "a broken sheet still closes one filing transaction")

	WorldHistory.clear_history()
	var clean_sheet := CharacterSheet.new()
	clean_sheet.toggle_trait("hospital_strength")
	var clean_filed := clean_sheet.apply_to_world()
	check(not bool(clean_filed.get("broken_run", false)), "an honest sheet does not file as broken")
	check(WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "achievement_run_started").is_empty(), "and records no achievement-run event")
	check(PLAYER_ACTION_LEDGER.count("sheet_filed") == 1 and int(WorldHistory.get("_ledger_batch_depth")) == 0, "an honest sheet follows the same single receipt route")

	print("SHEET_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
