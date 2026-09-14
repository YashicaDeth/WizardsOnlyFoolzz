extends Node

## AT1.3/AT1.5/AT1.7/AT1.8. The four claims in `DESIGN/THE_BRAIN.md` that are
## logic rather than render, each held to the thing that would actually break
## it: that a keyword can be bought, that the bridge opens without the chip,
## that the trail survives going dark, and that 8D is free.

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

	# --- AT1.3: an index, and most of it optional ---------------------------
	check(BrainIndex.FOLDERS.size() >= 12, "the index has %d folders" % BrainIndex.FOLDERS.size())
	check(BrainIndex.FOLDERS.has("unknown"), "and one of them is UNKNOWN")
	var ratio := BrainIndex.optional_ratio()
	check(ratio > 0.8, "most of what is in it is optional (%.0f%%)" % (ratio * 100.0))
	check(BrainIndex.required_entries().size() == 3, "exactly three entries are not optional")

	check(BrainIndex.is_open("self_name"), "an unsealed entry is readable from the start")
	check(not BrainIndex.is_open("the_table"), "a sealed entry is not")
	var sealed_read := BrainIndex.read_entry("the_table")
	check(not bool(sealed_read.get("ok", false)) and str(sealed_read.get("reason", "")) == "SEALED", "and reading it is refused as SEALED")

	# Listed but not readable — the whole difference between an index and an
	# inventory. The player can see the shape of what they have not remembered.
	var trauma := BrainIndex.listing("trauma")
	check(trauma.size() >= 2, "the TRAUMA folder still lists its sealed entries (%d)" % trauma.size())
	var hidden := true
	for row in trauma:
		if not bool(row.open) and str(row.title) != "[SEALED]":
			hidden = false
	check(hidden, "but every sealed row reads [SEALED] rather than its title")

	# --- remembering, not buying --------------------------------------------
	var bought := BrainIndex.unlock("RESTRAINT")
	check(not bool(bought.get("ok", false)), "RESTRAINT is refused: the word is known, the meaning is not")
	check(str(bought.get("reason", "")).begins_with("YOU KNOW THE WORD"), "and it says so in those terms")

	WorldHistory.record_event("player_captured", {"captor": "celloutz_intake", "faction_id": "celloutz", "outcome": "processed", "destination": "the tank"})
	check(BrainIndex.has_evidence("RESTRAINT"), "being taken is the evidence, and it is read off the log")
	check(BrainIndex.discovered_keywords().has("RESTRAINT"), "so RESTRAINT is now speakable")

	var remembered := BrainIndex.unlock("restraint")
	check(bool(remembered.get("ok", false)), "and now it opens")
	check((remembered.get("opened", []) as Array).size() == 2, "opening the whole afternoon, not one file (%d entries)" % (remembered.get("opened", []) as Array).size())
	check(BrainIndex.is_open("the_table") and BrainIndex.is_open("who_held_you"), "both sealed entries under that word are open")
	check(WorldHistory.event_count("memory_recovered") == 1, "a recovery is a recorded event like anything else")
	check(not bool(BrainIndex.unlock("RESTRAINT").get("ok", false)), "and it cannot be remembered twice")

	# A threshold keyword is not satisfied by one instance of its evidence.
	for i in 2:
		WorldHistory.record_event("npc_resolution", {"subject_id": "npc_%d" % i, "outcome": "spare", "actor": "player"})
	check(not BrainIndex.has_evidence("MERCY"), "two acts of mercy is not the three MERCY needs")
	WorldHistory.record_event("npc_resolution", {"subject_id": "npc_2", "outcome": "spare", "actor": "player"})
	check(BrainIndex.has_evidence("MERCY"), "the third one is")
	# Wrong-outcome events of the same type must not count toward it.
	WorldHistory.record_event("npc_resolution", {"subject_id": "npc_9", "outcome": "killed", "actor": "player"})
	check(BrainIndex.evidence_count("MERCY") == 3, "a killing is not mercy even though it is the same event type")

	# --- the UNKNOWN regions are genuinely closed ---------------------------
	var abyss := BrainIndex.unlock("DA'ATH")
	check(not bool(abyss.get("ok", false)), "DA'ATH is indexed and unreadable")
	check(str(abyss.get("reason", "")) == "INDEXED. NOT READABLE.", "with no route offered, because there is none")
	check(BrainIndex.evidence_count("DA'ATH") == 0, "no amount of play produces evidence for it")

	# --- AT1.5: the tower is the bridge -------------------------------------
	check(BrainIndex.chip().is_empty(), "you start with nothing in your head")
	var free_plane := BrainIndex.bridge("player", 4)
	check(bool(free_plane.get("ok", false)), "4D is free — the wizard eyes need no hardware")
	check(not bool(free_plane.get("via_chip", true)), "and it is explicitly not via the chip")
	var unwired := BrainIndex.bridge("player", 5)
	check(not bool(unwired.get("ok", false)), "5D is refused with nothing in your head")
	check(BrainIndex.reach() == 4, "so your reach is 4D")

	var installed := BrainIndex.install_chip("player", "celloutz", "celloutz_surgeon")
	check(bool(installed.get("ok", false)), "the chip is installed by somebody else (%s)" % str(installed.get("serial", "")))
	check(not bool(BrainIndex.install_chip("player").get("ok", false)), "and it cannot be installed twice")
	check(str(BrainIndex.chip().get("owner_faction", "")) == "celloutz", "it answers to celloutz, not to you")
	var cybernetics: Array = (WorldHistory.subject("player").get("anatomy_state", {}) as Dictionary).get("cybernetics", [])
	var found_chip := false
	for implant in cybernetics:
		if str((implant as Dictionary).get("id", "")) == BrainIndex.CHIP_IMPLANT_ID:
			found_chip = true
			check(str((implant as Dictionary).get("zone", "")) == "head", "and it is real hardware in the head zone")
	check(found_chip, "carried on the same cybernetics list as every other implant")

	check(BrainIndex.reach() == 12, "wired, the whole ladder is reachable")
	var hod := BrainIndex.bridge("player", 5, 1.0, "ashbloom_yards")
	check(bool(hod.get("ok", false)) and str(hod.get("sephirah", "")) == "Hod", "5D opens through the chip")
	check(bool(hod.get("via_chip", false)), "and the crossing records that it went through the chip")

	# A plane-gated entry is gated by the bridge, not by the keyword.
	WorldHistory.record_event("entity_took_notice", {"entity_id": "clear_frequency", "subject_id": "player", "mercy_count": 3})
	check(bool(BrainIndex.unlock("NOTICED").get("ok", false)), "NOTICED opens its entry")
	var too_low := BrainIndex.read_entry("it_answered")
	check(bool(too_low.get("ok", false)), "and at full reach the 7D entry reads")

	# --- AT1.8: the thing connecting you is killing you ---------------------
	check(is_zero_approx(BrainIndex.head_dose()), "nothing has melted yet")
	var gevurah := BrainIndex.bridge("player", 8, 4.0, "ashbloom_yards")
	check(bool(gevurah.get("ok", false)), "8D opens")
	check(float(gevurah.get("dose", 0.0)) > 0.0, "and it doses you on the way in (%.1f)" % float(gevurah.get("dose", 0.0)))
	var dose_at_eight := BrainIndex.head_dose()
	check(dose_at_eight > 0.0, "the dose lands on the head zone, where the tower is")
	check(WorldHistory.event_count("wetwire_radiation") == 1, "and it is recorded as radiation, not as a wound")

	BrainIndex.bridge("player", 9, 4.0, "ashbloom_yards")
	var dose_at_nine := BrainIndex.head_dose() - dose_at_eight
	check(dose_at_nine > dose_at_eight, "9g melts you faster than 8g (%.1f vs %.1f for the same seconds)" % [dose_at_nine, dose_at_eight])
	var below := BrainIndex.head_dose()
	BrainIndex.bridge("player", 7, 10.0)
	check(is_equal_approx(BrainIndex.head_dose(), below), "7D and below cost nothing — the melting starts at 8g exactly")

	# --- AT1.7: revocable, traceable, and it can find you --------------------
	check(BrainIndex.trace_level() == 4, "every crossing left a trace (%d)" % BrainIndex.trace_level())
	var no_fix := BrainIndex.locate()
	check(not bool(no_fix.get("found", false)), "four is not yet a fix")
	BrainIndex.bridge("player", 6, 1.0, "black_mile")
	var fix := BrainIndex.locate()
	check(bool(fix.get("found", false)), "five is")
	check(str(fix.get("place", "")) == "black_mile", "and the fix is the real place of the last crossing")
	check(WorldHistory.event_count("wetwire_traced") == 1, "being found is a recorded event the world can react to")

	# Going dark is a real reset and a real cost, not a cosmetic flag.
	check(bool(BrainIndex.go_dark().get("ok", false)), "you can go dark")
	check(BrainIndex.trace_level() == 0, "which actually cuts the trail")
	check(not bool(BrainIndex.locate().get("found", false)), "and they lose the fix")
	var dark_bridge := BrainIndex.bridge("player", 6)
	check(not bool(dark_bridge.get("ok", false)), "but dark, the bridge is shut")
	check(str(dark_bridge.get("reason", "")).begins_with("DARK"), "you cannot hide from it and use it")
	check(BrainIndex.reach() == 4, "dark, your reach falls back to the free plane")
	BrainIndex.surface()
	check(BrainIndex.reach() == 12, "surfacing restores it")
	check(BrainIndex.trace_level() == 0, "and the old trail stays cut")

	# Revocation. Theirs to take; your memories are not theirs to take.
	var opened_before := BrainIndex.opened().size()
	check(bool(BrainIndex.revoke("player", "UNPAID SUBSCRIPTION").get("ok", false)), "the owner can revoke it")
	check(BrainIndex.reach() == 4, "revoked, you are back on the free plane")
	var revoked_bridge := BrainIndex.bridge("player", 5)
	check(not bool(revoked_bridge.get("ok", false)), "and 5D is shut")
	check(str(revoked_bridge.get("reason", "")).contains("UNPAID SUBSCRIPTION"), "with their reason attached, not a generic failure")
	check(BrainIndex.opened().size() == opened_before, "but nothing you remembered was taken back")
	check(bool(BrainIndex.read_entry("the_table").get("ok", false)), "a ground-level memory still reads with the chip dead")
	var gated := BrainIndex.read_entry("it_answered")
	check(not bool(gated.get("ok", false)), "while the 7D entry is shut behind the dead chip")
	check(str(gated.get("reason", "")).begins_with("REVOKED"), "and it says which of the three refusals this is")
	check(bool(BrainIndex.reinstate().get("ok", false)) and BrainIndex.reach() == 12, "reinstating opens it again")

	# --- AT1.6's data half, built and deliberately not ticked ---------------
	WorldHistory.register_subject("vanity_promoter", {"name": "THE PROMOTER", "kind": "person", "faction_id": "vanity_row", "status": "active"})
	WorldHistory.register_subject("fools_acolyte", {"name": "THE ACOLYTE", "kind": "person", "faction_id": "wizardsonlyfoolz", "status": "active"})
	var above := BrainIndex.wire_from_above()
	check(bool(above.get("ok", false)), "the Wire can be read from 5D")
	var rows: Array = above.get("accounts", [])
	check(rows.size() >= 3, "and it is the same accounts, not a second dataset (%d)" % rows.size())
	var descending := true
	for i in range(1, rows.size()):
		if float((rows[i] as Dictionary).alignment) > float((rows[i - 1] as Dictionary).alignment):
			descending = false
	check(descending, "re-ranked by Tree alignment rather than by reach")
	BrainIndex.revoke("player", "TERMS")
	check(not bool(BrainIndex.wire_from_above().get("ok", false)), "with the chip revoked there is no view from above at all")

	print("BRAIN_INDEX_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
