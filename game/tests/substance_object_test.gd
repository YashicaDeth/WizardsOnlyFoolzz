extends Node

## AU1.2. "A drug is an object — a baggie, a blister, a tab, a weight. It
## goes in CARRY, the Choir prices it, it can be stolen off a body."

const CARRY := preload("res://systems/carry.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})

	print("AU1.2 - a drug is a real object, not a generic 'substance' kind")
	var bag: Carry = CARRY.new()
	var taken := bag.take_substance("marrow_dust")
	_check(not taken.is_empty(), "taking a real substance actually adds it")
	_check(str(taken.get("form", "")) == "baggie", "it carries its own physical form")
	_check(str(taken.get("label", "")).contains("BAGGIE"), "which shows in the label a player actually reads (%s)" % str(taken.label))
	_check(bag.items.has(taken), "and it is really in CARRY, not a side record")

	print("AU1.2 - the Choir prices it")
	# Isolates the one thing this item actually changed - appetite - rather
	# than the full sale_value() pipeline, which also folds in the player's
	# own standing with the Choir and can mask the appetite entirely for a
	# fresh subject with no history against them.
	var choir_appetite: float = bag._appetite("choir_of_marrow", "substance")
	var anonymous_appetite: float = bag._appetite("", "substance")
	_check(choir_appetite > anonymous_appetite, "the Choir has a real, higher appetite for it than an anonymous broker (%.2f > %.2f)" % [choir_appetite, anonymous_appetite])
	_check(choir_appetite > 1.0, "and it is genuinely above the neutral baseline every unlisted buyer gets (%.2f)" % choir_appetite)

	print("AU1.2 - it can be stolen off a body")
	WorldHistory.register_subject("mara_voss", {"name": "Mara Voss", "kind": "person", "carried_substance": "choir_bloom"})
	var stolen := bag.take_from_subject("mara_voss")
	_check(not stolen.is_empty(), "a subject actually carrying a substance yields it")
	_check(bool(stolen.get("stolen", false)), "and it is marked stolen, the same as a robbed organ")
	var second_attempt := bag.take_from_subject("mara_voss")
	_check(second_attempt.is_empty(), "it cannot be lifted a second time off the same body")
	_check(str(WorldHistory.subject("mara_voss").get("carried_substance", "MISSING")) == "", "the body's own record is cleared, not merely copied")

	print("AU1.2 - a stolen drug is worth less, the same rule as a robbed organ")
	var clean := bag.take_substance("marrow_dust")
	var clean_price := bag.sale_value(clean, "choir_of_marrow")
	var stolen_price := bag.sale_value(stolen, "choir_of_marrow")
	_check(stolen_price < clean_price, "the heat discount (B5.6) applies here too, not a second rule for drugs (%d < %d)" % [stolen_price, clean_price])

	print("SUBSTANCE_OBJECT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
