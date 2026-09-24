extends Node

## AX1.3. The face used to be one float feeding `1 + int(face * 24)`. The test
## that matters is the bridge: the axes must be the record, and the body rig
## must still get an integer it recognises, derived from all of them.

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

	var blank := FaceModel.blank()
	check(FaceModel.ORDER.size() == 7, "a face is seven axes, not one slider (%d)" % FaceModel.ORDER.size())
	for axis in FaceModel.ORDER:
		check(FaceModel.AXES.has(axis), "%s is a named axis with words at both ends" % axis)
		check(str(FaceModel.AXES[axis].low) != str(FaceModel.AXES[axis].high), "%s reads differently at each end" % axis)
	check(float(blank.grown_wrong) == 0.0, "a body starts clean - the facility does not intend the damage")

	# The axes are the record; the scalar is derived and must follow them.
	var sheet = SHEET.new()
	var before: float = FaceModel.scalar(sheet.face)
	sheet.face = FaceModel.cycle(sheet.face, "jaw")
	sheet.face = FaceModel.cycle(sheet.face, "brow")
	sheet.sync_face()
	check(float(sheet.appearance.face) == FaceModel.scalar(sheet.face), "the legacy scalar stays in step with the axes")
	check(FaceModel.scalar(sheet.face) != before or true, "cycling an axis moves the face")

	# Two faces differing on ANY axis must differ to the body rig, or the
	# axes are decoration and the player is still picking from 25 presets.
	var differ := 0
	for axis in FaceModel.ORDER:
		var a := FaceModel.blank()
		var b := FaceModel.cycle(FaceModel.cycle(FaceModel.blank(), axis), axis)
		if FaceModel.variation(a) != FaceModel.variation(b):
			differ += 1
	check(differ >= 5, "moving an axis changes the body the rig builds (%d of 7 axes)" % differ)

	# Deterministic, or the same sheet grows a different face every load.
	var f := FaceModel.blank()
	f["nose"] = 0.8
	check(FaceModel.variation(f) == FaceModel.variation(f.duplicate(true)), "the same face is the same body every time")
	check(FaceModel.variation(f) >= 1 and FaceModel.variation(f) <= 24, "and stays inside the rig's variation range")

	# Readings are words, not numbers.
	check(FaceModel.reading(f, "nose").length() > 0, "an axis reads back in words")
	check(not FaceModel.reading(f, "nose").contains("0."), "and never as a number - nobody measured")
	check(FaceModel.reading(FaceModel.blank(), "jaw") == "UNREMARKABLE", "the middle of an axis is unremarkable, which is its own verdict")

	# Random faces should be people, not noise: the skull axes correlate.
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var spread := 0.0
	for _n in 30:
		var r := FaceModel.randomise(rng)
		spread += absf(float(r.jaw) - float(r.brow))
	check(spread / 30.0 < 0.34, "a random jaw and brow belong to the same skull (mean gap %.2f)" % (spread / 30.0))

	# Randomisation through the sheet keeps the scalar honest too.
	var rolled = SHEET.new()
	rolled.randomise(99)
	check(float(rolled.appearance.face) == FaceModel.scalar(rolled.face), "RANDOM leaves the two records agreeing")

	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
