extends Node

## AX1.6. The point of this suite is the parity check: it fails the day someone
## adds a body region to one presentation and not the other.

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
	WorldHistory.register_subject("settings", {"kind": "settings"})

	check(AnatomyPresentation.parity_gaps().is_empty(), "every region exists in both presentations (gaps: %s)" % str(AnatomyPresentation.parity_gaps()))
	check(AnatomyPresentation.mode() == "MOSAIC", "the censored presentation is the default, not the opt-in")

	check(AnatomyPresentation.set_mode("EXPLICIT") == "EXPLICIT", "explicit can be turned on")
	check(AnatomyPresentation.is_explicit(), "and the world agrees it is on")
	check(AnatomyPresentation.set_mode("NONSENSE") == "EXPLICIT", "an unknown mode changes nothing")

	AnatomyPresentation.set_mode("MOSAIC")
	for region in AnatomyPresentation.EXPLICIT_REGIONS:
		var t := AnatomyPresentation.treatment(region)
		check(bool(t.ok), "%s has a censored treatment" % region)
		check(float(t.cell) > 0.0, "and it is a real mosaic rather than nothing (%s cell %.0f)" % [region, t.cell])
		check(bool(t.keeps_silhouette), "and it keeps the shape of %s rather than deleting it" % region)

	# The one that matters: a censored build still says this person was opened.
	var wound := AnatomyPresentation.treatment("wounds_deep")
	check(bool(wound.keeps_blood), "a deep wound keeps its blood under the mosaic")
	check(float(wound.cell) < 12.0, "and is pixelated finely enough to still read as a wound")

	check(not bool(AnatomyPresentation.treatment("elbow").ok), "an unregistered region is refused, not guessed at")

	# AX1.3. The anatomy question the facility used to answer for you.
	const SHEET := preload("res://systems/character_sheet.gd")
	var sheet = SHEET.new()
	check(sheet.anatomy_sex == "unformed", "a decanted body starts unformed - nothing was chosen for it")
	check(CharacterSheet.ANATOMY_SEX.size() >= 4, "there is a real range of options (%d)" % CharacterSheet.ANATOMY_SEX.size())
	for key in CharacterSheet.ANATOMY_SEX.keys():
		check(CharacterSheet.ANATOMY_SEX_FILED.has(key), "%s has a filed institutional record" % key)
	sheet.anatomy_sex = "intersex"
	check(str(CharacterSheet.ANATOMY_SEX[sheet.anatomy_sex].name) == "INTERSEX", "the body is what the player chose")
	check(str(CharacterSheet.ANATOMY_SEX_FILED[sheet.anatomy_sex]) != "INTERSEX", "and the facility files something else")
	check(str(CharacterSheet.ANATOMY_SEX_FILED["intersex"]) == "F / STANDARD", "specifically F / STANDARD, because the form has no second box")

	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
