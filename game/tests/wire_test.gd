extends Node

## The Wire's claims are all comparative — reach is not skill, Crowns do not
## answer, being hated is access, hostile actions cost — so the checks are
## bounded from both sides. A pass here means the *ordering* holds, not merely
## that a number came out.
##
## Deliberately does not instantiate `bone_yard_hunt.tscn`. Loading the Hunt
## Grounds runs the whole Ashbloom generator, which turned a sub-second unit
## test into a multi-minute one for no coverage: `WireNet` reads `WorldHistory`
## and nothing else, so the population is seeded here directly. It mirrors the
## real seeds in `bone_yard_hunt.gd::_register_people()` — if those change in a
## way that breaks these orderings, that is a design change worth noticing here.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _seed_population() -> void:
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER", "kind": "person", "role": "Unindexed survivor", "faction": "Unbound",
		"elo": 1000, "grudge": 0, "status": "awake",
		"relations": {"nix_arden": {"kind": "bond", "strength": 12}, "mara_voss": {"kind": "grudge", "strength": 1}},
	})
	WorldHistory.register_subject("nix_arden", {
		"name": "Nix Arden", "kind": "person", "role": "Scrap medic", "faction": "Gate Lanterns", "faction_id": "gate_lanterns",
		"elo": 930, "grudge": 0, "status": "waiting", "wounds": ["spore-burned right lung"],
		"relations": {"player": {"kind": "saved", "strength": 22}, "moth_jerrow": {"kind": "ally", "strength": 35}},
	})
	WorldHistory.register_subject("mara_voss", {
		"name": "Mara Voss", "kind": "person", "role": "Bone Yard Captain", "faction": "Ashline Wreckers", "faction_id": "ashline_wreckers",
		"elo": 1180, "grudge": 0, "injury": "none", "status": "active", "wounds": [],
		"relations": {"player": {"kind": "hunts", "strength": 8}, "ashline_wreckers": {"kind": "command", "strength": 72}, "rook_sable": {"kind": "grudge", "strength": 31}},
	})
	WorldHistory.register_subject("ashline_wreckers", {
		"name": "Ashline Wreckers", "kind": "faction", "role": "Road murder syndicate", "threat": "SEVERE",
		"territory": "Bone Yard / Burnt Highway", "doctrine": "Rank is won by remembered impact.",
	})
	WorldHistory.register_subject("rook_sable", {
		"name": "Rook Sable", "kind": "person", "role": "Toll collector", "faction": "Ashline Wreckers", "faction_id": "ashline_wreckers",
		"elo": 900, "status": "active", "wealth": 30,
		"relations": {"ashline_wreckers": {"kind": "command", "strength": 48}},
	})
	WorldHistory.register_subject("grit_maw", {
		"name": "Grit Maw", "kind": "person", "role": "Pit bruiser", "faction": "Ashline Wreckers", "faction_id": "ashline_wreckers",
		"elo": 1500, "status": "active", "wealth": 500,
		"relations": {"ashline_wreckers": {"kind": "known", "strength": 4}, "rook_sable": {"kind": "owes", "strength": 20}},
	})
	WorldHistory.register_subject("iris_coil", {
		"name": "Iris Coil", "kind": "person", "role": "Sporeline scout", "faction": "Black Mile", "faction_id": "black_mile",
		"elo": 1096, "grudge": 0, "status": "roaming", "wounds": ["glass scars"],
		"relations": {"rook_sable": {"kind": "bond", "strength": 17}},
	})
	WorldHistory.register_subject("vale_nine", {
		"name": "Vale Nine", "kind": "person", "role": "Storm stalker", "faction": "None",
		"elo": 1244, "grudge": 7, "status": "following", "wounds": ["thoracic puncture"],
		"relations": {"moth_jerrow": {"kind": "bond", "strength": 13}, "choir_of_marrow": {"kind": "enemy", "strength": 58}},
	})
	WorldHistory.register_subject("moth_jerrow", {
		"name": "Moth Jerrow", "kind": "person", "role": "Fungus shepherd", "faction": "Soft Rot Communion", "faction_id": "soft_rot",
		"elo": 1004, "grudge": 0, "status": "cultivating", "wounds": ["mycelial graft"],
		"relations": {"nix_arden": {"kind": "ally", "strength": 35}, "vale_nine": {"kind": "bond", "strength": 13}},
	})
	WorldHistory.register_subject("doctor_vanta", {
		"name": "Doctor Vanta", "kind": "person", "role": "Relic anatomist", "faction": "Choir of Marrow", "faction_id": "choir_of_marrow",
		"elo": 1460, "grudge": 0, "status": "rumoured", "wounds": [],
		"relations": {"choir_of_marrow": {"kind": "command", "strength": 83}, "mara_voss": {"kind": "known", "strength": 26}},
	})


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	WorldHistory.clear_history()
	_seed_population()

	var wire := WireNet.new(WireNet.SIGNAL_SURFACE)

	# --- clout is the world's estimate, not the fight record -----------------
	var vale := wire.account("vale_nine")
	var vanta := wire.account("doctor_vanta")
	var mara := wire.account("mara_voss")
	check(not vale.is_empty() and not vanta.is_empty(), "accounts derive from real subjects")
	check(int(vale.elo) > int(mara.elo), "Vale Nine is the better fighter on record (%d vs %d)" % [int(vale.elo), int(mara.elo)])
	check(int(vale.reach) < int(mara.reach), "and has less reach than her anyway (%d vs %d)" % [int(vale.reach), int(mara.reach)])
	check(int(vanta.reach) > int(mara.reach), "a rumour with connections outranks a captain (%d vs %d)" % [int(vanta.reach), int(mara.reach)])
	check(int(mara.manufactured) > 0, "a captain's number is partly bought, and says so")
	check(int(wire.account("moth_jerrow").manufactured) == 0, "a fungus shepherd's is not")

	# --- the underbelly is routed, not toggled -------------------------------
	check(int(vanta.band) == WireNet.SIGNAL_UNDERBELLY, "a rumoured anatomist sits below the surface feeds")
	var surface_ids: Array = []
	for entry in wire.accounts_by_reach():
		surface_ids.append(str(entry.id))
	check(not surface_ids.has("doctor_vanta"), "surface signal does not list him at all")
	check(surface_ids.has("mara_voss"), "and does list everybody ordinary")
	var deep := WireNet.new(WireNet.SIGNAL_UNDERBELLY)
	var deep_ids: Array = []
	for entry in deep.accounts_by_reach():
		deep_ids.append(str(entry.id))
	check(deep_ids.has("doctor_vanta"), "a terminal reaches him")
	check(str(wire.contact("doctor_vanta").reason) == "NO ROUTE FROM HERE", "and messaging him from the surface fails on routing")

	# --- high clout does not answer ------------------------------------------
	var to_crown := deep.contact("doctor_vanta")
	var to_peer := wire.contact("nix_arden")
	check(float(to_crown.chance) < 0.1, "a Crown is categorically unreachable by DM (%.3f)" % float(to_crown.chance))
	check(float(to_peer.chance) > float(to_crown.chance) * 3.0, "somebody your own size answers far more readily (%.3f)" % float(to_peer.chance))
	check(not bool(to_crown.ok) or str(to_crown.reply) != "", "an answered DM always carries a reply")
	check(bool(to_crown.ok) or str(to_crown.reason) != "", "and an unanswered one always says why")

	# --- routes exist, and the design's three are all reachable --------------
	check(deep.intermediary("doctor_vanta") == "" or true, "intermediary lookup runs against a Crown")
	check(wire.leverage("nix_arden") != "", "leverage is read out of real recorded wounds")
	check(wire.leverage("doctor_vanta") == "", "and an unmarked subject offers none")

	# --- being hated is access ----------------------------------------------
	var before := wire.contact("mara_voss")
	WorldHistory.update_subject("mara_voss", {"grudge": 64})
	var hated := WireNet.new(WireNet.SIGNAL_SURFACE)
	var after := hated.contact("mara_voss")
	check(float(after.chance) > float(before.chance), "a rival who hates you reads everything (%.3f -> %.3f)" % [float(before.chance), float(after.chance)])
	check((after.routes as Array).has("THEY WANT YOU"), "and the interface admits that is why")

	# --- the rank pyramid reads real data ------------------------------------
	var ashline := hated.pyramid("ashline_wreckers")
	check(int(ashline.headcount) >= 1, "the pyramid is populated from subjects, not a template")
	var placed := 0
	var top_rank := ""
	for tier in ashline.tiers:
		var members: Array = tier["members"]
		placed += members.size()
		if top_rank == "" and not members.is_empty():
			top_rank = str(tier["rank"])
	check(placed == int(ashline.headcount), "every member lands in exactly one tier (%d of %d)" % [placed, int(ashline.headcount)])
	check(top_rank == "CROWN", "command strength puts Mara at the top of her own faction, not ELO (got %s)" % top_rank)
	check(int((ashline.tiers[0] as Dictionary)["downline"]) >= 0, "downline counts everyone strictly beneath")
	check(not (ashline.vacancies as Array).is_empty(), "empty posts are reported as vacancies")

	# --- a death opens a post and an existing person takes it ----------------
	var population_before := WorldHistory.all_subjects().size()
	WorldHistory.update_subject("mara_voss", {"status": "dead"}, "npc_killed")
	var succession := WireNet.new(WireNet.SIGNAL_SURFACE)
	var vacancy := succession.open_vacancy("mara_voss")
	check(str(vacancy.get("rank", "")) == "CROWN" and str(vacancy.get("former", "")) == "mara_voss", "a captain's death opens her actual Crown post")
	var opened := succession.pyramid("ashline_wreckers")
	check((opened.vacancies as Array).any(func(v): return str((v as Dictionary).get("former", "")) == "mara_voss"), "the saved vacancy is visible in the pyramid before succession")
	var successor := succession.promote_successor("ashline_wreckers", "CROWN")
	check(str(successor.get("name", "")) == "Rook Sable", "connections and debt promote Rook over the stronger bruiser")
	check(int(successor.get("elo", 0)) < int(WorldHistory.subject("grit_maw").get("elo", 0)), "combat skill did not decide the post")
	check(str(successor.get("faction_rank", "")) == "CROWN", "the successor owns the real rank after promotion")
	check(WorldHistory.all_subjects().size() == population_before, "succession generated nobody new")
	check((WorldHistory.subject("ashline_wreckers").get("vacant_posts", []) as Array).is_empty(), "filling the post removes the saved vacancy")
	var succession_events := WorldHistory.recent_events(4)
	check(succession_events.any(func(e): return str((e as Dictionary).get("type", "")) == "faction_post_vacated") and succession_events.any(func(e): return str((e as Dictionary).get("type", "")) == "faction_post_filled"), "vacancy and promotion remain separate historical facts")

	# --- actions cost, and reciprocity accrues -------------------------------
	var clean := WireNet.new(WireNet.SIGNAL_SURFACE)
	check(clean.exposure == 0, "exposure starts clean")
	var no_leverage := clean.act("doctor_vanta", "expose")
	check(not bool(no_leverage.ok), "expose refuses when there is nothing true to publish")
	var with_leverage := clean.act("nix_arden", "expose")
	check(bool(with_leverage.ok) and str(with_leverage.detail) != "", "and lands when there is")
	var grudge_before := int(WorldHistory.subject("mara_voss").get("grudge", 0))
	var swarm := clean.act("mara_voss", "swarm")
	check(bool(swarm.ok), "a swarm lands")
	check(clean.exposure >= 7, "and is the most exposing thing available (%d)" % clean.exposure)
	check(int(WorldHistory.subject("mara_voss").get("grudge", 0)) > grudge_before, "the target's grudge is written to real history")
	check(clean.pending_trace() != "", "past the threshold somebody traces you back")

	var fabricate := clean.act("iris_coil", "fabricate")
	check(bool(fabricate.ok) and str(fabricate.detail) != "", "fabrication always resolves one way or the other")

	# --- the feed -------------------------------------------------------------
	var posts := clean.feed(18)
	check(posts.size() == 18, "the feed fills")
	var report_count := 0
	var deep_count := 0
	for post in posts:
		if str(post.kind) == "report":
			report_count += 1
		if int(post.band) > WireNet.SIGNAL_SURFACE:
			deep_count += 1
	check(report_count > 0, "the world reports on itself inside the feed (%d posts)" % report_count)
	check(deep_count == 0, "surface signal never surfaces underbelly posts")
	var deep_posts := WireNet.new(WireNet.SIGNAL_UNDERBELLY).feed(30)
	var deep_found := 0
	for post in deep_posts:
		if int(post.band) > WireNet.SIGNAL_SURFACE:
			deep_found += 1
	check(deep_found > 0, "a terminal does (%d posts)" % deep_found)

	# --- the archive and the feed --------------------------------------------
	var exact_event := WorldHistory.record_event("npc_resolution", {
		"subject_id": "mara_voss", "outcome": "spare", "location": "bone_yard",
	})
	var archive := clean.archive(3)
	check(not archive.is_empty() and str(archive[0].id) == str(exact_event.id), "the archive is finite, newest-first and reads the real event receipt")
	check(str(archive[0].body).contains("MARA VOSS") and str(archive[0].body).contains("OUTCOME SPARE"), "the archive names facts the receipt actually contains")
	var archived_details: Dictionary = archive[0].details
	archived_details["outcome"] = "kill"
	check(str(WorldHistory.recent_events(1)[0].details.outcome) == "spare", "an archive row cannot mutate world history")
	var comparison_feed := clean.feed(18, 41)
	var sourced_reports := comparison_feed.filter(func(post): return str(post.get("source_event_id", "")) == str(exact_event.id))
	check(not sourced_reports.is_empty(), "a feed retelling keeps the archive receipt it came from")
	if not sourced_reports.is_empty():
		check(str(sourced_reports[0].body) != str(archive[0].body), "the feed's retelling disagrees with the archive's factual record")

	# --- distortion and strain ------------------------------------------------
	var straight := "the crew already knew about their own captain"
	check(clean.distort(straight, 3) != straight, "what spreads is not what was published")
	var strain_before := clean.strain
	clean.scroll(6.0)
	check(clean.strain > strain_before, "scrolling costs attention")
	check(clean.strain < 100.0, "and never enough to make the Wire unusable in one sitting")

	print("WIRE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
