extends Node

## AU3.5/AU3.6. "Same same" is the requirement, so this is the test that makes
## it mean something: every place that offers substances offers the *same* ones,
## because there is one object rather than three layouts.
##
## The failure this is written against is not hypothetical. E2 ended up with two
## directors for the same seventy-two seals, and ritual_ledger.gd and
## ritual_app.gd spent a month not meeting - both times because the same idea
## was expressed twice.

const STATION := preload("res://systems/substance_station.gd")
const SHED := preload("res://systems/shed.gd")
const SMOKEABLES := preload("res://systems/smokeables.gd")
const SUBSTANCES := preload("res://systems/substances.gd")

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

	# --- the manifest is real and covers everything --------------------------
	var ids := STATION.manifest_ids()
	check(ids.size() >= 9, "the station offers a real spread, not a token two")
	for substance_id: String in SUBSTANCES.CATALOG:
		var found := false
		for entry: String in ids:
			if entry.begins_with("substance:%s:" % substance_id):
				found = true
		check(found, "%s is reachable from a station" % substance_id)
	for device_id: String in SMOKEABLES.CATALOG:
		check(ids.has("smokeable:%s:-" % device_id), "%s is reachable from a station" % device_id)

	# --- two stations agree, which is the whole point ------------------------
	var a: Node3D = STATION.new()
	add_child(a)
	a.build()
	var b: Node3D = STATION.new()
	add_child(b)
	b.build(false)
	var a_ids: Array[String] = []
	for entry in (a.pickups() as Array):
		a_ids.append("%s:%s" % [entry["kind"], entry["id"]])
	var b_ids: Array[String] = []
	for entry in (b.pickups() as Array):
		b_ids.append("%s:%s" % [entry["kind"], entry["id"]])
	check(a_ids == b_ids, "two stations built independently offer an identical set")
	check(a_ids.size() == ids.size(), "and a built station offers exactly what the manifest says")

	# --- reach, and taking ---------------------------------------------------
	var first: Dictionary = (a.pickups() as Array)[0]
	var at: Vector3 = (first["node"] as Node3D).global_position
	var near: Dictionary = a.nearest(at)
	check(near.get("id", "") == first["id"], "standing on a thing puts it in reach")
	var inspected: Dictionary = a.inspection_nearest(at)
	check(inspected.get("source") == first["node"], "inspection presents the actual world object rather than a parallel icon")
	check(inspected.get("item_id", "") == first["id"] and not str(inspected.get("label", "")).is_empty(),
		"the shared inspection grammar receives a stable identity and readable label")
	check((a.pickups() as Array).size() == ids.size(), "looking at a pickup does not consume it")
	var far: Dictionary = a.nearest(at + Vector3(0, 0, 40.0))
	check(far.is_empty(), "and standing in the next county does not")
	check(a.inspection_nearest(at + Vector3(0, 0, 40.0)).is_empty(), "nor can a distant object be inspected through the world")
	var fixture_probe: Dictionary = a.inspection_nearest((a as Node3D).to_global(Vector3(1.04, STATION.TOP_Y, 0.08)), 0.08)
	check(str(fixture_probe.get("kind", "")) == "fixture" and str(fixture_probe.get("label", "")) == "ASHTRAY",
		"fixed working objects enter the same inspection contract without becoming takeable")

	var before: int = (a.pickups() as Array).size()
	var lifted: Dictionary = a.take_nearest(at)
	check(not lifted.is_empty(), "what is in reach can be taken")
	check(str(lifted.get("label", "")) != "", "and it comes back named, so a prompt has something to say")
	check(not lifted.has("node"), "without handing the caller a freed node to hold on to")
	await get_tree().process_frame
	check((a.pickups() as Array).size() == before - 1, "and the table is one item shorter afterwards")
	var nothing: Dictionary = a.take_nearest(at + Vector3(0, 0, 40.0))
	check(nothing.is_empty(),
		"taking nothing returns nothing, so an interact key can fall through to whatever else it does")

	# --- the shed uses the station rather than its own copy -----------------
	var shed: Node3D = SHED.new()
	add_child(shed)
	shed.build()
	await get_tree().process_frame
	check(shed.station != null, "the shed dresses its bench with a station")
	var shed_ids: Array[String] = []
	for entry in (shed.station.pickups() as Array):
		shed_ids.append("%s:%s" % [entry["kind"], entry["id"]])
	check(shed_ids == b_ids, "so what is on the shed's bench is what is on every other table")

	print("SUBSTANCE_STATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
