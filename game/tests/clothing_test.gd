extends Node

## AS3. Layers as a world system: a real reason to wear one (warmth, faction
## standing), pockets as a small named capacity distinct from carry.gd's bag,
## and none of it invented under a real-world brand per non-negotiable 1.

const CLOTHING := preload("res://systems/clothing.gd")

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
	WorldHistory.register_subject("player", {"kind": "player"})

	check(Clothing.worn("player") == "bare", "nobody has dressed you yet, so you read as bare")
	check(float(Clothing.stats("player").get("warmth", -1.0)) == 0.0, "and bare has no warmth to give")

	var refused := Clothing.wear("player", "not_a_real_layer")
	check(not bool(refused.get("ok", true)), "an invented layer is refused")

	var result := Clothing.wear("player", "storm_oilskin")
	check(bool(result.get("ok", false)), "a real layer is accepted")
	check(Clothing.worn("player") == "storm_oilskin", "and it is what you are actually wearing now")
	check(float(Clothing.stats("player").get("warmth", 0.0)) > 0.3, "oilskin actually has real warmth in it")

	var nobody := Clothing.wear("a_subject_that_does_not_exist", "bare")
	check(not bool(nobody.get("ok", true)), "you cannot dress a subject that does not exist")

	# AS3.3. The layer's bias reaches WorldHistory.tree_alignment() by way of
	# a field wear() writes onto the subject itself.
	WorldHistory.register_subject("wearer", {"faction_id": "", "kind": "npc"})
	var bare_alignment: float = WorldHistory.tree_alignment(WorldHistory.subject("wearer"))
	Clothing.wear("wearer", "gate_lantern_wrap")
	var dressed_alignment: float = WorldHistory.tree_alignment(WorldHistory.subject("wearer"))
	check(dressed_alignment > bare_alignment, "a layer with a positive bias actually moves where you sit (%.3f -> %.3f)" % [bare_alignment, dressed_alignment])

	# AS3.2. Pockets: a small, named capacity, not a mass.
	check(Clothing.pocketed("player").is_empty(), "pockets start empty")
	for item in ["choir_bloom_dose", "a_key", "a_note"]:
		var pocketed := Clothing.pocket("player", item)
		check(bool(pocketed.get("ok", false)), "pocketing %s while there is room succeeds" % item)
	var overfull := Clothing.pocket("player", "one_too_many")
	check(not bool(overfull.get("ok", true)), "a fourth item does not fit (capacity is %d)" % Clothing.POCKET_CAPACITY)
	check(Clothing.pocketed("player").size() == Clothing.POCKET_CAPACITY, "exactly capacity items are actually held")

	var removed := Clothing.unpocket("player", "a_key")
	check(bool(removed.get("ok", false)), "taking a named item back out succeeds")
	check(not Clothing.pocketed("player").has("a_key"), "and it is actually gone")
	check(Clothing.pocketed("player").size() == Clothing.POCKET_CAPACITY - 1, "freeing a slot actually frees it")
	var missing := Clothing.unpocket("player", "never_was_there")
	check(not bool(missing.get("ok", true)), "removing something never pocketed is refused")

	# Non-negotiable 1: nothing in the catalog is a real substance/fabric
	# wearing a thin disguise.
	var real_world_names := ["kevlar", "cocaine", "heroin", "morphine"]
	for item_id in Clothing.CATALOG:
		var entry: Dictionary = Clothing.CATALOG[item_id]
		var label := str(entry.get("label", "")).to_lower()
		for banned in real_world_names:
			check(not label.contains(banned), "%s is not a real-world name in a thin disguise" % item_id)

	if failures.is_empty():
		print("clothing: a world system, not a paperdoll")
		get_tree().quit(0)
	else:
		print("clothing FAILURES: ", failures)
		get_tree().quit(1)
