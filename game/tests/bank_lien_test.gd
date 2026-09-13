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

	print("BANK_LIEN_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
