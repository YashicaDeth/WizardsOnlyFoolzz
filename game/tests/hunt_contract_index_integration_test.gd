extends Node

const CONTRACTS := preload("res://systems/hunt_contracts.gd")
const INDEX := preload("res://systems/world_index.gd")

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
	AscentEntities.seed_entities()
	TheFourHorsemen.seed_horsemen()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "bond": 30.0})
	WorldHistory.register_subject("aura_keeper", {"name": "AURA KEEPER", "kind": "person", "status": "active"})
	var offer := CONTRACTS.publish("war", "aura_keeper", "aura", "Keeps the pit's panic aura coherent", "standing", 5.0)
	var contract_id := str(offer.get("id", ""))

	var index: Control = INDEX.new()
	add_child(index)
	index.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	index.size = Vector2(1280, 720)
	index.open()
	index._go_to_page(index.PAGES.find("WORK"), 1.0)
	index._rebuild_links()
	check(index.PAGES[index.page] == "WORK", "the physical INDEX has one dedicated WORK leaf")
	check(index._rail_cache.size() == 1 and str(index._rail_cache[0].id) == contract_id, "the rail shows the exact persisted contract rather than a copied quest row")
	var take_links: Array = index._link_rects.filter(func(link: Dictionary): return str(link.get("kind", "")) == "hunt_contract")
	check(take_links.size() == 1, "an offered contract exposes one pointable consume action")
	var subject_links: Array = index._link_rects.filter(func(link: Dictionary): return str(link.get("kind", "")) == "contract_subject")
	check(subject_links.size() == 2 and subject_links.any(func(link: Dictionary): return str(link.id) == "war") and subject_links.any(func(link: Dictionary): return str(link.id) == "aura_keeper"), "patron and exact target are both pointable records")

	var standing_before := float(WorldHistory.subject("player").get("bond", 0.0))
	index._follow_link(take_links[0])
	var standing_after := float(WorldHistory.subject("player").get("bond", 0.0))
	check(str(WorldHistory.subject(contract_id).get("status", "")) == "active" and is_equal_approx(standing_before - standing_after, 5.0), "clicking WORK consumes the real offer and pays its standing cost")
	check(not index._link_rects.any(func(link: Dictionary): return str(link.get("kind", "")) == "hunt_contract"), "the consume action disappears as soon as its one use is spent")
	index._accept_selected_contract()
	check(is_equal_approx(float(WorldHistory.subject("player").get("bond", 0.0)), standing_after), "ENTER on the spent row cannot charge the player twice")

	WorldHistory.amend_subject("aura_keeper", {"status": "escaped"})
	CONTRACTS.resolve(contract_id)
	index._rebuild_rail()
	check(str(index._rail_cache[0].note).begins_with("COMPLETED"), "the same WORK row becomes completed when its exact target resolves")

	print("HUNT_CONTRACT_INDEX_INTEGRATION_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
