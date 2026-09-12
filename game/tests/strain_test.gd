extends Node

## AU1.3. "Strains differ. Two mushrooms are not one item with a number."

const SUBSTANCES := preload("res://systems/substances.gd")
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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person", "anatomy_state": {"blood": 5000.0, "blood_capacity": 5000.0}})

	print("AU1.3 - a strain is deterministic, the same guarantee a seal makes")
	var first := SUBSTANCES.roll_strain("marrow_dust", 42)
	var replay := SUBSTANCES.roll_strain("marrow_dust", 42)
	_check(first.strain == replay.strain and is_equal_approx(first.potency, replay.potency), "the same seed rolls the same strain and potency twice")

	print("AU1.3 - two mushrooms are not one item with a number")
	var strains: Array = []
	for seed_value in range(20):
		strains.append(str(SUBSTANCES.roll_strain("marrow_dust", seed_value).strain))
	var unique: Array = []
	for s: String in strains:
		if not unique.has(s):
			unique.append(s)
	_check(unique.size() > 1, "different pickups genuinely roll different named strains (%d distinct across 20 rolls)" % unique.size())

	print("AU1.3 - a real item in CARRY carries its own strain")
	var bag: Carry = CARRY.new()
	var taken := bag.take_substance("marrow_dust")
	_check(not str(taken.get("strain", "")).is_empty(), "the item itself remembers which strain it actually is")
	_check(str(taken.get("label", "")).contains(str(taken.strain)), "and it shows in the label, not only in a hidden field")
	_check(float(taken.get("potency", 0.0)) > 0.0, "and it carries a real potency, not a flat 1.0 for everything")

	print("AU1.3 - potency changes what the same substance actually does to you")
	WorldHistory.amend_subject("player", {"anatomy_state": {"pain": 60.0, "consciousness": 100.0, "blood": 5000.0, "blood_capacity": 5000.0}})
	var weak := SUBSTANCES.take("player", "marrow_dust", 0.6)
	WorldHistory.amend_subject("player", {"anatomy_state": {"pain": 60.0, "consciousness": 100.0, "blood": 5000.0, "blood_capacity": 5000.0}})
	var strong := SUBSTANCES.take("player", "marrow_dust", 1.4)
	_check(bool(weak.get("ok", false)) and bool(strong.get("ok", false)), "both a weak and a strong dose actually go through")
	var weak_relief := 60.0 - float(weak.get("pain_after", 60.0))
	var strong_relief := 60.0 - float(strong.get("pain_after", 60.0))
	_check(strong_relief > weak_relief, "a strong batch does more for the same catalogue price than a weak one (%.1f > %.1f)" % [strong_relief, weak_relief])

	print("STRAIN_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
