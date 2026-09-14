extends Node

## AV3.2-AV3.7. A relationship that accumulates across trips; standing
## expressed as how much of a line actually arrives rather than as a meter;
## withholding that names what it is keeping and hands over the identical
## content once it is earned; debt that is really collected out of the body;
## planes that disagree about a kill the way the gods do; and the demonic,
## jesterish register the handheld's jester already belongs to.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _intact_words(source: String, spoken: String) -> Array:
	var kept: Array = []
	var a := source.split(" ")
	var b := spoken.split(" ")
	if a.size() != b.size():
		return kept
	for index in a.size():
		if str(a[index]) == str(b[index]):
			kept.append(str(a[index]))
	return kept


func _has_digit(text: String) -> bool:
	for index in text.length():
		if text[index] >= "0" and text[index] <= "9":
			return true
	return false


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("mule_tam", {"name": "Mule Tam", "kind": "person"})
	Sephiroth.register_planes()
	ModernGods.seed_gods()

	var line := "THE LEDGER IS OPEN AND YOUR NAME IS WRITTEN IN IT TWICE"

	# --- AV3.7: the register exists for every place that has a voice ---------
	for plane_id in Sephiroth.reachable_planes():
		check(PlaneVoices.MASK.has(plane_id), "%s has a mask and a jest of its own" % plane_id)
	check(not PlaneVoices.MASK.has(Sephiroth.DAATH), "Da'ath has no voice here either — nothing off the map gets a face")

	# --- AV3.3: a stranger's line arrives with holes in it -------------------
	var stranger := PlaneVoices.voice("hod", "player", line)
	check(stranger != line, "at zero standing the line does not arrive whole")
	check(stranger.split(" ").size() == line.split(" ").size(), "but it is plainly the same sentence — same word count, same order")
	check(PlaneVoices.voice("hod", "player", line) == stranger, "and it is deterministic: the same entity garbles the same words the same way twice")
	check(PlaneVoices.distort(line, 1.0, "hod|player") == line, "at full clarity the transform is the identity, byte for byte")

	# The readout is the whole expression of standing — no number in it.
	var readout := PlaneVoices.handheld_readout("hod", "player", line)
	check(not _has_digit(readout), "the readout carries no number, no bar, no percentage (AV3.3)")
	check(readout.contains(str(PlaneVoices.MASK["hod"].mask)), "it is attributed to the thing that is grinning at you")

	# AV3.7's rule, made mechanical: the jest never distorts, the truth always does.
	var spoken := PlaneVoices.speak("hod", "player", line)
	check(str(spoken.jest) == str(PlaneVoices.MASK["hod"].jest), "the jest arrives intact even at zero standing — the fool is louder than the oracle")
	check(str(spoken.line) != line, "while the sentence that matters does not")
	check(not bool(spoken.whole), "and it knows it did not arrive whole")

	# --- AV3.3: monotone — it clears, it never reshuffles --------------------
	var low := _intact_words(line, PlaneVoices.distort(line, 0.15, "hod|player"))
	var mid := _intact_words(line, PlaneVoices.distort(line, 0.55, "hod|player"))
	var high := _intact_words(line, PlaneVoices.distort(line, 0.9, "hod|player"))
	check(low.size() < high.size(), "more of it arrives as clarity rises (%d -> %d words)" % [low.size(), high.size()])
	var monotone := true
	for word in low:
		if not mid.has(word) or not high.has(word):
			monotone = false
	for word in mid:
		if not high.has(word):
			monotone = false
	check(monotone, "and every word that already survived keeps surviving — the readout clears, it does not become a different sentence")

	# --- AV3.6: they disagree about a kill, the way the gods do -------------
	var verdicts := PlaneVoices.record_plane_verdicts("mule_tam", "player", {"contracted": true, "public": true, "witnessed": 6, "harvested": true})
	check(verdicts.size() == 10, "every reachable plane gave its own opinion on the one death (%d)" % verdicts.size())
	var split := PlaneVoices.disagreement("mule_tam", "player")
	check((split[PlaneVoices.CALLED_IN] as Array).size() > 0, "some of them called it a debt called in")
	check((split[PlaneVoices.MERCY_WITHHELD] as Array).size() > 0, "and some of them called the same death a mercy withheld")
	check((split[PlaneVoices.CALLED_IN] as Array).has("gevurah"), "Severity is on the approving side, as its own pillar says it must be")
	check((split[PlaneVoices.MERCY_WITHHELD] as Array).has("chesed"), "and Mercy is on the other one — the same kill, two opposite verdicts")
	var middle := PlaneVoices.plane_verdict("tiferet", "mule_tam", {"contracted": true})
	check(str(middle.label).begins_with("UNDECIDED"), "the middle pillar with nothing to read the death through genuinely has no opinion")
	var verdict_events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "plane_verdict")
	check(verdict_events.size() == 10, "each opinion is recorded as its own attributed event, never summed into a score")

	# The disagreement has a consequence: it moves each plane's own standing.
	check(PlaneVoices.standing("gevurah", "player") > 0.0, "the plane that approved of the kill thinks better of you for it")
	check(PlaneVoices.standing("chesed", "player") < 0.0, "and the one that did not thinks worse — opposite directions off one act")

	# --- AV3.4: it knows a specific thing, and it says so while refusing ----
	var nothing := PlaneVoices.ask("yesod", "player", "your_falls")
	check(not bool(nothing.get("ok", false)) and not bool(nothing.get("known", true)), "with no falls on record it says plainly that it has nothing — not a hint, nothing")
	var nonsense := PlaneVoices.ask("yesod", "player", "the_price_of_fish")
	check(not bool(nonsense.get("ok", false)), "a topic nobody keeps is refused as such")

	var withheld := PlaneVoices.ask("yesod", "player", "the_dead")
	check(bool(withheld.get("ok", false)), "it answers the question")
	check(bool(withheld.get("known", false)), "and it says outright that it knows the answer")
	check(bool(withheld.get("withheld", false)), "and then refuses to give it at this standing")
	check(str(withheld.get("answer", "x")) == "", "nothing vague comes out in its place — the answer field is empty, not mush")
	check(str(withheld.get("withholding", "")).length() > 20, "the refusal names the shape of what it is sitting on")
	check(float(withheld.get("clears_at", 0.0)) > 0.0, "and names the standing that would buy it")
	var withheld_readout := PlaneVoices.ask_readout("yesod", "player", "the_dead")
	check(not _has_digit(withheld_readout), "even the refusal prints no threshold at the player — they are told a thing is kept, not shown a bar")

	# --- AV3.2/AV3.5: trips accumulate, and creditors collect on arrival -----
	var dose := Substances.take("player", "choir_bloom")
	check(bool(dose.get("ok", false)), "sanity: the door substance opened")
	check(is_zero_approx(PlaneVoices.standing("yesod", "player")), "before the first trip, Yesod has no opinion of you at all")

	var first := Sephiroth.petition("player", "yesod", "a name under a seal", "blood", 10.0)
	check(bool(first.get("ok", false)), "the first petition lands")
	Sephiroth.depart("player", "yesod", "blood", 5.0)
	var after_one := PlaneVoices.standing("yesod", "player")
	check(after_one > 0.0, "one clean trip is worth something (%.2f)" % after_one)
	check(PlaneVoices.trips("yesod", "player") == 1, "and it is one trip, counted")

	for _i in 3:
		Sephiroth.petition("player", "yesod", "a name under a seal", "blood", 10.0)
		Sephiroth.depart("player", "yesod", "blood", 5.0)
	var after_four := PlaneVoices.standing("yesod", "player")
	check(after_four > after_one, "and it genuinely accumulates across trips (%.2f -> %.2f)" % [after_one, after_four])
	check(PlaneVoices.trips("yesod", "player") == 4, "four trips, remembered as four")
	var yesod_edge: Dictionary = WorldHistory.subject("yesod").get("relations", {}).get("player", {})
	check(is_equal_approx(float(yesod_edge.get("standing", -99.0)), after_four), "and it is written on the plane's own subject, where anything else can read it")

	# --- AV3.3 again, now earned: the same line arrives whole ---------------
	check(PlaneVoices.voice("yesod", "player", line) == line, "with the relationship earned, the whole line arrives — no meter ever appeared")
	var earned := PlaneVoices.speak("yesod", "player", line)
	check(bool(earned.whole), "and it knows it arrived whole")

	# --- AV3.4 again: the withheld content was real all along ---------------
	var told := PlaneVoices.ask("yesod", "player", "the_dead")
	check(not bool(told.get("withheld", true)), "at the earned standing it stops withholding")
	check(str(told.get("answer", "")).contains("MULE TAM"), "and the thing it was sitting on was a real name out of the history, recoverable verbatim")

	# --- AV3.5: a debt is real, and it is taken out of the body -------------
	var owed := PlaneVoices.owe("gevurah", "player", "blood", 120.0, "a sight you could not afford")
	check(bool(owed.get("ok", false)), "a plane will let you take something on credit")
	check(is_equal_approx(float(PlaneVoices.debt("gevurah", "player").get("amount", 0.0)), 120.0), "and the figure is stored on its own edge with you")
	var figure := PlaneVoices.ask("gevurah", "player", "your_debt")
	check(str(figure.get("answer", "")).contains("120"), "a creditor always tells you the figure, whatever it thinks of you")

	var blood_before := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	var taken := PlaneVoices.collect("gevurah", "player")
	check(bool(taken.get("ok", false)), "and then it collects")
	var blood_after := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	check(blood_after < blood_before, "out of the body, through the same ledger every other cost here uses (%.0f -> %.0f)" % [blood_before, blood_after])
	check(PlaneVoices.debt("gevurah", "player").is_empty(), "the debt is settled, not merely marked")

	# A default: standing is a ledger you can be empty of, and the debt grows.
	var chesed_before := PlaneVoices.standing("chesed", "player")
	PlaneVoices.owe("chesed", "player", "standing", 40.0, "mercy you had not earned")
	var failed := PlaneVoices.collect("chesed", "player")
	check(not bool(failed.get("ok", true)) and bool(failed.get("defaulted", false)), "collecting from a body that cannot pay is a real default, not a skipped turn")
	check(float(failed.get("now_owed", 0.0)) > 40.0, "the debt is not forgiven, it grows (%.0f)" % float(failed.get("now_owed", 0.0)))
	check(PlaneVoices.standing("chesed", "player") < chesed_before, "and the default costs more standing than any trip ever earned")
	var default_events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "plane_debt_defaulted")
	check(default_events.size() == 1, "the default is a real recorded event")

	# ...and a plane you have defaulted on is genuinely close to unreadable.
	check(PlaneVoices.clarity("chesed", "player") < PlaneVoices.CLARITY_FLOOR, "a plane you stiffed can barely be heard at all")

	# --- AV3.5: they collect on arrival, anywhere ---------------------------
	PlaneVoices.owe("hod", "player", "blood", 60.0, "a page of the ledger you read without asking")
	var blood_pre_trip := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	var arrival := Sephiroth.petition("player", "yesod", "a name under a seal", "blood", 10.0)
	check(bool(arrival.get("ok", false)), "sanity: the arrival itself succeeds")
	check(PlaneVoices.debt("hod", "player").is_empty(), "setting foot on Yesod let Hod collect — you cannot visit the plane you can afford and dodge the one you cannot")
	var blood_post_trip := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", 5000.0))
	check(blood_post_trip <= blood_pre_trip - 60.0, "and Hod's 60 came out of the body on the way in, on top of Yesod's own offering")

	# --- AV3.2: a fall is remembered, and costs more than a trip earned -----
	WorldHistory.register_subject("faller", {"name": "Faller", "kind": "person"})
	Sephiroth.petition("faller", "malkuth", "a seal", "blood", 5.0)
	var faller_after_trip := PlaneVoices.standing("malkuth", "faller")
	Sephiroth.sustain_or_fail("faller", "chokmah", "talk")
	check(PlaneVoices.standing("chokmah", "faller") < -faller_after_trip, "coming down mid-sentence costs a plane's regard more than a clean trip buys (AV2.3 into AV3.2)")
	var fall_answer := PlaneVoices.ask("chokmah", "faller", "your_falls")
	check(bool(fall_answer.get("known", false)) and bool(fall_answer.get("withheld", false)), "it knows exactly how many times you slid off it, and at that standing it will not say")

	print("PLANE_VOICES_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
