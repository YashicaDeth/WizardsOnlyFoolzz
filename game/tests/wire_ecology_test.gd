extends Node

const SiteCatalog := preload("res://systems/wire_site_catalog.gd")

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor", "faction": "Unbound", "status": "awake", "relations": {}})
	WorldHistory.register_subject("moth_jerrow", {"name": "Moth Jerrow", "kind": "person", "role": "Fungus shepherd", "faction": "Soft Rot Communion", "faction_id": "soft_rot", "status": "cultivating", "relations": {}})
	WorldHistory.register_subject("doctor_vanta", {"name": "Doctor Vanta", "kind": "person", "role": "Relic anatomist", "faction": "Choir of Marrow", "faction_id": "choir_of_marrow", "status": "rumoured", "relations": {}})

	check(SiteCatalog.validate_links().is_empty(), "every authored cross-link resolves")
	var layouts: Dictionary = {}
	for site in SiteCatalog.all_sites():
		layouts[str((site.aesthetic as Dictionary).layout)] = true
	check(layouts.size() >= 7, "the ecology exposes genuinely distinct page treatments")

	var surface := WireNet.new(WireNet.SIGNAL_SURFACE)
	var fungus: Dictionary = surface.search_web("fungus soup")
	check(int(fungus.count) > 0 and str((fungus.results[0] as Dictionary).site_id) == "softrot_picnic", "search ranks an authored personal page by meaning")
	var people: Dictionary = surface.search_web("Moth Jerrow")
	check((people.results as Array).any(func(r): return str((r as Dictionary).site_id) == "profile:moth_jerrow"), "search discovers a character's separate online body")
	var moth_online: Dictionary = surface.account("moth_jerrow").online
	var player_online: Dictionary = surface.account("player").online
	check(str(moth_online.subject_id) == "moth_jerrow" and str(moth_online.profile_uri) != "", "online identity links back to canonical character truth")
	check((moth_online.avatar as Dictionary).seed != (player_online.avatar as Dictionary).seed, "characters receive distinct deterministic avatar hooks")
	check((surface.sites_for_account("moth_jerrow") as Array).size() == 1, "authored character websites link through the account API")

	var hidden: Dictionary = surface.search_web("marrow donor darkweb")
	check(not (hidden.results as Array).any(func(r): return str((r as Dictionary).site_id) == "marrow_exchange"), "surface search does not leak an underbelly address")
	var blocked: Dictionary = surface.open_site("marrow_exchange")
	check(not bool(blocked.ok) and str(blocked.reason) == "NO ROUTE FROM HERE", "known dark address still requires a physical route")
	var deep := WireNet.new(WireNet.SIGNAL_UNDERBELLY)
	var revealed: Dictionary = deep.search_web("marrow donor")
	check((revealed.results as Array).any(func(r): return str((r as Dictionary).site_id) == "marrow_exchange"), "underbelly terminal reveals the gated market")
	var market: Dictionary = deep.open_site("marrow_exchange")
	var page: Dictionary = market.get("page", {})
	var lots: Array = page.get("market_lots", [])
	check(bool(market.ok) and not lots.is_empty() and not ((lots[0] as Dictionary).get("provenance", []) as Array).is_empty(), "market lots carry in-game scarcity and provenance")
	check(str((page.sections[0] as Dictionary).body).contains("outside the game"), "market explicitly remains a fictional in-game ledger")

	deep.open_site("softrot_picnic")
	var followed: Dictionary = deep.follow_site_link("softrot_picnic", 0)
	check(bool(followed.ok) and str((followed.page as Dictionary).id) == "lantern_repair", "authored links form a navigable rabbit hole")
	var back: Dictionary = deep.browser_back()
	check(bool(back.ok) and str((back.page as Dictionary).id) == "softrot_picnic", "back returns through the actual visit trail")
	var forward: Dictionary = deep.browser_forward()
	check(bool(forward.ok) and str((forward.page as Dictionary).id) == "lantern_repair", "forward restores the descended page")
	var saved := deep.browser_save_state()
	var restored := WireNet.new(WireNet.SIGNAL_UNDERBELLY)
	restored.restore_browser_state(saved)
	check(restored.browser_state().trail == deep.browser_state().trail and restored.browser_state().cursor == deep.browser_state().cursor, "rabbit-hole history round-trips through additive save state")
	var legacy := WireNet.new(WireNet.SIGNAL_SURFACE)
	legacy.restore_browser_state({})
	check((legacy.browser_state().trail as Array).is_empty(), "an older save with no browser payload receives safe defaults")

	print("WIRE_ECOLOGY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
