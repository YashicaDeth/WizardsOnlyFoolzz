extends Node

## AX4.5. Greg, 24 September: death in the opening is rebirth in a vat, and
## the last filed body comes back with you so a death costs no time.

const SHEET := preload("res://systems/character_sheet.gd")

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

	check(OpeningDeath.FICTION_AUTHORED, "the death fiction is authored")
	check(OpeningDeath.consume_pending().is_empty(), "a fresh world has no pending rebirth")

	# A death before anything was filed still grows a body, just not a saved one.
	var early := OpeningDeath.handle("drowned in the tank")
	check(bool(early.ok) and str(early.kind) == "rebirth", "dying resolves as rebirth")
	check(str(early.scene) == "res://vat_chamber.tscn", "and rebirth happens in the vat")
	check(str(early.preset).is_empty(), "with no preset when nothing was ever filed")
	OpeningDeath.consume_pending()

	# The filed body is saved to the rebirth slot and handed back on death.
	var filed := SHEET.new()
	filed.randomise()
	check(bool(CharacterPresets.save(CharacterPresets.LAST_BODY, filed).ok), "the filed body is saved")
	var before: int = WorldHistory.events.size()
	var death := OpeningDeath.handle("bled out in the corridor")
	check(str(death.preset) == CharacterPresets.LAST_BODY, "death names the saved body to grow back")
	check(int(death.count) == 2, "and counts the rebirths (%d)" % int(death.count))
	check(WorldHistory.events.size() > before, "the world records that it happened")
	check(RunLifecycle.death_history().is_empty(), "rebirth is not filed as a permanent death")

	var pending := OpeningDeath.consume_pending()
	check(str(pending.get("preset", "")) == CharacterPresets.LAST_BODY, "the vat picks the pending rebirth up")
	check(OpeningDeath.consume_pending().is_empty(), "exactly once")

	var regrown := SHEET.new()
	CharacterPresets.apply(str(pending.preset), regrown)
	check(regrown.race == filed.race and regrown.traits == filed.traits, "the reborn body is the one that was filed")

	# Rebirth is authored; respawn, clone and backup are still not.
	check(OpeningDeath.counterfeits_in(str(death)).is_empty(), "the payload claims nothing beyond the authored fiction")
	check(OpeningDeath.counterfeits_in("you respawn from a clone backup").size() >= 3, "the detector still catches what is not decided")
	check(OpeningDeath.counterfeits_in("the corridor is quiet").is_empty(), "and does not cry wolf")

	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
