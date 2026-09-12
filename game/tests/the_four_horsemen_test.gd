extends Node

## K2. Four real named subjects, a rotating succession that is scored rather
## than scripted, and a CellOutz doctrine that actually changes with whoever
## holds the post.

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
	CosmologyFactions._seed()
	TheFourHorsemen.seed_horsemen()

	for horseman_id in ["war", "famine", "pestilence", "death"]:
		var subject := WorldHistory.subject(horseman_id)
		check(str(subject.get("kind", "")) == "person", "%s is a real registered subject, not a health bar in a room" % horseman_id)
		check(str(subject.get("faction_id", "")) == "celloutz", "and belongs to CellOutz")

	check(DemonHierarchy.tier("war") == "LEADERSHIP", "War, holding CROWN, reads as Leadership")
	for waiting in ["famine", "pestilence", "death"]:
		check(DemonHierarchy.tier(waiting) == "", "%s, not currently reigning, is not read as Leadership yet" % waiting)

	check(TheFourHorsemen.current_reign() == "war", "current_reign() correctly names War")
	var war_doctrine := TheFourHorsemen.current_doctrine()
	check(str(war_doctrine.get("reigning_horseman", "")) == "war", "current_doctrine() names the reigning Horseman")
	check(str(war_doctrine.get("doctrine", "")).contains("speed"), "and CellOutz's doctrine actually reads as War's own version of it")

	# --- K2.2: a real succession, scored rather than scripted ---------------
	var wire := WireNet.new()
	WorldHistory.update_subject("war", {"status": "dead"})
	var vacancy := wire.open_vacancy("war")
	check(str(vacancy.get("rank", "")) == "CROWN", "War's death opens a real CROWN vacancy on CellOutz")
	var promoted := wire.promote_successor("celloutz", "CROWN")
	check(not promoted.is_empty(), "the vacancy is actually filled")
	var new_reign := TheFourHorsemen.current_reign()
	check(new_reign in ["famine", "pestilence", "death"], "one of the other three Horsemen actually takes the post (got %s)" % new_reign)
	check(DemonHierarchy.tier("war") != "LEADERSHIP", "and the fallen Horseman no longer reads as Leadership")
	check(DemonHierarchy.tier(new_reign) == "LEADERSHIP", "while the new one does")

	# --- K2.3/K2.4: the succession is felt, not cosmetic ---------------------
	var new_doctrine := TheFourHorsemen.current_doctrine()
	check(str(new_doctrine.get("doctrine", "")) != str(war_doctrine.get("doctrine", "")), "CellOutz's own doctrine actually changed with the succession, not just the name at the top")
	check(str(new_doctrine.get("threat", "")) != "" , "and it still carries a real threat rating")

	# --- K2.5 v2: the reigning Horseman has real behaviour of their own -----
	var horseman_grudge_before := int(WorldHistory.subject(new_reign).get("grudge", 0))
	wire.contest_channel("vanity_row", "cut", "player", true)
	var horseman_grudge_after := int(WorldHistory.subject(new_reign).get("grudge", 0))
	check(horseman_grudge_after > horseman_grudge_before, "attacking a Sin CellOutz commands actually raises the reigning Horseman's own grudge (%d -> %d)" % [horseman_grudge_before, horseman_grudge_after])
	var captain_grudge_gain := int(WorldHistory.subject("cass_lumen").get("grudge", 0))
	check(horseman_grudge_after - horseman_grudge_before < captain_grudge_gain, "but less than the Sin's own captain feels it directly — once removed, not the same hit")

	print("THE_FOUR_HORSEMEN_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
