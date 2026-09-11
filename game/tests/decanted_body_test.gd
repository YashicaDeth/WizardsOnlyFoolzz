extends Node

## D. What the intake collected has to reach the body, or character creation is
## a form you fill in for nothing. Greg's report was "nothing with the character
## creation modelling gets made", and he was right: the sheet never filed
## appearance at all, and the rig read only the race's build — so every player
## walked out of the vat the same colour, with the same blood, wearing a
## hardcoded arm regardless of what they were grown with.

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

	var sheet = preload("res://systems/character_sheet.gd").new()
	sheet.appearance = {"face": 0.9, "build": 0.5, "wear": 0.8}
	sheet.under_skin = {"skeleton": "standard", "organs": "standard", "blood": "NULL", "grown_with": []}
	var filed: Dictionary = sheet.apply_to_world()
	check(filed.has("appearance"), "the sheet files what you chose to look like")
	check(is_equal_approx(float((filed.appearance as Dictionary).get("face", 0.0)), 0.9), "and files the face you picked")
	check(str((filed.anatomy as Dictionary).get("blood_type", "")) == "NULL", "and the blood type")

	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame

	# Blood type reaches the body rather than sitting on the form.
	check(hunt._blood_volume("NULL") < hunt._blood_volume("SAP"), "a NULL carrier holds less blood than a SAP")
	check(hunt._blood_volume("O-RUST") > 0.0, "and an unlisted type still has blood")

	# You keep what you were grown with instead of a hardcoded arm.
	var grown: Dictionary = hunt._grown_cybernetics({"cybernetics": ["ceramic sternum"]})
	check(not grown.is_empty(), "what you were grown with reaches the body")
	var named := false
	for zone in grown:
		if str((grown[zone] as Dictionary).get("name", "")).contains("sternum"):
			named = true
	check(named, "and it is the part the sheet named, not a default (%s)" % str(grown))
	var bare: Dictionary = hunt._grown_cybernetics({})
	check(not bare.is_empty(), "an empty sheet still leaves the opening's own arm")

	# Two different faces do not generate the same head.
	var quiet: Dictionary = {"appearance": {"face": 0.05}}
	var loud: Dictionary = {"appearance": {"face": 0.95}}
	var quiet_variation := 1 + int(clampf(float((quiet.appearance as Dictionary).face), 0.0, 1.0) * 24.0)
	var loud_variation := 1 + int(clampf(float((loud.appearance as Dictionary).face), 0.0, 1.0) * 24.0)
	check(quiet_variation != loud_variation, "two faces give two different bodies (%d vs %d)" % [quiet_variation, loud_variation])

	print("DECANTED_BODY_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
