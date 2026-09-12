extends Node

## The Mara Voss wipe. The property that matters is not that she is gone — it is
## that no second hardcoded name replaced her.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# ---- stable inside a save.
	WorldHistory.run_salt = 12345
	var first := CastNames.person("derby_captain")
	var again := CastNames.person("derby_captain")
	print("salt 12345 -> %s, %s, %s" % [first["name"], first["role"], first["faction"]])
	check(str(first["name"]) == str(again["name"]), "the same slot is the same person twice")
	check(str(first["id"]) == str(again["id"]), "and the same id")

	# ---- different between saves.
	var seen := {}
	for salt in [12345, 777, 90210, 5150, 4409, 1, 2, 3]:
		WorldHistory.run_salt = salt
		var who := CastNames.person("derby_captain")
		seen[str(who["name"])] = true
		print("  salt %-6d -> %-22s %s" % [salt, who["name"], who["role"]])
	print("distinct captains across eight saves: %d" % seen.size())
	check(seen.size() >= 6, "eight different saves give at least six different captains")

	# ---- two slots are not siblings.
	WorldHistory.run_salt = 12345
	var captain := CastNames.person("derby_captain")
	var other := CastNames.person("derby_captain_2")
	check(str(captain["name"]) != str(other["name"]), "adjacent slot names are not adjacent people")

	# ---- and nothing anywhere still says her name.
	var offenders: Array = []
	for path in ["res://bone_yard_hunt.gd", "res://rift_derby.gd",
			"res://systems/world_index.gd", "res://systems/gothic_field_hud.gd",
			"res://systems/character_archive.gd", "res://systems/celloutz_hud.gd"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var body := file.get_as_text()
		if body.contains("Mara Voss") or body.contains("mara_voss") or body.contains("MARA VOSS"):
			offenders.append(path)
	print("files still naming her: ", offenders)
	check(offenders.is_empty(), "no game file names her any more")

	# ---- ensure() registers a real subject that the labels can read.
	WorldHistory.run_salt = 4409
	var made := CastNames.ensure("derby_captain", {"elo": 1180, "grudge": 0})
	var record: Dictionary = WorldHistory.subject(str(made["id"]))
	check(not record.is_empty(), "ensure registers the subject")
	check(str(record.get("name", "")) == str(made["name"]), "and the record carries the generated name")
	check(int(record.get("elo", 0)) == 1180, "and the extras passed with it")

	if failures.is_empty():
		print("cast names: generated")
		get_tree().quit(0)
	else:
		print("cast names FAILURES: ", failures)
		get_tree().quit(1)
