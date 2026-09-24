extends Node

## AU4. A substance is a curve through time. This proves the curve exists, that
## it differs per substance rather than being one shape at three volumes, that
## tolerance moves it, and that a bad trip is a different shape rather than a
## louder one.

const SX := preload("res://systems/substance_experience.gd")

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})

	# --- every catalogued substance has an authored experience --------------
	for substance_id: String in Substances.CATALOG:
		check(SX.PROFILES.has(substance_id), "%s has an authored curve, not just a cost" % substance_id)
		check(SX.duration(substance_id) > 0.0, "%s lasts a real amount of time" % substance_id)

	# --- AU4.2: the phases are real and arrive in order ---------------------
	var seen: Array[String] = []
	var total := SX.duration("choir_bloom")
	for step in 60:
		var at := total * float(step) / 59.0
		var phase := str(SX.state_at("choir_bloom", at)["phase"])
		if seen.is_empty() or seen[seen.size() - 1] != phase:
			seen.append(phase)
	check(seen.has("come_up") and seen.has("peak") and seen.has("come_down"),
		"choir_bloom passes through come_up, peak and come_down")
	check(seen.find("come_up") < seen.find("peak") and seen.find("peak") < seen.find("come_down"),
		"and it passes through them in that order, once")

	# --- AU4.1: different substances are different shapes, not volumes ------
	var bloom_peak: Dictionary = SX.state_at("choir_bloom", SX.duration("choir_bloom") * 0.5)["dials"]
	var hymn_peak: Dictionary = SX.state_at("static_hymn", SX.duration("static_hymn") * 0.35)["dials"]
	var dust_peak: Dictionary = SX.state_at("marrow_dust", SX.duration("marrow_dust") * 0.35)["dials"]
	check(float(bloom_peak["kaleidoscope_segments"]) >= 3.0, "the fungal door is the geometric one")
	check(float(hymn_peak["cut_intensity"]) > float(bloom_peak["cut_intensity"]),
		"the dead mast's feedback cuts the frame more than the fungus does")
	check(float(dust_peak["kaleidoscope_segments"]) == 0.0,
		"and marrow dust opens no door at all - it is body, not geometry")

	# --- nothing is ever left on: sober in, sober out ------------------------
	var before: Dictionary = SX.state_at("choir_bloom", -1.0)["dials"]
	var after: Dictionary = SX.state_at("choir_bloom", SX.duration("choir_bloom") + 5.0)["dials"]
	check(before == SX.REST and after == SX.REST, "before and after a dose every dial is at rest")
	check(bool(SX.state_at("choir_bloom", SX.duration("choir_bloom") + 5.0)["done"]), "and the state says it is over")

	# --- Rule 3: no hard cuts. Consecutive samples move smoothly ------------
	var worst := 0.0
	var previous: Dictionary = SX.state_at("choir_bloom", 0.0)["dials"]
	for step in range(1, 400):
		var now: Dictionary = SX.state_at("choir_bloom", total * float(step) / 399.0)["dials"]
		worst = maxf(worst, absf(float(now["lut_strength"]) - float(previous["lut_strength"])))
		previous = now
	check(worst < 0.05, "lut_strength never jumps between adjacent frames (worst step %.4f)" % worst)

	# --- AU4.5: tolerance moves the curve -----------------------------------
	var fresh := SX.duration("choir_bloom", 1.0, 0)
	var worn := SX.duration("choir_bloom", 1.0, 5)
	check(worn < fresh, "a fifth dose of the same thing peaks for less time")
	var fresh_peak := float(SX.state_at("choir_bloom", fresh * 0.5, 1.0, 0)["dials"]["lut_strength"])
	var worn_peak := float(SX.state_at("choir_bloom", worn * 0.5, 1.0, 5)["dials"]["lut_strength"])
	check(worn_peak < fresh_peak, "and it does less when it gets there")

	# --- AU4.3: a bad trip is a different shape -----------------------------
	var good: Dictionary = SX.state_at("choir_bloom", fresh * 0.5, 1.0, 0, false)["dials"]
	var bad: Dictionary = SX.state_at("choir_bloom", fresh * 0.5, 1.0, 0, true)["dials"]
	check(float(bad["kaleidoscope_segments"]) < float(good["kaleidoscope_segments"]),
		"a bad trip has less symmetry, not more")
	check(float(bad["kaleidoscope_spin"]) < 0.0, "and the spin reverses")
	check(float(bad["cut_intensity"]) > float(good["cut_intensity"]), "and the frame starts cutting")

	# --- a first dose is never a bad trip -----------------------------------
	check(not SX.is_bad_trip("player", "choir_bloom", 0), "a first dose of anything is never a bad trip")
	var ever_bad := false
	for held in range(1, 9):
		if SX.is_bad_trip("player", "choir_bloom", held):
			ever_bad = true
	check(ever_bad, "but enough repeats can turn on you")
	check(SX.is_bad_trip("player", "choir_bloom", 4) == SX.is_bad_trip("player", "choir_bloom", 4),
		"and the same dose count answers the same way twice")

	# --- the record: taking it is an event the world knows about ------------
	var began := SX.begin("player", "choir_bloom", 100.0, 1.0)
	check(bool(began.get("ok", false)), "a dose can be started")
	check(SX.tolerance("player", "choir_bloom") == 1, "and it is remembered as tolerance")
	check(WorldHistory.event_count("substance_experience_began") == 1 and int(WorldHistory.get("_ledger_batch_depth")) == 0, "dose history, tolerance and the experience fact close one derived transaction")
	var mid := SX.dials_for("player", 100.0 + fresh * 0.5)
	check(float(mid["lut_strength"]) > 0.0, "mid-dose the rig is being driven")
	var over := SX.dials_for("player", 100.0 + fresh + 60.0)
	check(over == SX.REST, "and once it is over the rig is back at rest")
	check(SX.settle("player", 100.0 + fresh + 60.0) == 0, "the finished dose is dropped at the seam")

	# --- stacking does not run away -----------------------------------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	SX.begin("player", "choir_bloom", 0.0, 1.0)
	SX.begin("player", "static_hymn", 0.0, 1.0)
	var stacked := SX.dials_for("player", 20.0)
	check(float(stacked["feedback_strength"]) <= 1.0, "two at once cannot push feedback past 1.0")
	check(float(stacked["kaleidoscope_segments"]) <= 8.0, "or the mirrors past what the shader draws")
	check(float(stacked["kaleidoscope_segments"]) == roundf(float(stacked["kaleidoscope_segments"])),
		"and a mirror count is always whole")

	print("SUBSTANCE_EXPERIENCE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
