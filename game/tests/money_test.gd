extends Node

## R. One currency with a real issuer, a market of buyers with real
## appetites, prices that actually move with the world, and real debt.

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
	WorldHistory.register_subject("celloutz", {"name": "CellOutz", "kind": "faction", "doctrine": "Ownership, downward."})
	WorldHistory.register_subject("choir_of_marrow", {"name": "Choir of Marrow", "kind": "faction"})
	WorldHistory.register_subject("vanity_row", {"name": "Vanity Row", "kind": "faction"})

	var carry := Carry.new()

	# --- R1.1: the currency has a name and a real issuer ---------------------
	check(Carry.CURRENCY == "rust_scrip", "the currency has an actual name")
	check(carry.currency_reason().contains("CellOutz"), "and a real issuer, read from the actual subject")

	# --- R1.2 (audit): part, condition and whose it was all price it --------
	var fresh_organ := {"kind": "organ", "condition": 1.0, "perishes": false}
	var battered_organ := {"kind": "organ", "condition": 0.4, "perishes": false}
	var stolen_organ := {"kind": "organ", "condition": 1.0, "perishes": false, "stolen": true}
	check(carry.sale_value(fresh_organ) > carry.sale_value(battered_organ), "condition actually prices it")
	check(carry.sale_value(fresh_organ) > carry.sale_value(stolen_organ), "whose it was actually prices it (stolen is worth less)")

	# --- R1.3: buyers have real, different appetites --------------------------
	var organ := {"kind": "organ", "condition": 1.0, "perishes": false}
	var cyber := {"kind": "cybernetic", "condition": 1.0, "perishes": false}
	check(carry.sale_value(organ, "choir_of_marrow") > carry.sale_value(organ, "vanity_row"), "the Choir pays more for an organ than Vanity Row does")
	check(carry.sale_value(cyber, "vanity_row") > carry.sale_value(cyber, "choir_of_marrow"), "and Vanity Row pays more for a cybernetic — a market is people, not a price")

	# --- R1.5: prices actually move with the world's own history -------------
	var glut_organ := {"kind": "organ", "condition": 1.0, "perishes": false}
	var before_glut := carry.sale_value(glut_organ)
	for i in 10:
		WorldHistory.record_event("carried_part_sold", {"part": {"kind": "organ"}, "price": 1})
	var after_glut := carry.sale_value(glut_organ)
	check(after_glut < before_glut, "a real glut of organs sold recently actually lowers the price (%d -> %d)" % [before_glut, after_glut])
	var unrelated_cyber := {"kind": "cybernetic", "condition": 1.0, "perishes": false}
	var cyber_price_after_organ_glut := carry.sale_value(unrelated_cyber)
	var cyber_price_before_anything := 24  # base rate, no buyer, no glut, no condition loss
	check(cyber_price_after_organ_glut == cyber_price_before_anything, "and the glut is specific to organs — an unrelated kind is not touched (%d)" % cyber_price_after_organ_glut)

	# --- R1.4: real debt, in the direction that did not exist before ---------
	check(carry.debt_to("choir_of_marrow") == 0, "starts owing nothing")
	var refused_borrow := carry.borrow(0, "choir_of_marrow")
	check(not bool(refused_borrow.get("ok", false)), "borrowing nothing is refused")
	var wallet_before := int(WorldHistory.subject("inventory").get("rust_scrip", 0))
	var borrowed := carry.borrow(50, "choir_of_marrow")
	check(bool(borrowed.get("ok", false)), "borrowing succeeds")
	check(int(WorldHistory.subject("inventory").get("rust_scrip", 0)) == wallet_before + 50, "and the wallet actually grows by the real amount")
	check(carry.debt_to("choir_of_marrow") == 50, "and the debt is real and owed to the actual lender")
	check(PlayerActionLedger.count("player_borrowed") == 1, "the loan is summarized as one durable player act")

	var over_repay := carry.repay(1000, "choir_of_marrow")
	check(bool(over_repay.get("ok", false)) and int(over_repay.get("paid", -1)) == 50, "repaying more than owed only pays what is actually owed")
	check(carry.debt_to("choir_of_marrow") == 0, "and the debt actually clears")
	var repayment_events := WorldHistory.events.filter(func(event: Dictionary): return str(event.get("type", "")) == "player_repaid")
	check(repayment_events.size() == 1 and str((repayment_events[0].get("details", {}) as Dictionary).get("action_id", "")).begins_with("action_"), "wallet, debt and repayment share one identified action receipt")
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "economy actions leave no open ledger transaction")
	var nothing_owed := carry.repay(10, "choir_of_marrow")
	check(not bool(nothing_owed.get("ok", false)), "repaying a cleared debt is refused, not a silent no-op")

	print("MONEY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
