extends Node

## E2.3 stays a catalogue boundary. These assertions deliberately test the
## data that a later presentation can consume without starting rituals, changing
## alignment, or borrowing Goetic ranks/correspondences.

const AshbloomSealCatalogue := preload("res://systems/ashbloom_seals.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var seals := AshbloomSealCatalogue.all()
	check(seals.size() == 10, "the Ashbloom catalogue has ten authored marks")
	check(AshbloomSeals.all().size() == seals.size(), "the catalogue registers as a reusable world system")
	var expected_origins := PackedStringArray(["choir_of_marrow", "soft_rot", "reset", "gate_lanterns", "wizardsonlyfoolz"])
	var origins: Dictionary = {}
	var marks: Dictionary = {}
	for seal in seals:
		var seal_id := str(seal.get("id", ""))
		var origin_id := str(seal.get("origin_id", ""))
		var strokes: Array = seal.get("strokes", [])
		check(not seal_id.is_empty() and not str(seal.get("label", "")).is_empty(), "%s is named for this world" % seal_id)
		check(expected_origins.has(origin_id), "%s names an Ashbloom origin" % seal_id)
		check(not seal.has("rank") and not seal.has("effect"), "%s carries no borrowed hierarchy or invented mechanic" % seal_id)
		check(not strokes.is_empty(), "%s has a drawable mark" % seal_id)
		check(str(strokes) == str(AshbloomSealCatalogue.strokes_for(seal_id)), "%s remains stable" % seal_id)
		origins[origin_id] = int(origins.get(origin_id, 0)) + 1
		marks[str(strokes)] = true
		var polylines_are_valid := true
		var points_are_in_grid := true
		for stroke in strokes:
			polylines_are_valid = polylines_are_valid and stroke is Array and (stroke as Array).size() >= 2
			if not stroke is Array:
				continue
			for point in stroke as Array:
				var point_is_valid := point is Array and (point as Array).size() >= 2
				if point_is_valid:
					point_is_valid = absf(float((point as Array)[0])) <= 1.0 and absf(float((point as Array)[1])) <= 1.0
				points_are_in_grid = points_are_in_grid and point_is_valid
		check(polylines_are_valid, "%s uses real polyline strokes" % seal_id)
		check(points_are_in_grid, "%s stays inside the renderer's centred grid" % seal_id)
	check(marks.size() == seals.size(), "every Ashbloom origin gets a distinct mark")
	for origin_id in expected_origins:
		check(int(origins.get(origin_id, 0)) == 2, "%s contributes a pair of original marks" % origin_id)
	check(AshbloomSealCatalogue.find("not_a_seal").is_empty(), "unknown marks never invent a fallback")
	check(AshbloomSealCatalogue.from_origin("soft_rot").size() == 2, "origins can be displayed without ritual coupling")
	var mutable_copy := AshbloomSealCatalogue.find("marrow_saint")
	mutable_copy["label"] = "TAMPERED"
	(mutable_copy.get("strokes", []) as Array)[0][0][0] = 99.0
	var canonical := AshbloomSealCatalogue.find("marrow_saint")
	check(str(canonical.get("label", "")) == "MARROW SAINT", "a caller cannot mutate the canonical name")
	check(float((canonical.get("strokes", []) as Array)[0][0][0]) != 99.0, "a caller cannot mutate the canonical stroke path")
	print("ASHBLOOM_SEALS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
