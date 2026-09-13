extends Node3D

## B7.1 / B7.2. Clothes and layers on the rig, and armour and cover as one
## system rather than a stat.

var failures: Array[String] = []


func check(condition: bool, described: String) -> void:
	if not condition:
		failures.append(described)
	print("%s %s" % ["  ok" if condition else "FAIL", described])


func body(id: String, worn: Array) -> BaselineHuman:
	var rig := BaselineHuman.new()
	add_child(rig)
	rig.build(id, {"flesh": Color("7a6350"), "gore": false})
	rig.anatomy.worn = worn
	return rig


func _ready() -> void:
	var bare := body("bare", [])
	var wrapped := body("wrapped", ["lead wrap"])
	var coated := body("coated", ["ash coat"])

	# B7.1. A lead wrap is for radiation and a coat is not.
	var bare_hit: Dictionary = bare.anatomy.apply_hit("torso", 40.0, 0.0, "radiation")
	var wrapped_hit: Dictionary = wrapped.anatomy.apply_hit("torso", 40.0, 0.0, "radiation")
	var coated_hit: Dictionary = coated.anatomy.apply_hit("torso", 40.0, 0.0, "radiation")
	check(float(wrapped_hit.damage) < float(bare_hit.damage), "lead stops a dose (%.1f against %.1f)" % [float(wrapped_hit.damage), float(bare_hit.damage)])
	check(float(coated_hit.damage) > float(wrapped_hit.damage), "and a coat is not lead (%.1f)" % float(coated_hit.damage))

	# It protects the zones it covers and no others.
	var arm_bare: Dictionary = bare.anatomy.apply_hit("left_leg", 30.0, 0.0, "radiation")
	var arm_wrapped: Dictionary = wrapped.anatomy.apply_hit("left_leg", 30.0, 0.0, "radiation")
	check(is_equal_approx(float(arm_bare.damage), float(arm_wrapped.damage)), "a torso wrap does nothing for a leg")

	# B7.1. Weather. Standing in a storm doses what is not sealed.
	var masked := body("masked", ["filter mask"])
	var unmasked := body("unmasked", [])
	for _second in 20:
		masked.anatomy.expose(1.0, 0.1)
		unmasked.anatomy.expose(1.0, 0.1)
	check(unmasked.anatomy.dose_ratio("head") > 0.0, "a storm doses a bare head")
	check(
		masked.anatomy.dose_ratio("head") < unmasked.anatomy.dose_ratio("head"),
		"a filter mask keeps most of it out (%.3f against %.3f)" % [masked.anatomy.dose_ratio("head"), unmasked.anatomy.dose_ratio("head")],
	)

	# B7.2. Cover arrives at the same figure armour does.
	var exposed := body("exposed", [])
	var behind := body("behind", [])
	behind.anatomy.cover = {"torso": 0.8}
	var open_hit: Dictionary = exposed.anatomy.apply_hit("torso", 40.0, 0.0, "ballistic")
	var cover_hit: Dictionary = behind.anatomy.apply_hit("torso", 40.0, 0.0, "ballistic")
	check(float(cover_hit.damage) < float(open_hit.damage), "a wall protects the zone it is in front of (%.1f against %.1f)" % [float(cover_hit.damage), float(open_hit.damage)])
	var plated := body("plated", ["scrap plate"])
	var plate_hit: Dictionary = plated.anatomy.apply_hit("torso", 40.0, 0.0, "ballistic")
	check(float(plate_hit.damage) < float(open_hit.damage), "and so does a plate, through the same figure")

	# And it is on the body, not only in the numbers.
	var seen := BaselineHuman.new()
	add_child(seen)
	seen.build("seen", {"flesh": Color("7a6350"), "gore": false})
	var look := HunterAppearance.new()
	seen.add_child(look)
	look.configure(seen, {"name": "seen", "worn": ["ash coat", "filter mask"]})
	var layers := 0
	for node in seen.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("worn_layer"):
			layers += 1
	check(layers > 0, "what is worn is on the rig (%d layers)" % layers)

	print("GARMENTS_TEST_RESULT failures=", failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
