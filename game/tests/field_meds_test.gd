extends Node

## Greg, 26 September: meds on hold-4, a dressing heals 20. Checked on the
## shared piece, then with a real held 4 in the Support Unit and the Hunt.

const FIELD_MEDS := preload("res://systems/field_meds.gd")
const ANATOMY := preload("res://systems/anatomy_component.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func give(n: int) -> void:
	var items: Array = []
	for i in n:
		items.append(FIELD_MEDS.LABEL)
		items[i] = {"label": FIELD_MEDS.LABEL, "kind": "meds", "heals": 20}
	WorldHistory.update_subject("inventory", {"items": items}, "carry_changed")


func hold_four(down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_4
	event.keycode = KEY_4
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	var meds := FIELD_MEDS.new()
	give(2)
	check(FIELD_MEDS.count() == 2, "two dressings counted")
	check(meds.tick(0.3, true) == "holding", "holding 4 fills the bar")
	check(meds.tick(0.0, false) == "tap", "letting go early is a tap, nothing spent")
	check(FIELD_MEDS.count() == 2, "a tap spends nothing")
	var result := ""
	for i in 6:
		result = meds.tick(0.2, true)
	check(result == "used" or FIELD_MEDS.count() == 1, "a full second held spends one")
	check(FIELD_MEDS.count() == 1, "one left")
	check(meds.tick(0.5, true) == "", "still holding does not spend a second one")
	meds.tick(0.0, false)
	WorldHistory.update_subject("inventory", {"items": ["field dressing"]}, "carry_changed")
	check(FIELD_MEDS.count() == 1, "the Hunt broker's plain 'field dressing' counts too")
	WorldHistory.update_subject("inventory", {"items": []}, "carry_changed")
	check(meds.tick(0.1, true) == "none", "nothing to open says so once")
	check(meds.tick(0.1, true) == "", "and only once per hold")
	meds.tick(0.0, false)

	var body = ANATOMY.new()
	add_child(body)
	body.configure("meds_subject", 5000.0)
	body.apply_hit("left_leg", 30.0, 0.0, "cut")
	body.blood_remaining = 3000.0
	var leg_before := float(body.zones.left_leg.health)
	FIELD_MEDS.heal_anatomy(body)
	check(is_equal_approx(body.blood_remaining, 4000.0), "an anatomy body gets 20%% of its blood back (%.0f)" % body.blood_remaining)
	check(float(body.zones.left_leg.health) > leg_before, "and the worst zone is patched (%.0f -> %.0f)" % [leg_before, float(body.zones.left_leg.health)])
	body.queue_free()

	# The Support Unit, with a real held 4.
	give(1)
	var unit = load("res://support_unit.tscn").instantiate()
	add_child(unit)
	for i in 5:
		await get_tree().physics_frame
	unit.blood = 50.0
	hold_four(true)
	for i in 80:
		await get_tree().physics_frame
	hold_four(false)
	await get_tree().physics_frame
	check(is_equal_approx(unit.blood, 70.0), "Support Unit: holding 4 dresses a wound, 50 -> 70 blood (%.0f)" % unit.blood)
	check(FIELD_MEDS.count() == 0, "and the dressing is gone from the carry list")
	var line := unit.get_node_or_null("FieldMedsLine/Line") as Label
	check(line != null and "+20" in line.text, "a line says so (%s)" % (line.text if line != null else "none"))
	unit.queue_free()
	await get_tree().physics_frame

	# The Hunt: tap 4 is the carried limb, hold 4 the dressing.
	WorldHistory.clear_history()
	give(1)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for i in 5:
		await get_tree().physics_frame
	hunt.health = 40
	hold_four(true)
	for i in 80:
		await get_tree().physics_frame
	hold_four(false)
	await get_tree().physics_frame
	check(hunt.health == 60, "Hunt: holding 4 dresses a wound, 40 -> 60 (%d)" % hunt.health)
	check(FIELD_MEDS.count() == 0, "and spends the dressing")

	print("FIELD_MEDS_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
