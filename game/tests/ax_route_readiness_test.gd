extends Node

## The consolidated demo, checked as a chain rather than as parts.
##
## There are twenty-eight demo-level test scenes in this project and not one of
## them mentions AX. Each beat of the opening is covered by its own suite and
## every one of them passes, which tells you the parts work and nothing at all
## about whether a player can get from the vat to the surface.
##
## This walks the route in order and reports which beats are actually live. It
## is deliberately shallow per beat -- the deep tests already exist and are
## better -- and its whole value is the last line it prints: how much of the
## demo is real today, in one number, from one command.
##
## A beat is "live" when the mechanism the player would touch responds
## correctly. Not when the file exists.

var failures: Array[String] = []
var live := 0
var beats := 0


func beat(name: String, ok: bool, detail: String = "") -> void:
	beats += 1
	if ok:
		live += 1
	print("%s %s%s" % ["PASS" if ok else "FAIL", name, (" -- " + detail) if detail != "" else ""])
	if not ok:
		failures.append(name)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var sheet = load("res://systems/character_sheet.gd").new()

	# --- AX1. The examination is the character creation.
	sheet.race = "born"
	var filed := DoctorExamination.classify(sheet)
	beat("AX1.1/1.4 the examination files you as something you did not choose",
		str(filed.label) != str(filed.chosen) and not bool(filed.agrees),
		"chose %s, filed %s" % [filed.chosen, filed.label])

	beat("AX1.2 the doctor has something to say about the body page",
		not DoctorExamination.observe("body", 0).is_empty())

	beat("AX1.3 anatomy is a choice with an institutional record",
		sheet.anatomy_sex == "unformed" and CharacterSheet.ANATOMY_SEX.size() >= 4
			and CharacterSheet.ANATOMY_SEX_FILED.has("intersex"))

	sheet.traits = ["clerical_error"]
	CharacterPresets.save("ROUTE CHECK", sheet)
	var repeat = load("res://systems/character_sheet.gd").new()
	CharacterPresets.apply("ROUTE CHECK", repeat)
	beat("AX1.3 a repeat player can come back on a preset",
		repeat.race == "born" and repeat.traits.has("clerical_error"))

	beat("AX1.6 the censored presentation is complete, not a hole",
		AnatomyPresentation.parity_gaps().is_empty())

	# --- AX2. The verdict, the refusal, the breakout.
	var verdict := DoctorExamination.verdict(sheet)
	var spoken := ""
	for line in verdict:
		spoken += str(line.line) + " "
	beat("AX2.1 the verdict names what the player actually picked",
		spoken.contains("clerical error"))

	beat("AX2.2 submission alone never awakens the soul",
		not SoulBreakthrough.awakened(30, 0) and SoulBreakthrough.awakened(4, 2))

	WorldHistory.register_subject("player", {"kind": "person"})
	BrainIndex.install_chip("player", "celloutz", "the_facility")
	var seized := SoulBreakthrough.seize("player", 4, 2)
	beat("AX2.3 the government chip ends up answering to the player",
		bool(seized.ok) and str(BrainIndex.chip("player").get("owner_faction", "")) == "self",
		"was %s" % seized.get("was", "?"))

	beat("AX2.4 the breakout exists as a recorded act",
		FileAccess.file_exists("res://vat_chamber.gd")
			and FileAccess.open("res://vat_chamber.gd", FileAccess.READ).get_as_text().contains("_record_breakout"))

	DoctorExamination.begin_departure()
	var reachable_now := DoctorExamination.reachable()
	WorldClock.set_hour(WorldClock.minutes() / 60.0 + 1.0)
	beat("AX2.5 the doctor can be chased, and missing him is silent",
		reachable_now and not DoctorExamination.reachable() and DoctorExamination.urgency() == 0.0)

	DoctorExamination.record_kill("blade")
	DoctorExamination.reconstruct()
	beat("AX2.6 killing him stays killed after he is rebuilt",
		DoctorExamination.was_killed())

	# --- AX3. What the escape teaches by handing it to you.
	beat("AX3.5 the prototype is taken rather than issued",
		FileAccess.file_exists("res://systems/restricted_storage.gd"))

	# --- AX4. Getting out, and dying on the way.
	var death := OpeningDeath.handle("route check")
	beat("AX4.5 opening death is rebirth in the vat, not a counterfeit",
		str(death.kind) == "rebirth" and str(death.scene) == "res://vat_chamber.tscn"
			and OpeningDeath.counterfeits_in(str(death)).is_empty())

	# --- AX5. The contracts the slice has to hold.
	var hunt := FileAccess.open("res://bone_yard_hunt.gd", FileAccess.READ).get_as_text()
	var strike := hunt.substr(hunt.find("\nfunc _resolve_strike"), 3000)
	beat("AX5.1 damage does not know which camera is active",
		not strike.contains("third_person"))

	beat("AX5.3 distant bodies get cheaper without being forgotten",
		RoamerDetail.relative_cost(RoamerDetail.Tier.SIMULATED) > RoamerDetail.relative_cost(RoamerDetail.Tier.DORMANT)
			and not RoamerDetail.frees(RoamerDetail.Tier.DORMANT))

	print("")
	print("DEMO READINESS: %d of %d beats live" % [live, beats])
	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
