extends Node

## C8.2 / AS3.2. "Pockets are real, and what is in them is in them." Not a
## second inventory - the same real carried items, marked which of them are
## on the body rather than in the bag. Small, few, and refused rather than
## silently dropped when something does not actually fit one.

var failures: Array[String] = []


func check(condition: bool, what: String) -> void:
	print("PASS " if condition else "FAIL ", what)
	if not condition:
		failures.append(what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var carry := Carry.new()

	print("C8.2 - a small, real thing pockets cleanly")
	carry.take_substance("marrow_dust")
	check(carry.pocketed_items().is_empty(), "nothing starts pocketed just by being carried")
	var pocketed := carry.pocket(0)
	check(bool(pocketed.get("ok", false)), "a light item pockets")
	check(carry.pocketed_items().size() == 1, "and shows up in the pocketed set")
	check(bool((carry.items[0] as Dictionary).get("pocketed", false)), "the item itself carries the real flag, not a side table")

	print("C8.2 - a severed limb does not go in a pocket")
	carry.take_chunk({"layer_name": "limb", "whole_limb": true, "zone": "left_arm", "condition": 1.0})
	var limb_index := carry.first_index("limb")
	var refused := carry.pocket(limb_index)
	check(not bool(refused.get("ok", false)), "too big for a pocket is refused, not silently truncated")
	check(str(refused.get("reason", "")) == "TOO BIG FOR A POCKET", "and says why")

	print("C8.2 - pockets have a real, small capacity")
	carry.take_substance("choir_bloom")
	carry.take_substance("static_hymn")
	# Fill to the cap with whatever small things remain unpocketed.
	for index in carry.items.size():
		if carry.pocketed_items().size() >= Carry.POCKET_CAPACITY:
			break
		carry.pocket(index)
	check(carry.pocketed_items().size() == Carry.POCKET_CAPACITY, "capacity actually fills at the stated number (%d)" % carry.pocketed_items().size())
	carry.take_substance("marrow_dust")
	var overflow := carry.pocket(carry.items.size() - 1)
	check(not bool(overflow.get("ok", false)) and str(overflow.get("reason", "")) == "POCKETS ARE FULL", "a full set of pockets refuses a fourth, rather than growing silently")

	print("C8.2 - unpocketing is real and reversible")
	var some_pocketed_index := -1
	for index in carry.items.size():
		if bool((carry.items[index] as Dictionary).get("pocketed", false)):
			some_pocketed_index = index
			break
	var unpocketed := carry.unpocket(some_pocketed_index)
	check(bool(unpocketed.get("ok", false)), "moving it back to the bag succeeds")
	check(carry.pocketed_items().size() == Carry.POCKET_CAPACITY - 1, "and the pocketed count actually drops")
	check(not bool(carry.unpocket(some_pocketed_index).get("ok", false)), "unpocketing something already in the bag is refused, not a no-op success")

	print("C8.2 - a search only ever finds what is actually pocketed")
	var found := carry.search_pockets()
	check(found.size() == carry.pocketed_items().size(), "search_pockets() is the same honest set, not a second answer")
	for entry in found:
		check(bool((entry as Dictionary).get("pocketed", false)), "everything a search turns up is genuinely pocketed")

	print("POCKETS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
