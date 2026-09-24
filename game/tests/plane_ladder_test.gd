extends Node

const PLAYER_ACTION_LEDGER := preload("res://systems/player_action_ledger.gd")

## AV1.1-AV1.4, AV2.1-AV2.5, AV3.1. Ten sephiroth plus the one that is not on
## the map; four worlds as registers; altitude read from what substances.gd/
## meditation.gd already record rather than a menu; a petition that costs
## something real to open and to close; a failure that is remembered when
## altitude drops mid-interaction; planes as real WorldHistory subjects.

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

	# --- AV1.1: ten real, named, ordered places -----------------------------
	var planes := PlaneLadder.reachable_planes()
	check(planes.size() == 10, "ten sephiroth, not eleven and not nine (%d)" % planes.size())
	check(planes[0] == "malkuth" and planes[-1] == "keter", "ordered low to high, Malkuth first and Keter last")
	for plane_id in planes:
		var data := PlaneLadder.plane(plane_id)
		check(str(data.get("name", "")) != "", "%s has a real tradition name" % plane_id)

	# --- AV1.3: Da'ath is real data and never a reachable place -------------
	var daath_data := PlaneLadder.plane(PlaneLadder.DAATH)
	check(str(daath_data.get("name", "")) == "Da'ath", "Da'ath is real data, not an empty result")
	check(not planes.has(PlaneLadder.DAATH), "but it is never in the reachable list")
	check(is_inf(PlaneLadder.floor_requirement(PlaneLadder.DAATH, "see")), "and no floor is even defined for it")

	# --- AV2.1: floors rise with a plane's own order -------------------------
	for floor_name in PlaneLadder.FLOOR_ORDER:
		check(is_equal_approx(PlaneLadder.floor_requirement("malkuth", floor_name), 0.0), "Malkuth needs no altitude for %s — you are already standing in it" % floor_name)
	var keter_see := PlaneLadder.floor_requirement("keter", "see")
	var keter_fight := PlaneLadder.floor_requirement("keter", "fight")
	check(keter_see > PlaneLadder.floor_requirement("yesod", "see"), "Keter asks more altitude to even see than Yesod does")
	check(keter_fight > keter_see, "and fighting there asks more than seeing it does")
	check(keter_fight >= 100.0, "Keter's fight floor clamps at the ceiling — not a difficulty setting, actually unreachable (AV2.4)")

	# --- AV1.2/AV1.6: same place, two registers, no second asset set --------
	var hellish := PlaneLadder.perceive("gevurah", "yetzirah")
	var angelic := PlaneLadder.perceive("gevurah", "beriah")
	check(str(hellish.get("name", "")) == str(angelic.get("name", "")), "it is the same named place in both registers")
	check(str(hellish.get("tone", "")) != str(angelic.get("tone", "")), "but it reads differently through each one (%s vs %s)" % [hellish.get("tone"), angelic.get("tone")])

	# --- AV2.2: the substance decides, altitude is read, never set directly -
	check(is_equal_approx(PlaneLadder.altitude("player"), 0.0), "nothing taken yet, nothing to read (altitude 0)")
	var dose := Substances.take("player", "choir_bloom")
	check(bool(dose.get("ok", false)), "sanity: the door substance was actually taken")
	var after_dose := PlaneLadder.altitude("player")
	check(after_dose > 0.0, "taking a door substance actually raises altitude, read back from the event it left")
	check(PlaneLadder.has_floor("player", "yesod", "talk"), "and it is enough on its own to talk on a plane one step up")

	# --- AV2.5: it decays rather than staying wherever it was set -----------
	# Backdate the event this altitude reading came from, rather than waiting
	# out a real half-life — same technique this project's own chaos-magick
	# test uses (advance the clock the number reads, not the test's own
	# runtime).
	var last_event: Dictionary = WorldHistory.events[WorldHistory.events.size() - 1]
	last_event["time_msec"] = int(last_event["time_msec"]) - int(PlaneLadder.ALTITUDE_HALF_LIFE_MSEC)
	var after_one_half_life := PlaneLadder.altitude("player")
	check(after_one_half_life < after_dose * 0.6, "one half-life later it has genuinely roughly halved (%.2f vs %.2f)" % [after_one_half_life, after_dose])
	check(after_one_half_life > 0.0, "but it has not vanished outright")

	# --- meditation reaches the same tier the weaker door-substance does, slower
	WorldHistory.register_subject("sitter", {"name": "Sitter", "kind": "person"})
	Meditation.begin("sitter")
	Meditation.tick("sitter", 60.0)
	Meditation.end("sitter")
	check(PlaneLadder.altitude("sitter") > 0.0, "a full meditation hold also reads as real altitude")
	check(PlaneLadder.has_floor("sitter", "yesod", "talk"), "sixty seconds of sitting reaches the same floor a dose does, per the design's own parity")

	# --- AV1.4: the petition verb, a real cost to open it -------------------
	var no_seal := PlaneLadder.petition("player", "yesod", "", "blood", 50.0)
	check(not bool(no_seal.get("ok", false)), "a petition with no seal is refused outright")

	var too_high := PlaneLadder.petition("player", "keter", "a name spoken once", "blood", 50.0)
	check(not bool(too_high.get("ok", false)), "and one aimed above your own altitude is refused before anything is spent")

	var on_daath := PlaneLadder.petition("player", PlaneLadder.DAATH, "a name", "blood", 50.0)
	check(not bool(on_daath.get("ok", false)), "and Da'ath refuses a petition outright, full stop")

	var blood_before := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	var petitioned := PlaneLadder.petition("player", "yesod", "a name, spoken with the seal drawn under it", "blood", 80.0)
	check(bool(petitioned.get("ok", false)), "a real seal, a real offering, altitude already earned — the petition succeeds")
	var blood_after_petition := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	check(blood_after_petition < blood_before, "and the offering actually left the body (%.0f -> %.0f)" % [blood_before, blood_after_petition])
	var petition_events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "plane_petitioned")
	check(petition_events.size() == 1 and PLAYER_ACTION_LEDGER.count("plane_petitioned") == 1 and str((petition_events[0].get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"), "the paid petition is one identified act later systems can read")

	# --- AV1.4's other half: a licence to depart also costs something -------
	var departed := PlaneLadder.depart("player", "yesod", "blood", 40.0)
	check(bool(departed.get("ok", false)), "leaving is its own paid act")
	var blood_after_departure := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	check(blood_after_departure < blood_after_petition, "and it costs something too, on the way out (%.0f -> %.0f)" % [blood_after_petition, blood_after_departure])
	check(PLAYER_ACTION_LEDGER.count("plane_departed") == 1, "the paid departure has one player-action receipt")

	# --- AV2.3: coming down mid-interaction is a real, remembered failure ---
	WorldHistory.register_subject("faller", {"name": "Faller", "kind": "person"})
	var still_up := PlaneLadder.sustain_or_fail("faller", "malkuth", "talk")
	check(bool(still_up.get("ok", false)), "at altitude 0 on Malkuth (needs 0), sustaining a talk still holds")
	var never_climbed := PlaneLadder.sustain_or_fail("faller", "yesod", "talk")
	check(not bool(never_climbed.get("ok", false)), "but on a plane one step up with nothing taken, the same hold fails")
	var failure_events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "plane_altitude_failed" and str((e.get("details", {}) as Dictionary).get("subject_id", "")) == "faller")
	check(failure_events.size() == 1, "and the failure is a real recorded event, not a silent no-op")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "offerings, crossings, plane memory and altitude failure always close their nested transactions")

	# --- AV3.1: planes are real WorldHistory subjects, Da'ath is not --------
	PlaneLadder.register_planes()
	check(str(WorldHistory.subject("keter").get("kind", "")) == "plane", "every reachable plane registers as a real subject")
	check(WorldHistory.subject(PlaneLadder.DAATH).is_empty(), "Da'ath is never registered — nothing can hold a relationship with a place off the map")

	# --- the ladder and the tree describe the same ten -----------------------
	# `Sephiroth` (geometry: positions, the twenty-two paths) and `PlaneLadder`
	# (mechanic: what altitude each floor costs) are separate files on purpose,
	# but they both list the ten sephiroth, and that is the one place they can
	# silently disagree. A sephirah added to the tree and not the ladder draws a
	# node nothing can reach; added to the ladder and not the tree, it is a place
	# with no position on the chart. Asserted rather than trusted.
	var tree_ten: Array = Sephiroth.ORDER.duplicate()
	var ladder_ten: Array = PlaneLadder.PLANES.keys()
	tree_ten.sort()
	ladder_ten.sort()
	check(tree_ten == ladder_ten, "the tree's ten sephiroth and the ladder's ten are the same ten")

	# Da'ath is the exception both sides have to get right in the same way: real
	# data in each, reachable in neither.
	check(Sephiroth.NAMES.has(PlaneLadder.DAATH), "the tree knows Da'ath exists")
	check(not Sephiroth.ORDER.has(PlaneLadder.DAATH), "but never counts it among the ten")
	check(not PlaneLadder.reachable_planes().has(PlaneLadder.DAATH), "and the ladder never offers it as somewhere to go")

	print("PLANE_LADDER_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
