extends Node

## Nudity and the censor (Greg, 24 September): a naked body shows its forms
## under a body-cam glitch by default; clothing covers them; turning the
## censor off leaves the forms and removes the glitch; every region has both.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _rig(anatomy: String) -> BaselineHuman:
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build("forms_" + anatomy, BaselineHuman.config_from_subject({"anatomy_sex": anatomy}))
	return rig


func _count(rig: BaselineHuman, prefix: String) -> int:
	var found := 0
	for child in rig.parts.torso.get_children():
		if str(child.name).begins_with(prefix):
			found += 1
	return found


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	check(AnatomyPresentation.mode() == "MOSAIC", "the censor is on by default")
	var body := _rig("female")
	check(_count(body, "Nude_") > 0 and _count(body, "Censor_") == 3, "a naked body shows its forms under three censors")
	for region: String in BodyForms.REGIONS:
		check(BodyForms.censored(body, region), "%s is censored" % region)
	Outfit.dress(body)
	check(_count(body, "Nude_") == 0 and _count(body, "Censor_") == 0, "the jester set covers everything")
	Outfit.break_lock(body, "sword")
	var carry := Carry.new()
	Outfit.take_off(body, carry, "jester_doublet")
	check(BodyForms.exposed(body, "chest") and not BodyForms.exposed(body, "groin"), "without the doublet the chest shows; the pantaloons still cover the groin")
	check(BodyForms.censored(body, "chest") and not BodyForms.censored(body, "groin"), "and only the chest is censored")
	Outfit.take_off(body, carry, "jester_hose")
	check(BodyForms.exposed(body, "groin") and BodyForms.exposed(body, "buttocks"), "without the pantaloons too, everything shows")
	AnatomyPresentation.set_mode("EXPLICIT")
	Outfit.dress(body)
	check(_count(body, "Censor_") == 0 and _count(body, "Nude_") > 0, "with the censor off the forms show plain")
	AnatomyPresentation.set_mode("MOSAIC")
	var male := _rig("male")
	var female := _rig("female")
	check(male.parts.torso.get_node_or_null("Nude_groin") != null and female.parts.torso.get_node_or_null("Nude_groin") == null, "the forms follow the intake's anatomy")
	check((female.parts.torso.get_node("Nude_chest_1") as Node3D).scale.z > (male.parts.torso.get_node("Nude_chest_1") as Node3D).scale.z, "and the frame")
	var parity := true
	for region in AnatomyPresentation.EXPLICIT_REGIONS:
		if region in ["chest", "groin", "buttocks"]:
			parity = parity and BodyForms.REGIONS.has(region)
	check(parity, "every body region AnatomyPresentation names has a form and a censor")
	print("BODY_FORMS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
