extends Node

## B3.1 / B3.2. Radiation as a damage path through the same anatomy.
##
## The claims this guards: it reaches what is inside a body without opening it,
## it barely bleeds, it does not fracture a limb, it goes on doing damage after
## the hit, and it survives a save. Each of those is a way it differs from a
## cut, and a cut of the same size is measured beside it every time.

var failures: Array[String] = []


func check(condition: bool, described: String) -> void:
	if not condition:
		failures.append(described)
	print("%s %s" % ["  ok" if condition else "FAIL", described])


func _ready() -> void:
	var dosed := AnatomyComponent.new()
	add_child(dosed)
	dosed.configure("dosed")
	var cut := AnatomyComponent.new()
	add_child(cut)
	cut.configure("cut")

	var heart_before: float = float((cut.organs["heart"] as Dictionary).health)
	var radiation: Dictionary = dosed.apply_hit("torso", 40.0, 0.0, "radiation")
	var blade: Dictionary = cut.apply_hit("torso", 40.0, 0.0, "cut")

	check(
		float((dosed.organs["heart"] as Dictionary).health) < heart_before,
		"radiation reaches an organ with no way in",
	)
	check(
		float((cut.organs["heart"] as Dictionary).health) == heart_before,
		"a blade that named no organ reaches none (the control)",
	)
	check(
		dosed.bleed_rate < cut.bleed_rate * 0.2,
		"it barely bleeds (%.2f against %.2f)" % [dosed.bleed_rate, cut.bleed_rate],
	)
	check(bool(radiation.get("melted", false)), "the wound records itself as melted")
	check(not blade.has("melted"), "a cut does not")
	check(dosed.dose_ratio("torso") > 0.0, "the zone is left carrying dose")

	# The half a cut does not have: it is still working afterwards.
	var health_after_hit: float = float((dosed.zones["torso"] as Dictionary).health)
	var organ_after_hit: float = float((dosed.organs["heart"] as Dictionary).health)
	for _tick in 40:
		dosed._process(0.05)
	check(
		float((dosed.zones["torso"] as Dictionary).health) < health_after_hit,
		"the zone keeps losing ground after the hit lands",
	)
	check(
		float((dosed.organs["heart"] as Dictionary).health) < organ_after_hit,
		"and so does what is inside it",
	)

	# A limb is melted, not broken.
	var limb := AnatomyComponent.new()
	add_child(limb)
	limb.configure("limb")
	for _blast in 4:
		limb.apply_hit("left_arm", 22.0, 0.0, "radiation")
	check(
		str((limb.zones["left_arm"] as Dictionary).get("fracture", "")) == "",
		"a dosed limb has no fracture: it is melted, not broken",
	)

	# And it travels with the body.
	var carried := AnatomyComponent.new()
	add_child(carried)
	carried.configure("carried")
	carried.restore(dosed.snapshot())
	check(carried.dose_ratio("torso") > 0.0, "dose survives a save and a restore")

	print("RADIATION_PATH_TEST_RESULT failures=", failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
