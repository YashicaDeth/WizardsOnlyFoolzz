extends Node

## AX1.3/AX1.5. The load-bearing test is the round trip: a preset that quietly
## loses a field sends a repeat player back into the chart to re-enter their
## birth time, and they will never work out why their chart is wrong.

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

	check(CharacterPresets.names().is_empty(), "a new world has no presets")
	check(not bool(CharacterPresets.apply("anything", SHEET.new()).ok), "applying a preset that does not exist fails cleanly")

	# A player who made every choice the examination offers.
	var made = SHEET.new()
	made.race = "roadborn"
	made.anatomy_sex = "intersex"
	made.display_name = "SOMEBODY ELSE"
	made.birth = {"year": 1991, "month": 7, "day": 3, "hour": 19, "minute": 45}
	made.appearance = {"face": 0.31, "build": 0.77, "wear": 0.9, "mutation": 0.4, "ink": 0.2, "piercings": 0.6}
	made.under_skin = {"skeleton": "plated", "organs": "salvaged", "blood": "SAP", "grown_with": ["a second heart"]}
	made.toggle_trait("clerical_error")
	made.modifiers = ["neuralace"]
	made.instrument = {"answers": [1, 4, 2]}

	check(not bool(CharacterPresets.save("", made).ok), "a preset needs a name")
	var saved := CharacterPresets.save("  THE ROADBORN  ", made)
	check(bool(saved.ok), "the build saves")
	check(str(saved.name) == "THE ROADBORN", "and its name is trimmed")
	check(CharacterPresets.names().has("THE ROADBORN"), "and it is listed")

	# The round trip, field by field, on a fresh sheet.
	var fresh = SHEET.new()
	var applied := CharacterPresets.apply("THE ROADBORN", fresh)
	check(bool(applied.ok), "a repeat player applies it in one action")
	check(fresh.race == "roadborn", "race came back")
	check(fresh.anatomy_sex == "intersex", "anatomy came back")
	check(fresh.display_name == "SOMEBODY ELSE", "the name came back")
	check(int(fresh.birth.get("hour", -1)) == 19 and int(fresh.birth.get("minute", -1)) == 45, "the birth TIME came back, so the chart is the same chart")
	check(int(fresh.birth.get("year", -1)) == 1991, "and the birth year")
	check(is_equal_approx(float(fresh.appearance.get("face", 0.0)), 0.31), "the face setting came back")
	check(str(fresh.under_skin.get("blood", "")) == "SAP", "the blood came back")
	check((fresh.under_skin.get("grown_with", []) as Array).has("a second heart"), "and what it was grown with")
	check(fresh.traits.has("clerical_error"), "the traits came back")
	check((fresh.modifiers as Array).has("neuralace"), "the modifiers came back")
	check(not (fresh.instrument as Dictionary).is_empty(), "the personality instrument came back")

	# Editing the restored sheet must not reach back into the stored preset.
	fresh.race = "decanted"
	var again = SHEET.new()
	CharacterPresets.apply("THE ROADBORN", again)
	check(again.race == "roadborn", "the stored preset is a copy, not a live reference")

	# The guard that outlives everyone here.
	var gaps := CharacterPresets.missing_fields(SHEET.new())
	check(gaps.is_empty(), "no chosen field is missing from SAVED_FIELDS (missing: %s)" % str(gaps))

	check(bool(CharacterPresets.save("THE ROADBORN", made).ok), "saving over a slot is allowed")
	check(CharacterPresets.names().size() == 1, "and refining a build does not leave eleven near-misses")

	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
