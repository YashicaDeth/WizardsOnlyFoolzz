extends Node

## E6.1/E6.3/E6.4. A substance must cost the body through the same ledger
## boons.gd already pays into, a "door" substance must actually open onto an
## entity contact, and a substance must carry and sell like anything else.

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
	AscentEntities.seed_entities()

	check(not Substances.CATALOG.is_empty(), "the catalog has at least one substance")
	for substance_id in Substances.CATALOG:
		var label := str((Substances.CATALOG[substance_id] as Dictionary).get("label", ""))
		check(label != "" and not label.to_lower().contains("meth") and not label.to_lower().contains("heroin"), "%s is named in the world's own vocabulary" % substance_id)

	# --- E6.1: a real body cost, refused rather than lethal -----------------
	var before_blood := 5000.0
	var taken := Substances.take("player", "marrow_dust")
	check(bool(taken.get("ok", false)), "marrow dust is taken")
	var blood_after := float(WorldHistory.subject("player").get("anatomy_state", {}).get("blood", before_blood))
	check(blood_after < before_blood, "and it actually cost blood (%.0f -> %.0f)" % [before_blood, blood_after])
	check(float(taken.get("pain_after", 100.0)) < 100.0, "and pain actually dropped")
	check(not taken.has("glimpsed"), "marrow dust is not a door substance")
	var first_dose_events := WorldHistory.events.filter(func(event: Dictionary): return str(event.get("type", "")) == "substance_taken")
	check(first_dose_events.size() == 1 and str((first_dose_events[0].get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"), "the body mutation and intake fact share one compact player-action receipt")

	WorldHistory.register_subject("empty_ledger", {"name": "Empty", "kind": "person", "anatomy_state": {"blood": 200.0, "blood_capacity": 5000.0}})
	var refused := Substances.take("empty_ledger", "marrow_dust")
	check(not bool(refused.get("ok", false)), "refused rather than driving blood below Boons' own floor")

	# --- E6.3: a door substance actually opens onto an entity ---------------
	var door_result := Substances.take("player", "choir_bloom")
	check(bool(door_result.get("ok", false)), "choir bloom is taken")
	var glimpsed := str(door_result.get("glimpsed", ""))
	check(AscentEntities.ENTITIES.has(glimpsed), "and it names a real entity, not an empty result")
	check(not bool(WorldHistory.subject(glimpsed).get("has_noticed", false)), "a glimpse is not regard() — it does not grant attention")

	var liver_after := float(WorldHistory.subject("player").get("anatomy_state", {}).get("organs", {}).get("liver", {}).get("health", -1.0))
	check(liver_after > 0.0 and liver_after < 40.0, "choir bloom actually costs the liver, not just narrates a cost (%.1f of 40)" % liver_after)

	var events_with_glimpse := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "entity_glimpsed")
	check(not events_with_glimpse.is_empty(), "the glimpse is a real recorded event later systems can read")
	check(PlayerActionLedger.count("substance_taken") == 2 and int(WorldHistory.get("_ledger_batch_depth")) == 0, "both player doses close their nested transaction with one summarized act each")

	# --- E6.4: a substance carries and sells like anything else -------------
	var carry := Carry.new()
	var item := carry.take_substance("static_hymn")
	check(str(item.get("kind", "")) == "substance", "static hymn is carried with kind=substance")
	var price := carry.sale_value(item)
	check(price > 0, "and it has a real sale price (%d)" % price)
	check(carry.condition_label(item) == "FRESH", "and it spoils on the same clock as anything else perishable")

	print("SUBSTANCES_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
