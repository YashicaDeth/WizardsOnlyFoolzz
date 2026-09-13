extends Node

## AL1 — the bank. AL1.1 (money is a real quantity with a real issuer) is
## already covered by `money_test.gd`'s own R1.1 checks against the same
## `rust_scrip`/`celloutz` pair; this covers what AL adds on top of it: a
## lien that names one real carried item rather than an abstract debt
## number, and a default that actually takes the named thing rather than
## inventing a second penalty for not paying.

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
	WorldHistory.world_minute = 0.0
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("celloutz", {"name": "CellOutz", "kind": "faction", "doctrine": "Ownership, downward."})
	WorldHistory.register_subject("choir_of_marrow", {"name": "Choir of Marrow", "kind": "faction"})

	var carry := Carry.new()
	carry.take_chunk({"layer_name": "organ", "organ_id": "liver", "condition": 1.0})

	print("AL1.2 - the bank does not lend against nothing")
	var missing := carry.borrow_against(40, "choir_of_marrow", 5)
	check(not bool(missing.get("ok", false)), "an item index that does not exist refuses the loan entirely")
	check(carry.debt_to("choir_of_marrow") == 0, "...and writes no debt when it does")

	var loaned := carry.borrow_against(40, "choir_of_marrow", 0)
	check(bool(loaned.get("ok", false)), "borrowing against a real, named item succeeds")
	check(carry.debt_to("choir_of_marrow") == 40, "and the debt is real, same ledger `borrow()` already writes")
	var liened_item: Dictionary = carry.items[0]
	check(str(liened_item.get("lien", "")).contains("CHOIR OF MARROW"), "the lien names the actual lender, found on the item itself (%s)" % str(liened_item.get("lien", "")))
	check(str(liened_item.get("lien_holder", "")) == "choir_of_marrow", "and records who actually holds it")

	print("AL1.6 - the institution incriminates itself in its own paperwork")
	var statement := carry.account_statement("choir_of_marrow")
	check(bool(statement.get("ok", false)) and str(statement.get("office", "")).contains("CHOIR OF MARROW"), "the statement names the office responsible")
	check(int(statement.get("owed", 0)) == 40 and is_equal_approx(float(statement.get("rate_per_day", 0.0)), Carry.DEBT_INTEREST_RATE_PER_DAY), "the paperwork prints the real balance and real rate")
	check((statement.get("security", []) as Array).has("LIVER"), "the exact collateral is named in the statement")
	var clauses := " ".join(statement.get("clauses", []))
	check(clauses.contains("THE OFFICE") and clauses.contains("ACCOUNT HOLDER"), "the copy targets the office and its procedure, not a caricature of the borrower")

	print("AL1.3 - default takes the named thing, not an invented penalty")
	var nothing_to_seize := carry.seize_lien("vanity_row")
	check(not bool(nothing_to_seize.get("ok", false)), "a lender with no lien on anything gets nothing")
	check(carry.items.size() == 1, "...and the item is untouched")

	var before_count := carry.items.size()
	var seized := carry.seize_lien("choir_of_marrow")
	check(bool(seized.get("ok", false)), "the actual lienholder can take the named item")
	check(carry.items.size() == before_count - 1, "and it is genuinely gone from CARRY, not just marked")
	check(int(seized.get("value", -1)) > 0, "valued at something real, the same pricing the Choir sells by")
	check(carry.debt_to("choir_of_marrow") < 40, "and the debt actually shrinks by what the thing was worth")

	var second_seize := carry.seize_lien("choir_of_marrow")
	check(not bool(second_seize.get("ok", false)), "seizing again with nothing left liened is refused, not a phantom repeat")

	print("AL1.5 - the clock keeps the account when the bank is not loaded")
	WorldHistory.clear_history()
	WorldHistory.world_minute = 0.0
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("celloutz", {"name": "CellOutz", "kind": "faction", "doctrine": "Ownership, downward."})
	WorldHistory.register_subject("choir_of_marrow", {"name": "Choir of Marrow", "kind": "faction"})
	var first_account := Carry.new()
	check(bool(first_account.borrow(100, "choir_of_marrow").get("ok", false)), "a 100 scrip account opens against the real lender")
	WorldClock.pass_time(23.0)
	check(first_account.debt_to("choir_of_marrow") == 100, "twenty-three hours does not round itself into a day")
	WorldClock.pass_time(1.0)
	check(first_account.debt_to("choir_of_marrow") == 103, "one whole in-world day accrues the stated three percent (100 -> 103)")
	check(WorldHistory.event_count("bank_interest_accrued") == 1, "the charge is written once into world history")
	WorldClock.pass_time(48.0)
	var reopened_account := Carry.new()
	check(reopened_account.debt_to("choir_of_marrow") == 109, "two unattended days catch up on a fresh Carry instance (103 -> 109)")
	var interest_events := WorldHistory.recent_events(1)
	check(not interest_events.is_empty() and int((interest_events[0].details as Dictionary).get("days", 0)) == 2,
		"the receipt names the two days it charged rather than hiding a magic total")

	print("AL1.5 - an old save starts now; it is not retroactively punished")
	WorldHistory.clear_history()
	WorldHistory.world_minute = WorldClock.MINUTES_PER_DAY * 90.0
	WorldHistory.register_subject("inventory", {"items": [], "rust_scrip": 0, "player_debt": {"choir_of_marrow": 50}})
	var old_save_account := Carry.new()
	check(old_save_account.debt_to("choir_of_marrow") == 50, "a pre-interest save keeps its exact recorded debt on first read")
	check(bool(WorldHistory.subject("inventory").get("player_debt_at_minute", {}).has("choir_of_marrow")), "and receives a migration-safe clock anchor")
	WorldClock.pass_time(24.0)
	check(old_save_account.debt_to("choir_of_marrow") == 52, "interest begins only after that honest migration point")

	print("AL1.7 - default sends a named person, not an invisible debit")
	WorldHistory.clear_history()
	WorldHistory.world_minute = 0.0
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("choir_of_marrow", {"name": "Choir of Marrow", "kind": "faction"})
	var defaulted := Carry.new()
	defaulted.take_chunk({"layer_name": "organ", "organ_id": "liver", "condition": 1.0})
	check(bool(defaulted.borrow_against(40, "choir_of_marrow", 0).get("ok", false)), "the default has real collateral for a collector to visit")
	var visit := defaulted.send_collector("choir_of_marrow")
	var collector_id := str(visit.get("collector_id", ""))
	var collector := WorldHistory.subject(collector_id)
	check(bool(visit.get("ok", false)) and not collector_id.is_empty(), "a default records the person who came to collect")
	check(str(collector.get("kind", "")) == "person" and str(collector.get("body_kind", "")) == "BaselineHuman", "the collector is a person with a real body type")
	var collector_anatomy: Dictionary = collector.get("anatomy_state", {})
	check(not (collector_anatomy.get("zones", {}) as Dictionary).is_empty(), "the collector body carries the normal anatomy snapshot")
	check(WorldHistory.event_count("debt_collector_visited") == 1, "the visit is part of world history")

	print("BANK_LIEN_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
