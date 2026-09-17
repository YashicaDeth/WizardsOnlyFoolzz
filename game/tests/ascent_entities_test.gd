extends Node

## E5.1/E5.2. Ascent entities must run on the same shape as any rival — a
## conclusion drawn from the log, not a shop — and washing sins must be a real
## cost (refused until earned, spent on use) rather than a free tap.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _spare(index: int) -> void:
	WorldHistory.record_event("npc_resolution", {"subject_id": "npc_%d" % index, "outcome": "spare", "actor": "player"})


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	AscentEntities.seed_entities()
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "both ascent entities seed in one closed schema transaction")

	var seeded := WorldHistory.subject("clear_frequency")
	check(str(seeded.get("kind", "")) == "entity", "The Clear Frequency is registered as an entity")
	check(str(seeded.get("faction_id", "")) == "wizardsonlyfoolz", "and sits under wizardsonlyfoolz on the Tree")
	check(not bool(seeded.get("has_noticed", true)), "it starts unnoticed — attention has to be earned")

	# --- attention is a conclusion, not a button -----------------------------
	AscentEntities.regard("clear_frequency")
	check(not bool(WorldHistory.subject("clear_frequency").get("has_noticed", false)), "one act of mercy is not enough (threshold 3)")

	for i in 2:
		_spare(i)
	AscentEntities.regard("clear_frequency")
	check(not bool(WorldHistory.subject("clear_frequency").get("has_noticed", false)), "still short of the threshold at 2 of 3")

	_spare(2)
	AscentEntities.regard("clear_frequency")
	check(bool(WorldHistory.subject("clear_frequency").get("has_noticed", false)), "the third act of mercy earns its attention")

	# The live Hunt writes one state-change event and one canonical resolution
	# for the same spared person. Attention counts the person once, not both rows.
	WorldHistory.amend_subject("clear_frequency", {"has_noticed": false, "washed_at_sequence": WorldHistory.next_sequence - 1})
	WorldHistory.record_event("npc_spared", {"subject_id": "same_person", "actor": "player"})
	WorldHistory.record_event("npc_resolution", {"subject_id": "same_person", "outcome": "spare", "actor": "player"})
	AscentEntities.regard("clear_frequency")
	check(not bool(WorldHistory.subject("clear_frequency").get("has_noticed", false)), "duplicate ledger rows for one spared person count as one mercy, not two")
	WorldHistory.amend_subject("clear_frequency", {"has_noticed": true, "washed_at_sequence": -1})

	# --- washing is refused before notice, real once granted ----------------
	var refused := AscentEntities.wash("still_ledger")
	check(not bool(refused.get("ok", false)), "The Still Ledger refuses — it has not noticed you")

	var before_karma := float(WorldHistory.subject("player").get("karma", 0.0))
	var granted := AscentEntities.wash("clear_frequency")
	check(bool(granted.get("ok", false)), "The Clear Frequency, having noticed you, will wash")
	var after_karma := float(WorldHistory.subject("player").get("karma", 0.0))
	check(after_karma > before_karma, "and it actually moves you up the axis (%.3f -> %.3f)" % [before_karma, after_karma])
	check(PlayerActionLedger.count("sin_washed") == 1 and int(WorldHistory.get("_ledger_batch_depth")) == 0, "the karma event and spent attention close as one identified player act")

	# --- the notice is spent, not free to use twice --------------------------
	check(not bool(WorldHistory.subject("clear_frequency").get("has_noticed", false)), "attention is spent on use")
	AscentEntities.regard("clear_frequency")
	check(not bool(WorldHistory.subject("clear_frequency").get("has_noticed", false)), "the same three old acts of mercy cannot re-earn it")

	for i in range(10, 13):
		_spare(i)
	AscentEntities.regard("clear_frequency")
	check(bool(WorldHistory.subject("clear_frequency").get("has_noticed", false)), "a fresh run of mercy earns it again")

	# --- re-seeding is migration-safe, never erases earned attention --------
	AscentEntities.seed_entities()
	check(bool(WorldHistory.subject("clear_frequency").get("has_noticed", false)), "re-seeding does not quietly reset earned attention")

	print("ASCENT_ENTITIES_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
