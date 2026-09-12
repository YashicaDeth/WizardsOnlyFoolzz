extends Node

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "status": "awake", "defeats": 0})
	WorldHistory.register_subject("rook", {"name": "Rook", "kind": "person", "faction_id": "ashline_wreckers"})
	var event_count := WorldHistory.event_count()
	var result := DefeatRouter.route("rook", "ashbloom_bone_yard")
	var player := WorldHistory.subject("player")
	check(str(result.outcome) == "shackled", "Ashline defeat routes to shackled")
	check(str(player.status) == "shackled" and str(player.captor_id) == "rook", "the player persists as a captive instead of reloading")
	check(str(player.held_at) == "ashline_shackle_pit", "defeat moves the player to the captor's real destination")
	check(int(player.defeats) == 1, "the loss remains on the player record")
	check(WorldHistory.event_count() == event_count + 2, "defeat and capture are written as history")
	check(WorldHistory.event_count("player_defeated") == 1, "the defeat has its own event")
	WorldHistory.register_subject("inventory", {"items": [{"label": "STOLEN HEART"}, {"label": "RUST SCRIP"}], "rust_scrip": 9})
	var identity_before := str(WorldHistory.subject("player").name)
	var reborn := DefeatRouter.redecant()
	check(str(reborn.status) == "redecanted", "a captive can choose deliberate death")
	check((reborn.forfeited as Array).size() == 2 and (WorldHistory.subject("inventory").items as Array).is_empty(), "re-decanting forfeits everything carried")
	check(int(WorldHistory.subject("inventory").rust_scrip) == 9, "currency is not loose carried loot")
	check(str(WorldHistory.subject("player").name) == identity_before, "the same protagonist returns")
	check(WorldHistory.event_count("player_deliberate_death") == 1 and WorldHistory.event_count("player_redecanted") == 1, "death and re-decanting both remain in history")
	check(DefeatRouter.redecant().is_empty(), "re-decanting is only available from captivity")
	print("DEFEAT_ROUTER_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
