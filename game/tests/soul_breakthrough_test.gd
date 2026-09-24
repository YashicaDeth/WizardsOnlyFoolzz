extends Node

## AX2.2/AX2.3. The breakthrough, checked against the direction doc. The claim
## that matters most is the last block: no third party is ever credited.

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

	# Submission is not a breakthrough, however much it hurt.
	check(not SoulBreakthrough.awakened(20, 0), "enduring everything and refusing nothing never awakens it")
	check(not SoulBreakthrough.awakened(100, 0), "and no amount of suffering alone changes that")
	check(SoulBreakthrough.ember(20, 0) > 0.0, "the suffering still accumulated - it just did not light")

	# Refusal is what lights it.
	check(SoulBreakthrough.awakened(4, 2), "suffering plus refusal awakens it (4 cycles, 2 refusals)")
	check(not SoulBreakthrough.awakened(1, 1), "a little of each is not enough")

	# Nothing to take.
	var nothing := SoulBreakthrough.seize("player", 4, 2)
	check(not bool(nothing.ok), "seizing with no chip in the head fails")
	check(str(nothing.reason) == "NOTHING IN THE HEAD TO TAKE", "and says why (%s)" % nothing.reason)

	WorldHistory.register_subject("player", {"kind": "person"})
	var installed := BrainIndex.install_chip("player", "celloutz", "the_facility")
	check(bool(installed.ok), "the government installs a chip the player did not ask for")
	var serial_before := str(BrainIndex.chip("player").get("serial", ""))

	# Not awake yet: the chip stays theirs.
	var early := SoulBreakthrough.seize("player", 20, 0)
	check(not bool(early.ok), "a player who never refused cannot take it")
	check(str(BrainIndex.chip("player").get("owner_faction", "")) == "celloutz", "and it still answers to them")

	var before_chaos: float = WorldHistory.chaos_magick()
	var taken := SoulBreakthrough.seize("player", 4, 2)
	check(bool(taken.ok), "an awakened player takes it")
	check(str(taken.was) == "celloutz", "it was the government's")
	check(str(taken.now) == "self", "and now it answers to the player")
	var chip: Dictionary = BrainIndex.chip("player")
	check(str(chip.get("owner_faction", "")) == "self", "the record itself changed owner")
	check(str(chip.get("serial", "")) == serial_before, "same serial - it is the same hardware, not a new device")
	check(not bool(chip.get("revoked", true)), "and it is not revoked; it works, for you")

	# The doc's hardest line: no separate entity granted this.
	var credited := str(chip.get("seized_by", ""))
	check(credited == "player", "the seizure credits the player (%s)" % credited)
	var text := str(chip)
	for outsider in ["demon", "entity", "visitor", "patron", "god", "stranger"]:
		check(not text.to_lower().contains(outsider), "no %s is named anywhere in the record" % outsider)

	check(WorldHistory.chaos_magick() > before_chaos, "chaos magick rose when the implant was rewritten")
	check(SoulBreakthrough.seize("player", 9, 9).ok == false, "it cannot be taken twice")

	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
