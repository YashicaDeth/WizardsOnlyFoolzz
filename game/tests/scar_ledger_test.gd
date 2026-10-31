extends Node

## Brief 2, `scar-ledger`. A landed blow leaves one line on the body and it is
## still there after a reload.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _rig() -> BaselineHuman:
	var body := BaselineHuman.new()
	add_child(body)
	body.build("scar_subject", {})
	return body


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	# An afternoon in ASHWAKE, day one.
	WorldHistory.world_minute = 13.0 * 60.0 + 20.0

	# --- What a blow leaves. ------------------------------------------------
	var stick := {"at": Vector3(0.02, 0.31, 0.0), "type": "cut", "depth": 0.2, "through": false}
	var blade := ScarLedger.from_wound("left_arm", stick, WorldHistory.world_minute)
	check(str(blade.cause) == "BLADE" and str(blade.zone_label) == "LEFT ARM", "a cut is a blade scar on the limb it landed in")
	check(str(blade.bone).is_empty() and not ScarLedger.is_empty_bone(blade) == false, "a shallow cut does not claim a bone")
	check(int(blade.round) == 0, "a blade has no round count")
	check(not str(blade.stamp).is_empty() and str(blade.stamp).contains("ASHWAKE"), "a scar carries the world's date, not a real month")

	var deep := ScarLedger.from_wound("left_arm", {"at": Vector3(0.0, 0.3, 0.0), "type": "ballistic", "depth": 0.8, "through": false}, WorldHistory.world_minute)
	check(str(deep.cause) == "ROUND" and str(deep.bone) == "HUMERUS", "a round that got deep enough reached the humerus")
	var through := ScarLedger.from_wound("torso", {"at": Vector3.ZERO, "type": "puncture", "depth": 0.2, "through": true}, WorldHistory.world_minute)
	check(str(through.bone) == "RIB", "a round that left the body crossed the rib")

	# --- Rounds are counted, and only rounds. -------------------------------
	var ledger: Array = []
	ledger = ScarLedger.record(ledger, "left_arm", {"at": Vector3.ZERO, "type": "cut", "depth": 0.3}, WorldHistory.world_minute)
	ledger = ScarLedger.record(ledger, "left_arm", {"at": Vector3.ZERO, "type": "ballistic", "depth": 0.4}, WorldHistory.world_minute)
	ledger = ScarLedger.record(ledger, "torso", {"at": Vector3.ZERO, "type": "ballistic", "depth": 0.7}, WorldHistory.world_minute)
	check(ledger.size() == 3 and ScarLedger.rounds_in(ledger) == 2, "the second round into a body is round two")
	check(str(ledger[2].label) == "#2 · ROUND · TORSO · 1 ASHWAKE", "the line reads as a sentence: number, cause, place, date (got %s)" % str(ledger[2].label))
	check(str(ledger[0].label).begins_with("BLADE · LEFT ARM"), "a cut's line carries no number")
	check(ScarLedger.quote(ledger) == str(ledger[2].label), "the card quotes the most recent scar that reached a bone")

	var full: Array = []
	for index in ScarLedger.MAX_SCARS + 4:
		full = ScarLedger.record(full, "torso", {"at": Vector3.ZERO, "type": "blunt", "depth": 0.1}, WorldHistory.world_minute + float(index))
	check(full.size() == ScarLedger.MAX_SCARS, "a body's ledger is capped so a save cannot grow without limit")
	check(full[full.size() - 1].minute > full[0].minute, "and it drops the oldest, never the newest")

	# --- A real blow on a real body. ---------------------------------------
	var body := _rig()
	var arm := body.parts.get("left_arm") as Node3D
	var point := arm.global_position + Vector3(0.0, 0.12, 0.0)
	body.hit_at(point, 12.0, 6.0, "ballistic", Vector3.RIGHT)
	body.hit_at(point, 12.0, 6.0, "ballistic", Vector3.RIGHT)
	check(body.scars.size() == 2, "two landed blows leave two scars on the body")
	check(int(body.scars[1].round) == 2, "the second blow is round two on that body")
	check(str(body.scars[0].zone) == "left_arm", "the scar landed in the arm that was hit")
	var local: Variant = body.scars[0].at
	check(local is Vector3, "the impact point is kept in the limb's own space")
	if local is Vector3:
		var back := arm.to_global(local)
		check(back.distance_to(point) < 0.06, "and it still resolves to the place the round went in (%.3f m off)" % back.distance_to(point))
	check(body.wound_marks.has("left_arm") and (body.wound_marks["left_arm"] as Array).size() >= 2, "the marks that draw the holes are still written too")

	# --- It survives a save, the way a mark does. -------------------------
	var saved := JSON.stringify(body.snapshot())
	# A body comes back the way every other body in the game does: built from the
	# record it was put down with.
	var relaunched := BaselineHuman.new()
	add_child(relaunched)
	relaunched.build("scar_subject_reloaded", {"restore": JSON.parse_string(saved)})
	check(relaunched.scars.size() == 2, "the ledger comes back with the body")
	check(relaunched.scars[0].at is Vector3, "and its impact points are vectors again, not JSON")
	if relaunched.scars[0].at is Vector3:
		var restored_arm := relaunched.parts.get("left_arm") as Node3D
		check(restored_arm.to_global(relaunched.scars[0].at).distance_to(point) < 0.06, "the scar is still where it landed after a reload")
	check(str(relaunched.scars[1].label) == str(body.scars[1].label), "the line a person is read by does not change across a save")
	check(int(relaunched.scars[1].round) == 2, "the round count survives too")

	# --- A scar is a mark, not a statistic: it crosses a quantum restart. --
	var carried := BaselineHuman.scars_of(body.snapshot())
	check(carried.has("scars") and (carried["scars"] as Array).size() == 2, "the scars are carried across a restart with the other permanent marks")

	# --- Nothing new is invented for a body that has never been hit. ------
	var clean := _rig()
	check(clean.scars.is_empty() and ScarLedger.quote(clean.scars).is_empty(), "an unhit body reads empty")

	print("SCAR_LEDGER_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
