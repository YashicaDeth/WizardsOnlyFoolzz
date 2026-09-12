extends Node

## E3. Completion comes from a photograph's anatomy evidence, not from a
## caption, a generic kill count, or a separate turn-in state.

const RITUAL_LEDGER := preload("res://systems/ritual_ledger.gd")
const FIELD_CAMERA := preload("res://systems/field_camera.gd")

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

	var definitions := RITUAL_LEDGER.all()
	check(definitions.size() == 1 and str(definitions[0].get("id", "")) == "five_gored_heads", "the first rite is exactly the documented five-head example")

	# One body shown five times is still one body. FieldCamera owns the
	# distinct-subject rule, so a ritual cannot quietly count photo records.
	var repeated := _crown_record("one_body", true, true)
	var repeat_photo := {"id": "repeat", "contents": [repeated, repeated, repeated, repeated, repeated]}
	check(not bool(RITUAL_LEDGER.evaluate(repeat_photo, "five_gored_heads").get("ok", false)), "five angles of one corpse do not become five heads")

	# The composite condition matters: five dead intact people plus five living
	# destroyed heads must not satisfy five *dead destroyed* heads.
	var split: Array[Dictionary] = []
	for index in 5:
		split.append(_crown_record("dead_intact_%d" % index, true, false))
		split.append(_crown_record("living_destroyed_%d" % index, false, true))
	var split_photo := {"id": "split_proof", "contents": split}
	check(not bool(RITUAL_LEDGER.evaluate(split_photo, "five_gored_heads").get("ok", false)), "dead and destroyed must be true on each same matched body")

	var crowns: Array[Dictionary] = []
	for index in 5:
		crowns.append(_crown_record("crown_%d" % index, true, true))
	var proof := {"id": "proof_crowns", "taken_msec": 44, "location": "ashbloom_bone_yard", "contents": crowns, "caption": "A LIE CANNOT HELP"}
	check(bool(RITUAL_LEDGER.evaluate(proof, "five_gored_heads").get("ok", false)), "five genuinely dead destroyed heads in one frame satisfy the rite")
	var accepted := RITUAL_LEDGER.submit_photo(proof)
	check((accepted.get("completed", []) as Array).size() == 1, "taking evidence completes the rite without a turn-in action")
	var ledger: Dictionary = WorldHistory.subject("ritual_ledger")
	var entry: Dictionary = (ledger.get("rituals", {}) as Dictionary).get("five_gored_heads", {}) as Dictionary
	check(str(entry.get("photo_id", "")) == "proof_crowns" and entry.has("photo"), "the completed record keeps the evidence even if the album rolls over")
	check(WorldHistory.event_count("ritual_completed") == 1, "completion is one recorded world event")

	RITUAL_LEDGER.submit_photo(proof)
	check(WorldHistory.event_count("ritual_completed") == 1, "resubmitting proof cannot complete the same rite twice")

	# A frame held before rituals are checked still counts when the ledger is
	# reconciled from the persistent camera album.
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	FIELD_CAMERA.store(proof)
	var reconciled := RITUAL_LEDGER.reconcile_album()
	check((reconciled.get("completed", []) as Array).size() == 1, "an older photo is reconciled as valid evidence")
	check(WorldHistory.event_count("ritual_completed") == 1, "album reconciliation writes the same single completion event")

	print("RITUAL_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _crown_record(subject_id: String, dead: bool, destroyed: bool) -> Dictionary:
	return {
		"subject_id": subject_id, "dead": dead, "downed": false,
		"severed": [], "destroyed": ["head"] if destroyed else [], "ruptured": [], "opened": {},
	}
