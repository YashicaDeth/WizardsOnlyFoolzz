extends Node

## Greg, 25 September: the examiner asks "What style of fighting do you
## want?". The STYLE page answers him; the answer opens that style's first
## blood-tree node before you have earned any blood, and iron starts you on the
## sidearm in the Hunt.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func press(target, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	target._unhandled_input(key)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await get_tree().process_frame
	var intake = vat.intake
	intake.intake_armed = true
	check(intake.PAGES.has("STYLE"), "the form has a STYLE page")
	intake.opening_active = false
	intake.page = intake.PAGES.find("STYLE")
	intake._doctor_observe()
	check(str(intake.doctor_says) == "What style of fighting do you want?", "he asks, in Greg's words")
	check(intake._rows() == 4, "four styles to answer with")
	intake.row = BloodTrees.STYLE_ORDER.find("firearm")
	intake._commit()
	check(intake.sheet.fighting_style == "firearm", "the answer goes on the sheet")
	check(intake.touched_pages.has(intake.page), "and confirms the page")
	intake._begin_verdict()
	var frames := 0
	while vat.intake != null and is_instance_valid(intake) and frames < 60:
		press(intake, KEY_F)
		intake._process(1.0 / 60.0)
		frames += 1
		await get_tree().process_frame
	check(vat.intake == null, "filed")
	check(str(WorldHistory.subject("player").get("fighting_style", "")) == "firearm", "the filed record carries the style")
	var ledger := BloodLedger.new()
	ledger.load_state()
	check(ledger.is_unlocked(BloodTrees.first_node("firearm")), "iron's first node (%s) is open before any blood" % BloodTrees.first_node("firearm"))
	check(not ledger.is_unlocked(BloodTrees.first_node("melee")), "and no other style's")
	check(ledger.available("firearm") == 0, "it cost nothing")
	ledger.free()
	check(WorldHistory.event_count("fighting_style_chosen") == 1, "the choice is recorded")
	check(BloodTrees.starting_weapon("firearm") == "sidearm" and HunterArsenal.SLOT_ORDER.has("sidearm"), "iron walks into the Hunt on the sidearm")
	check(BloodTrees.starting_weapon("melee") == "sword", "blade / blunt keeps the sword")
	print("FIGHTING_STYLE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
