extends Node

## Greg, 28 September: the next tanks and a colder examiner.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	VatHorror.force_in_tests = true
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var horror: VatHorror = vat.horror
	check(horror != null and horror.subjects.size() >= 2, "the next tanks' subjects are handed over (%d)" % (horror.subjects.size() if horror != null else 0))
	var blood_before: float = vat.anatomy.blood_remaining
	for i in 70:
		horror._process(1.0)
	check(horror.acts_done.has("inject") and horror.acts_done.has("sample"), "he injects you and cuts a sample during the intake")
	check(float(vat.anatomy.bleed_rate) > 0.0 or vat.anatomy.blood_remaining < blood_before, "and you bleed for it")
	check(horror.acts_done.has("price"), "he reads your price aloud")
	check(horror.drained and WorldHistory.event_count("vat_subject_drained") == 1, "and drains the failed tank beside you")
	check(vat.get_node_or_null("BloodCloud_2") != null, "its medium runs red")
	check(str(vat.intake.doctor_says) != "", "his lines reach the HE SAYS panel")
	vat.phase = "hacked"
	for i in 120:
		horror._process(1.0 / 30.0)
	var cloud := vat.get_node_or_null("BloodCloud_1") as Node3D
	check(cloud != null and cloud.scale.x > 0.05, "after the hack the one awake hammers and bleeds into their tank")
	VatHorror.force_in_tests = false
	print("VAT_HORROR_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
