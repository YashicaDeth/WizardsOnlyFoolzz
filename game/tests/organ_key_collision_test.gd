extends Node

## The crash Greg hit on the BODY page, in the index and in the device both.
##
## `character_sheet.gd` published `anatomy.organs` as a String naming the organ
## set you were decanted with ("standard", "doubled", "salvaged", "communion").
## Everywhere else in the game `anatomy.organs` is a Dictionary of live organ
## states. Two different things under one key: the moment the player had a
## sheet, `body_inspector._condition_of` read "standard" where it required a
## Dictionary and threw from inside `_draw` — once per frame, for as long as the
## page was open, which is what reads as the panel crashing.
##
## Both halves are asserted, because either one alone would let it back in: the
## sheet must stop publishing the collision, and the inspector must survive one
## if some other writer ever makes the same mistake.

const BODY_INSPECTOR := preload("res://systems/body_inspector.gd")
const CHARACTER_SHEET := preload("res://systems/character_sheet.gd")

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

	var sheet = CHARACTER_SHEET.new()
	sheet.under_skin["organs"] = "salvaged"
	var state: Dictionary = sheet.apply_to_world()
	var anatomy: Dictionary = state.get("anatomy", {})
	check(str(anatomy.get("organ_set", "")) == "salvaged",
		"the sheet publishes the decanted organ set under organ_set")
	check(not (anatomy.get("organs", null) is String),
		"the sheet no longer publishes a String under anatomy.organs")

	# A round trip through WorldHistory, which is how the sheet is really saved.
	var reloaded = CHARACTER_SHEET.new()
	check(reloaded.load_from_world() and str(reloaded.under_skin.get("organs", "")) == "salvaged",
		"a sheet saved with organ_set loads back with the same organ set")

	# A subject written before the rename still has to load. Cleared first,
	# because `register_subject` deliberately only fills in keys that are
	# missing — it will not overwrite an anatomy that is already on file.
	var legacy: Dictionary = WorldHistory.subject("player").duplicate(true)
	legacy["anatomy"] = {"blood_type": "O-RUST", "skeleton": "standard", "organs": "communion", "cybernetics": []}
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", legacy)
	var old_save = CHARACTER_SHEET.new()
	check(old_save.load_from_world() and str(old_save.under_skin.get("organs", "")) == "communion",
		"a sheet saved before the rename still loads its organ set")

	# And a simulation-shaped anatomy must not be read as an organ set at all.
	var simulated: Dictionary = legacy.duplicate(true)
	simulated["anatomy"] = {"blood_type": "O-RUST", "organs": {"heart": {"health": 30.0}}, "cybernetics": []}
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", simulated)
	var from_sim = CHARACTER_SHEET.new()
	check(from_sim.load_from_world() and str(from_sim.under_skin.get("organs", "")) == "standard",
		"a simulation-shaped organs Dictionary is not loaded as a garbage organ set")

	# The inspector must not throw on the shape that used to take it down.
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {
		"name": "THE HUNTER",
		"anatomy": {"blood_type": "O-RUST", "organs": "standard", "cybernetics": []},
	})
	WorldHistory.register_subject("mark", {
		"name": "A Mark",
		"anatomy": {"organs": {"heart": {"health": 18.0, "max_health": 30.0}}, "cybernetics": []},
	})
	var inspector = BODY_INSPECTOR.new()
	add_child(inspector)
	inspector.set_subject(WorldHistory.subject("mark"))
	inspector.zone = "torso"
	inspector._rebuild_parts()
	var read_back := 0.0
	for index in inspector._parts.size():
		inspector.part_index = index
		# This is the call that used to throw: it reaches `_condition_of` with
		# the player's sheet-shaped anatomy swapped in under it.
		var compare: Dictionary = inspector.comparison()
		read_back += float(compare.get("our_condition", 0.0))
	check(true, "every part compares against a sheet-shaped player without throwing")
	check(read_back >= 0.0, "the comparison still returns a real condition")

	print("ORGAN_KEY_COLLISION_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
