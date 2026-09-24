extends Node

## AX4.5. The whole loop in the real scene: file a body, die, come back in the
## vat with the form already filed and the same body on the record.

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

	var first = load("res://vat_chamber.tscn").instantiate()
	add_child(first)
	check(first.intake != null, "a first decanting shows the intake form")
	first.intake.sheet.randomise()
	var race: String = first.intake.sheet.race
	first.intake._finish_filing()
	check(CharacterPresets.names().has(CharacterPresets.LAST_BODY), "filing saves the body for rebirth")
	check(first.phase == "submerged", "and the opening proceeds")

	first.anatomy.call("_die_or_fail", {"type": "test_death"})
	check(first.phase == "dead", "a death in the opening stops the scene")
	await get_tree().process_frame
	Interstitial.set_process(false)
	first.queue_free()
	await get_tree().process_frame

	var second = load("res://vat_chamber.tscn").instantiate()
	add_child(second)
	check(second.intake == null, "the reborn player skips the form")
	check(second.phase == "submerged", "and goes straight to waking")
	check(str(WorldHistory.subject("player").get("race", "")) == race, "in the body they filed (%s)" % race)
	check(str(WorldHistory.subject("player").get("examination_route", "")) == "preset:" + CharacterPresets.LAST_BODY, "and the record says it came from the saved preset")

	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
