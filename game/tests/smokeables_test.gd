extends Node

## AU1.8. A hit is press-and-hold with a sweet spot you can overshoot, every
## device puts that spot somewhere different, and the buzz it produces is a real
## dose on the same curve a swallowed one runs on.

const SMOKEABLES := preload("res://systems/smokeables.gd")
const SX := preload("res://systems/substance_experience.gd")

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
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})

	# --- every device builds, and builds something ---------------------------
	for device_id: String in SMOKEABLES.CATALOG:
		var node: Node3D = SMOKEABLES.build(device_id)
		check(node != null and node.get_child_count() > 0, "%s is built from primitives, not nothing" % device_id)
		check(SX.PROFILES.has(str((SMOKEABLES.CATALOG[device_id] as Dictionary)["substance"])),
			"%s burns something with an authored curve" % device_id)
		node.free()

	# --- the curve: a snatch is thin, the sweet spot is best, greed bites ----
	for device_id: String in SMOKEABLES.CATALOG:
		var ideal := float((SMOKEABLES.CATALOG[device_id] as Dictionary)["draw_ideal"])
		var snatch := SMOKEABLES.draw_quality(device_id, ideal * 0.15)
		var clean := SMOKEABLES.draw_quality(device_id, ideal)
		var greedy := SMOKEABLES.draw_quality(device_id, ideal * 3.0)
		check(float(snatch["strength"]) < float(clean["strength"]), "%s: a snatched draw gets less than a held one" % device_id)
		check(str(snatch["grade"]) == SMOKEABLES.WEAK, "%s: and it is graded weak" % device_id)
		check(str(clean["grade"]) == SMOKEABLES.CLEAN, "%s: the sweet spot grades clean" % device_id)
		check(float(clean["harsh"]) == 0.0, "%s: and costs nothing" % device_id)
		check(str(greedy["grade"]) == SMOKEABLES.HARSH, "%s: greed grades harsh" % device_id)
		check(float(greedy["harsh"]) > 0.0, "%s: and it actually costs something" % device_id)
		check(float(greedy["strength"]) <= float(clean["strength"]) * 2.0,
			"%s: holding forever does not pay forever" % device_id)

	# --- the devices are genuinely different objects -------------------------
	var cig := SMOKEABLES.CATALOG["cigarette"] as Dictionary
	var bong := SMOKEABLES.CATALOG["bong"] as Dictionary
	check(float(bong["draw_ideal"]) > float(cig["draw_ideal"]), "a bong wants a longer pull than a cigarette")
	check(float(bong["forgiveness"]) < float(cig["forgiveness"]), "and is far less forgiving about it")
	check(float(bong["yield_scale"]) > float(cig["yield_scale"]) * 3.0, "and pays out accordingly")
	check(bool(bong["two_handed"]) and not bool(cig["two_handed"]), "and it is the only one that takes both hands")
	# The overshoot window is the whole difference between them as objects.
	var cig_over := SMOKEABLES.draw_quality("cigarette", float(cig["draw_ideal"]) * 1.6)
	var bong_over := SMOKEABLES.draw_quality("bong", float(bong["draw_ideal"]) * 1.6)
	check(float(bong_over["harsh"]) > float(cig_over["harsh"]) * 2.0,
		"overshooting a bong by the same fraction hurts far more than overshooting a cigarette")

	# --- AU1.8: an observable buzz ------------------------------------------
	var clean_hit := SMOKEABLES.hit("player", "joint", 2.2, 0.0)
	check(bool(clean_hit.get("ok", false)), "a clean hit lands")
	var dials := SX.dials_for("player", 12.0)
	check(dials != SX.REST, "and the screen is measurably different afterwards")
	check(float(dials["lut_strength"]) > 0.0 or float(dials["chromatic_offset"]) > 0.0,
		"specifically: something is on that was not on before")
	var sober = SX.dials_for("player", 6000.0)
	check(sober == SX.REST, "and it wears off")

	# --- harshness is paid into the body, not a private counter -------------
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person",
		"anatomy_state": {"consciousness": 100.0, "pain": 0.0}})
	SMOKEABLES.hit("player", "bong", 14.0, 0.0)
	var anatomy: Dictionary = WorldHistory.subject("player").get("anatomy_state", {})
	check(float(anatomy.get("consciousness", 100.0)) < 100.0, "coughing your lungs up costs consciousness")
	check(float(anatomy.get("pain", 0.0)) > 0.0, "and hurts, in the same field everything else hurts in")

	# --- the world remembers a hit ------------------------------------------
	var smoked := WorldHistory.events.filter(func(e): return str(e.get("type", "")) == "smoked")
	check(not smoked.is_empty(), "smoking is a recorded event like anything else you do")
	check(str((smoked[0].get("details", {}) as Dictionary).get("grade", "")) == SMOKEABLES.HARSH,
		"and the record says which kind of draw it was")

	# --- tolerance reaches through the device --------------------------------
	check(SX.tolerance("player", "choir_bloom") == 1, "a smoked dose counts toward tolerance like any other")

	print("SMOKEABLES_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
