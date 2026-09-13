extends Node

## AU5/AV. The door opens onto somebody, contact is earned rather than bought,
## and every entry in the catalogue is actually drawable.

const CONTACTS := preload("res://systems/contact_entities.gd")
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

	# --- every entry is storyboard-ready ------------------------------------
	for entry in CONTACTS.all():
		var who := str(entry.get("label", entry.get("id", "?")))
		for field: String in ["form", "does", "regard", "leaves", "storyboard"]:
			check(str(entry.get(field, "")).length() > 30, "%s says something concrete about '%s'" % [who, field])
		check(not (entry.get("channels", []) as Array).is_empty(), "%s arrives through named channels" % who)
		for channel in entry.get("channels", []) as Array:
			check(CONTACTS.CHANNELS.has(str(channel)), "%s's channel '%s' is in the taxonomy" % [who, channel])
		check(Substances.CATALOG.has(str(entry.get("substance", ""))), "%s hangs off a real substance" % who)
		check(str(entry.get("plane", "")) != "", "%s belongs to a plane" % who)

	# --- only door substances open onto anybody -----------------------------
	for substance_id: String in Substances.CATALOG:
		var opens := not CONTACTS.for_substance(substance_id).is_empty()
		var is_door := bool((Substances.CATALOG[substance_id] as Dictionary).get("door", false))
		if is_door:
			check(opens, "%s is a door and opens onto somebody" % substance_id)

	# --- the phase each contact appears in is a phase that substance has -----
	for entry in CONTACTS.all():
		var phases: Array = (SX.PROFILES[str(entry["substance"])] as Dictionary)["phases"]
		var names: Array[String] = []
		for raw in phases:
			names.append(str((raw as Dictionary).get("name", "")))
		check(names.has(str(entry.get("phase", ""))),
			"%s appears in a phase %s actually has" % [str(entry["label"]), str(entry["substance"])])

	# --- E5: contact is earned, never bought --------------------------------
	check(CONTACTS.contact_for("player", "choir_bloom", 0, 0.3).is_empty(),
		"a weak dose reaches nobody - an entity is not a purchase")
	check(not CONTACTS.contact_for("player", "choir_bloom", 0, 1.3).is_empty(),
		"a strong one does")
	check(CONTACTS.contact_for("player", "choir_bloom", 0, 1.3) == CONTACTS.contact_for("player", "choir_bloom", 0, 1.3),
		"and the same dose meets the same entity twice - a save is reproducible")
	check(CONTACTS.contact_for("player", "marrow_dust", 0, 2.0).size() > 0,
		"even the body one can be reached if you take enough")

	# --- tolerance closes the door ------------------------------------------
	var reached_worn := CONTACTS.contact_for("player", "choir_bloom", 9, 1.0)
	check(reached_worn.is_empty(), "a ninth dose at ordinary strength reaches nobody")

	# --- the record keeps what was left, and only once ----------------------
	var first := CONTACTS.record("player", "the_jester_that_counts", "choir_bloom")
	check(bool(first.get("ok", false)) and bool(first.get("first_time", false)), "a first contact is recorded as first")
	var again := CONTACTS.record("player", "the_jester_that_counts", "choir_bloom")
	check(not bool(again.get("first_time", true)), "meeting it again is not a new contact")
	check((WorldHistory.subject("player").get("contacts", []) as Array).size() == 1, "and it is only in the list once")
	var events := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "contact_made")
	check(events.size() == 2, "both meetings are real recorded events even so")

	# --- no entity hands out objectives -------------------------------------
	for entry in CONTACTS.all():
		var text := ("%s %s %s" % [entry["does"], entry["regard"], entry["leaves"]]).to_lower()
		check(not (text.contains("quest") or text.contains("objective") or text.contains("reward you")),
			"%s has no quest to give" % str(entry["label"]))

	print("CONTACT_ENTITIES_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
