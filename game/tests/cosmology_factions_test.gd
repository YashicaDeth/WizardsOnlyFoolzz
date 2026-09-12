extends Node

## K1.2 / K1.3 / K4.1 / K4.2. CellOutz, wizardsonlyfoolz and the three
## previously-missing Sins (Pride, Lust, Sloth) must exist as real subjects
## with pyramids and prices, not just entries in `FACTION_TREE_AXIS`.

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

	# The autoload seeds itself at boot; under ATG_TEST_MODE this test scene is
	# its own boot, so call it directly rather than depending on sibling
	# autoload _ready ordering inside a headless single-scene run.
	CosmologyFactions._seed()

	for faction_id in ["celloutz", "wizardsonlyfoolz", "vanity_row", "honeyvein", "long_static"]:
		var subject := WorldHistory.subject(faction_id)
		check(str(subject.get("kind", "")) == "faction", "%s is registered as a faction" % faction_id)
		check(str(subject.get("doctrine", "")) != "", "%s has a doctrine, not just a name in a table" % faction_id)

	for pair in [["cass_lumen", "vanity_row"], ["juno_veil", "honeyvein"], ["gray_hollis", "long_static"]]:
		var captain := WorldHistory.subject(pair[0])
		check(str(captain.get("faction_id", "")) == pair[1], "%s actually belongs to %s" % [pair[0], pair[1]])

	# --- the new Sins sit on the axis where COSMOLOGY.md put them ----------
	var wrath := WorldHistory.tree_alignment({"faction_id": "ashline_wreckers"})
	var pride := WorldHistory.tree_alignment({"faction_id": "vanity_row"})
	var lust := WorldHistory.tree_alignment({"faction_id": "honeyvein"})
	var sloth := WorldHistory.tree_alignment({"faction_id": "long_static"})
	var floor_axis := WorldHistory.tree_alignment({"faction_id": "celloutz"})
	check(pride < 0.0 and lust < 0.0 and sloth < 0.0, "all three new Sins sit in Descent")
	check(sloth < wrath, "Sloth sinks at least as far as an existing Sin (%.2f < %.2f)" % [sloth, wrath])
	check(floor_axis < pride and floor_axis < lust and floor_axis < sloth, "CellOutz sits below all seven Sins, not beside them")

	# --- felt presence: the pyramid and the pricing both see them ----------
	var wire := WireNet.new()
	var pyramid := wire.pyramid("vanity_row")
	check(pyramid.headcount >= 1, "Vanity Row has a real member, not an empty faction (%d)" % pyramid.headcount)
	check(str(pyramid.doctrine) != "No stated doctrine.", "the pyramid reads Vanity Row's real doctrine")

	var celloutz_pyramid := wire.pyramid("celloutz")
	var crown_empty := (celloutz_pyramid.tiers[0].members as Array).is_empty()
	check(crown_empty, "CellOutz's CROWN rank is genuinely empty — the Horsemen are not named yet")
	var crown_vacancy: bool = celloutz_pyramid.vacancies.any(func(v): return str((v as Dictionary).get("rank", "")) == "CROWN")
	check(crown_vacancy, "and the pyramid surfaces that as a real vacancy rather than hiding it")

	var neutral := WorldHistory.faction_price_factor("honeyvein", {"faction_id": ""})
	check(neutral > 0.0, "a newcomer can still deal with a brand-new Sin faction")

	# --- K1.3: wizardsonlyfoolz has real ranks/paid grades without needing
	# the still-blocked Law/Book/founder content -----------------------------
	check(str(WorldHistory.subject("wren_ashby").get("faction_id", "")) == "wizardsonlyfoolz", "wren_ashby actually belongs to wizardsonlyfoolz")
	var wof_pyramid := wire.pyramid("wizardsonlyfoolz")
	check(wof_pyramid.headcount >= 1, "wizardsonlyfoolz has a real member, not an empty order (%d)" % wof_pyramid.headcount)
	check((wof_pyramid.tiers[4].members as Array).size() >= 1, "and they sit at the bottom rank, paid in rather than promoted")

	# --- migration is safe: seeding twice must not duplicate or erase -------
	var before_relations: Dictionary = WorldHistory.subject("celloutz").get("relations", {})
	CosmologyFactions._seed()
	var after_relations: Dictionary = WorldHistory.subject("celloutz").get("relations", {})
	check(before_relations == after_relations, "re-seeding does not duplicate or alter CellOutz's relations")

	# --- wizardsonlyfoolz stays clear of the open Gate Lanterns question ----
	var wof := WorldHistory.subject("wizardsonlyfoolz")
	check(not (wof.get("relations", {}) as Dictionary).has("gate_lanterns"), "wizardsonlyfoolz takes no position on Gate Lanterns — still open per COSMOLOGY.md")

	print("COSMOLOGY_FACTIONS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
