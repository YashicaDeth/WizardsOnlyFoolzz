extends Node

## AX4.5. The job of this suite is to keep a question open. It fails the day
## somebody answers it by accident.

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

	var before: int = WorldHistory.events.size()
	var death := OpeningDeath.handle("bled out in the corridor")
	check(bool(death.ok), "dying in the opening resolves")
	check(str(death.kind) == "reload", "and it resolves as an ordinary reload")
	check(bool(death.placeholder), "and it says out loud that it is a placeholder")

	# It must not explain itself.
	var payload := str(death)
	var counterfeits := OpeningDeath.counterfeits_in(payload)
	check(counterfeits.is_empty(), "the payload claims nothing about revival (%s)" % str(counterfeits))

	# It must not take a position in the world either.
	check(WorldHistory.events.size() == before, "and it records no event - a logged death is a death the world has a view on")
	check(RunLifecycle.death_history().is_empty(), "opening death is not filed as a permanent death")

	# The gap is held open by a flag that cannot be flipped quietly.
	check(not OpeningDeath.FICTION_AUTHORED, "the death fiction is still unauthored, and the code says so")
	check(OpeningDeath.COUNTERFEITS.size() >= 6, "and the shortcuts it refuses are enumerated (%d)" % OpeningDeath.COUNTERFEITS.size())

	# The detector has to actually work, or the guard above is decoration.
	check(OpeningDeath.counterfeits_in("you are reborn in a new vessel").size() >= 2, "the detector catches a counterfeit when it sees one")
	check(OpeningDeath.counterfeits_in("the corridor is quiet").is_empty(), "and does not cry wolf")

	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
