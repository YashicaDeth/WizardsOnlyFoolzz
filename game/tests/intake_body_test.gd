extends Node

## D7.4 v2. The mirror's wobble used to be four universal constants - every
## character lied the same way regardless of what was actually on the sheet.
## `_mirror_distortion()` now reads race (`build`) and skeleton (rigidity),
## so a plated or dense skeleton barely moves and a hollow one swims, and
## different races land on a different wobble phase.
##
## D8.5 v2. Declining a modifier used to leave no fact anywhere that told
## "chose the hard way" apart from "was never offered" - both looked
## identical once the intake scene ended. `apply_to_world()` now records
## which modifiers were declined, as a real WorldHistory event, the same
## register N2.2 already uses to acknowledge an overspent build.

const VAT_INTAKE := preload("res://systems/vat_intake.gd")
const SHEET := preload("res://systems/character_sheet.gd")
const BASELINE_HUMAN := preload("res://systems/baseline_human.gd")
const HUNTER_APPEARANCE := preload("res://systems/hunter_appearance.gd")

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

	print("D7.4 v2 - the mirror's lie fits the body on the sheet")
	var intake: Control = VAT_INTAKE.new()
	add_child(intake)
	await get_tree().process_frame

	print("INTAKE BODY - visible FACE and BODY rows change their own data")
	var brow_before := float(intake.sheet.face.get("brow", 0.5))
	intake.page = 3
	intake.row = 0
	intake._commit()
	check(not is_equal_approx(float(intake.sheet.face.get("brow", 0.5)), brow_before), "FACE/BROW changes the brow rather than an invisible body field")
	intake.page = 4
	check(intake._rows() == 9, "BODY exposes every one of its nine visible choices")
	var anatomy_before: String = str(intake.sheet.anatomy_sex)
	intake.row = 0
	intake._commit()
	check(intake.sheet.anatomy_sex != anatomy_before, "BODY/ANATOMY changes anatomy after the page split")
	var build_before := float(intake.sheet.appearance.get("build", 0.5))
	intake.row = 4
	intake._commit()
	check(not is_equal_approx(float(intake.sheet.appearance.get("build", 0.5)), build_before), "BODY/BUILD changes the build setting")
	var compact := BASELINE_HUMAN.config_from_subject({"race": "decanted", "appearance": {"build": 0.0}, "anatomy": {}})
	var heavy := BASELINE_HUMAN.config_from_subject({"race": "decanted", "appearance": {"build": 1.0}, "anatomy": {}})
	check(float(compact.get("build", 0.0)) < float(heavy.get("build", 0.0)), "the stored BUILD setting changes the eventual world rig")

	# AX1.4. ANATOMY was the last row on the form that changed nothing a player
	# could see: the sheet held it, the page drew it back, presets saved it, and
	# no renderer ever read it. The brief is explicit that a control which does
	# not change anything must be removed rather than pretended at, so this is
	# the check that keeps it earning its place on the page.
	var female := BASELINE_HUMAN.config_from_subject({"race": "decanted", "anatomy_sex": "female", "anatomy": {}})
	var male := BASELINE_HUMAN.config_from_subject({"race": "decanted", "anatomy_sex": "male", "anatomy": {}})
	var unformed := BASELINE_HUMAN.config_from_subject({"race": "decanted", "anatomy_sex": "unformed", "anatomy": {}})
	check(float(female.get("frame", -1.0)) < float(male.get("frame", -1.0)), "BODY/ANATOMY reaches the rig as a real frame value")
	check(is_equal_approx(float(unformed.get("frame", -1.0)), 0.5), "UNFORMED is the neutral silhouette, not a fifth invented shape")
	# AX1.3. The face axes reached the rig only as a material seed, so
	# `face_model_test`'s "moving an axis changes the body the rig builds" was
	# true of an integer and false of the head. Greg found it by playing:
	# "Brow, jaw, none of this actually changes." This checks the mesh.
	var faces := {}
	for axis_test in [["jaw_low", "jaw", 0.0], ["jaw_high", "jaw", 1.0], ["brow_low", "brow", 0.0], ["brow_high", "brow", 1.0], ["mouth_low", "mouth", 0.0], ["mouth_high", "mouth", 1.0]]:
		var label := str(axis_test[0])
		var axes := FaceModel.blank()
		axes[str(axis_test[1])] = float(axis_test[2])
		var subject := BASELINE_HUMAN.new()
		add_child(subject)
		subject.build("face_probe_" + label, {"gore": false})
		var look = HUNTER_APPEARANCE.new()
		subject.add_child(look)
		look.configure(subject, {"axes": axes})
		faces[label] = {
			"jaw": (look.details["Jaw_Line"] as MeshInstance3D).mesh.size,
			"brow": (look.details["Brow_Ridge"] as MeshInstance3D).mesh.size,
			"mouth": (look.details["Mouth_Upper"] as MeshInstance3D).mesh.size,
		}
		subject.queue_free()
	check(faces["jaw_low"].jaw.x < faces["jaw_high"].jaw.x, "a broad JAW builds a wider jaw than a narrow one (%.3f < %.3f)" % [faces["jaw_low"].jaw.x, faces["jaw_high"].jaw.x])
	check(faces["jaw_low"].mouth.x < faces["jaw_high"].mouth.x, "...and the mouth widens across it rather than floating free")
	check(faces["brow_low"].brow.y < faces["brow_high"].brow.y, "a heavy BROW builds a heavier ridge than a fine one (%.3f < %.3f)" % [faces["brow_low"].brow.y, faces["brow_high"].brow.y])
	check(is_equal_approx(faces["brow_low"].jaw.x, faces["brow_high"].jaw.x), "and moving BROW does not silently move the jaw as well")
	check(faces["mouth_low"].mouth.y < faces["mouth_high"].mouth.y, "a full MOUTH builds a fuller lip than a thin one (%.3f < %.3f)" % [faces["mouth_low"].mouth.y, faces["mouth_high"].mouth.y])

	var narrow := BASELINE_HUMAN.new()
	var broad := BASELINE_HUMAN.new()
	add_child(narrow)
	add_child(broad)
	narrow.build("anatomy_narrow", {"gore": false, "frame": 0.0})
	broad.build("anatomy_broad", {"gore": false, "frame": 1.0})
	var narrow_torso: Vector3 = (narrow._layout.torso as Dictionary).size
	var broad_torso: Vector3 = (broad._layout.torso as Dictionary).size
	var narrow_leg: Vector3 = (narrow._layout.left_leg as Dictionary).size
	var broad_leg: Vector3 = (broad._layout.left_leg as Dictionary).size
	check(narrow_torso.x < broad_torso.x, "a narrow frame builds narrower shoulders (%.3f < %.3f)" % [narrow_torso.x, broad_torso.x])
	check(narrow_leg.x > broad_leg.x, "...and wider hips on the same body (%.3f > %.3f)" % [narrow_leg.x, broad_leg.x])
	check(is_equal_approx(narrow_torso.y, broad_torso.y), "frame moves width only - it never changes how tall the body is")
	narrow.queue_free()
	broad.queue_free()

	intake.sheet.race = "roadborn"
	intake.sheet.under_skin["skeleton"] = "plated"
	var rigid: Dictionary = intake._mirror_distortion()

	intake.sheet.race = "unreset"
	intake.sheet.under_skin["skeleton"] = "hollow"
	var frail: Dictionary = intake._mirror_distortion()

	check(float(rigid.amplitude) < float(frail.amplitude), "a plated skeleton distorts less than a hollow one (%.4f < %.4f)" % [float(rigid.amplitude), float(frail.amplitude)])
	check(float(rigid.phase) != float(frail.phase), "different races land on a different wobble phase, not the same waveform")

	intake.sheet.race = "roadborn"
	intake.sheet.under_skin["skeleton"] = "standard"
	var same_race_a: Dictionary = intake._mirror_distortion()
	var same_race_b: Dictionary = intake._mirror_distortion()
	check(is_equal_approx(float(same_race_a.amplitude), float(same_race_b.amplitude)) and is_equal_approx(float(same_race_a.phase), float(same_race_b.phase)), "the same sheet lies the same way twice - this is not extra randomness")

	print("D8.5 v2 - declining a modifier is a fact the world keeps")
	WorldHistory.clear_history()
	var sheet: CharacterSheet = SHEET.new()
	sheet.display_name = "TEST SUBJECT"
	sheet.modifiers.append("neuralace")
	# mast_tithe and full_schedule left untouched: declined by omission,
	# which is the ordinary path D8.4 already calls the harder road.
	var state: Dictionary = sheet.apply_to_world()
	var declined: Array = state.get("declined_modifiers", [])
	check(declined.has("mast_tithe") and declined.has("full_schedule"), "the sheet itself records which modifiers were declined (%s)" % str(declined))
	check(not declined.has("neuralace"), "and does not count the one actually signed for")

	var found_event := false
	for event: Dictionary in WorldHistory.recent_events(10):
		if str(event.get("type", "")) == "modifiers_declined":
			var details: Dictionary = event.get("details", {})
			if str(details.get("subject", "")) == "player":
				found_event = true
	check(found_event, "and a real event names the player and what they declined, the same way N2.2 acknowledges an overspent build")

	# One face slider shapes one feature: the skin does not re-roll under it.
	var before_axes := {"appearance": {"name": "THE HUNTER", "face": 0.2, "axes": {"brow": 0.2, "jaw": 0.5}}}
	var after_axes := {"appearance": {"name": "THE HUNTER", "face": 0.8, "axes": {"brow": 0.9, "jaw": 0.5}}}
	check(BaselineHuman.config_from_subject(before_axes).variation == BaselineHuman.config_from_subject(after_axes).variation, "moving the brow does not repaint the whole face")

	print("INTAKE_BODY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
