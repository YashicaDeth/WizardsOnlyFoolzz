extends Node

## Dead cloud slot machine, provably fair. The roll is pure — boundaries,
## gold at one in a hundred, refusals for unknown and unpaid boxes — and the
## only randomness lives with the caller, so this file never needs a mock die.

const CASE := preload("res://systems/loot_case.gd")
const PURSE := preload("res://systems/carry.gd")
const HUMAN := preload("res://systems/baseline_human.gd")
const GARMENT := preload("res://systems/clothing_shell.gd")

var failures: Array[String] = []


func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- the table --------------------------------------------------------------
	var total := 0.0
	for tier: Dictionary in CASE.TIERS:
		total += float(tier.weight)
	check(absf(total - 100.0) < 0.001, "weights sum to a hundred, so a draw reads as odds (%.1f)" % total)

	# --- boundaries ---------------------------------------------------------------
	check(CASE.tier_for(0.0) == "scrap", "a dead draw buys scrap")
	check(CASE.tier_for(0.599) == "scrap", "just under the line is still scrap")
	check(CASE.tier_for(0.60) == "useful", "the line itself moves up")
	check(CASE.tier_for(0.849) == "useful", "upper edge holds")
	check(CASE.tier_for(0.85) == "rare", "rare starts where it says")
	check(CASE.tier_for(0.949) == "rare", "and holds its band")
	check(CASE.tier_for(0.95) == "relic", "relic where priced")
	check(CASE.tier_for(0.989) == "relic", "up to the last percent")
	check(CASE.tier_for(0.99) == "gold", "gold is the top one percent, exactly")

	# --- receipts -------------------------------------------------------------------
	var hit: Dictionary = CASE.open("celloutz_cache", 0.995, true)
	check(bool(hit.get("ok", false)) and str(hit.get("tier", "")) == "gold", "a golden draw opens golden")
	check(str(hit.get("kind", "")) == "gold" and int(hit.get("amount", 0)) == 1, "one gold, never a stack")
	check(int(hit.get("price", 0)) == 25, "priced what the case costs")
	var poor: Dictionary = CASE.open("celloutz_cache", 0.995, false)
	check(not bool(poor.get("ok", true)) and str(poor.get("reason", "")) == "UNPAID", "unpaid boxes do not roll")
	var lost: Dictionary = CASE.open("no_such_case", 0.5, true)
	check(not bool(lost.get("ok", true)) and str(lost.get("reason", "")) == "NO SUCH CASE", "unknown cases refuse by name")
	var cheap: Dictionary = CASE.open("celloutz_cache", 0.1, true)
	check(bool(cheap.get("ok", false)) and int(cheap.get("amount", 0)) >= 2, "scrap still pays something (%d)" % int(cheap.get("amount", 0)))

	# --- winnings land somewhere real ------------------------------------------------
	WorldHistory.register_subject("inventory", {"items": [], "rust_scrip": 100})
	var purse = PURSE.new()
	var scrip_win: Dictionary = purse.take_case_winnings(CASE.open("celloutz_cache", 0.1, true))
	check(bool(scrip_win.get("ok", false)) and int(WorldHistory.subject("inventory").get("rust_scrip", 0)) > 100, "scrip reaches the wallet (%s)" % str(scrip_win.get("note", "")))
	var gold_win: Dictionary = purse.take_case_winnings(CASE.open("celloutz_cache", 0.995, true))
	check(int(WorldHistory.subject("inventory").get("rust_scrip", 0)) >= 100 + CASE.GOLD_VALUE, "gold pays a flat fortune (>= %d)" % (100 + CASE.GOLD_VALUE))
	var before_items: int = purse.items.size()
	purse.take_case_winnings(CASE.open("celloutz_cache", 0.86, true))
	check(purse.items.size() == before_items + 1, "hardware becomes a pocketed item")
	var won = purse.items[before_items]
	check(str(won.get("kind", "")) == "cybernetic" and str(won.get("implant", "")) != "", "shaped for install_into, so a case can put hardware in you")
	var bad: Dictionary = purse.take_case_winnings({"ok": false, "reason": "UNPAID"})
	check(not bool(bad.get("ok", true)), "a bad receipt lands nothing")
	# Patches sew into the worst zone when a rig is on hand.
	var rig: BaselineHuman = HUMAN.new()
	add_child(rig)
	rig.build("patch_dummy", {})
	await get_tree().process_frame
	rig.dress(GARMENT.ruin_wardrobe())
	var patched: Dictionary = purse.take_case_winnings({"ok": true, "kind": "patch", "amount": 1, "tier": "useful", "case": "celloutz_cache"}, rig)
	check(bool(patched.get("ok", false)) and str(patched.get("note", "")).begins_with("PATCH SEWN"), "a patch sews into the worst zone (%s)" % str(patched.get("note", "")))
	rig.queue_free()

	print("LOOT_CASE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
