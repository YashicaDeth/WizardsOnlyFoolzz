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
		check(node.get_node_or_null("anchor_grip") != null, "%s names where HeldGear closes the hand" % device_id)
		check(SX.PROFILES.has(str((SMOKEABLES.CATALOG[device_id] as Dictionary)["substance"])),
			"%s burns something with an authored curve" % device_id)
		if device_id == "bong":
			check(node.get_node_or_null("anchor_grip_support") != null, "the bong has a second physical handhold")
			check(bool(node.get_meta("two_handed", false)), "and names itself as a two-hand object")
		else:
			check(node.get_node_or_null("anchor_grip_support") == null, "%s does not invent a second hand" % device_id)
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
	check(int(WorldHistory.get("_ledger_batch_depth")) == 0, "dose, tolerance, harsh body cost and smoking receipt close one hit transaction")

	# --- tolerance reaches through the device --------------------------------
	check(SX.tolerance("player", "choir_bloom") == 1, "a smoked dose counts toward tolerance like any other")

	# --- AU7.8: it burns down, and the burn is derived from the charges -------
	for device_id: String in SMOKEABLES.CATALOG:
		var charges := float((SMOKEABLES.CATALOG[device_id] as Dictionary)["charges"])
		check(is_equal_approx(SMOKEABLES.spend_per_hit(device_id), 1.0 / charges),
			"%s spends exactly one of its own charges per hit" % device_id)

	var fresh: Node3D = SMOKEABLES.build("cigarette", 0.0)
	var stub: Node3D = SMOKEABLES.build("cigarette", 1.0)
	var fresh_length: float = ((fresh.get_meta("parts") as Dictionary)["body"] as MeshInstance3D).mesh.height
	var stub_length: float = ((stub.get_meta("parts") as Dictionary)["body"] as MeshInstance3D).mesh.height
	var fresh_ash: float = (((fresh.get_meta("parts") as Dictionary)["ash"] as MeshInstance3D).mesh as CylinderMesh).height
	var stub_ash: float = (((stub.get_meta("parts") as Dictionary)["ash"] as MeshInstance3D).mesh as CylinderMesh).height
	check(stub_length < fresh_length * 0.4, "a spent cigarette is visibly shorter than a fresh one")
	check(stub_length > 0.0, "and never burns away to nothing - you stub it out")
	check(stub_ash > fresh_ash, "ash accumulates on the resting object instead of existing only during RMB")

	# Monotonic, because a thing that got longer partway through would be a bug
	# nobody would think to look for.
	var previous := fresh_length + 1.0
	for step in 9:
		var at := float(step) / 8.0
		SMOKEABLES.set_spent(fresh, at)
		var now: float = ((fresh.get_meta("parts") as Dictionary)["body"] as MeshInstance3D).mesh.height
		check(now <= previous, "burning from %.2f never makes it longer" % at)
		previous = now
	check(is_equal_approx(SMOKEABLES.spent_of(fresh), 1.0), "and the object remembers how spent it is")

	var tank_full: Node3D = SMOKEABLES.build("vape", 0.0)
	var tank_dry: Node3D = SMOKEABLES.build("vape", 1.0)
	var full_z: float = ((tank_full.get_meta("parts") as Dictionary)["tank"] as MeshInstance3D).mesh.size.z
	var dry_z: float = ((tank_dry.get_meta("parts") as Dictionary)["tank"] as MeshInstance3D).mesh.size.z
	check(dry_z < full_z * 0.2, "a dead vape's tank window has dropped")

	var bowl_packed: Node3D = SMOKEABLES.build("bong", 0.0)
	var bowl_ashed: Node3D = SMOKEABLES.build("bong", 1.0)
	var packed_tint: Color = (((bowl_packed.get_meta("parts") as Dictionary)["pack"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
	var ashed_tint: Color = (((bowl_ashed.get_meta("parts") as Dictionary)["pack"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
	check(ashed_tint != packed_tint, "a spent bowl has gone to ash rather than staying green")

	# --- AU7.6 under I0: the gauge is the object ------------------------------
	# Nothing is drawn on a screen, so what a test can check is that the object
	# itself changes, measurably, with how long the button has been down.
	var held_light: OmniLight3D = (fresh.get_meta("parts") as Dictionary)["light"]
	var held_coal: MeshInstance3D = (fresh.get_meta("parts") as Dictionary)["coal"]
	var coal_material: StandardMaterial3D = held_coal.material_override
	SMOKEABLES.set_draw(fresh, 0.0)
	var rest_energy := coal_material.emission_energy_multiplier
	var rest_throw := held_light.light_energy
	SMOKEABLES.set_draw(fresh, 1.0)
	check(coal_material.emission_energy_multiplier > rest_energy, "drawing brightens the coal")
	check(held_light.light_energy > rest_throw, "and it throws more light while you do it")
	check(held_light.omni_range >= 6.0 and held_light.light_energy >= 4.0,
		"a live draw casts a usable warm pool into the night")
	var sweet_hue := coal_material.emission
	SMOKEABLES.set_draw(fresh, 1.6)
	check(coal_material.emission != sweet_hue,
		"past the sweet spot the cherry changes colour rather than only getting brighter")
	check(coal_material.emission.b > sweet_hue.b,
		"specifically it goes whiter, which is a different signal and not more of the same one")

	# The fix this test exists to hold: rest is one value, not two.
	var built_at_rest: Node3D = SMOKEABLES.build("cigarette", 0.0)
	var released: Node3D = SMOKEABLES.build("cigarette", 0.0)
	SMOKEABLES.set_draw(released, 1.2)
	SMOKEABLES.set_draw(released, 0.0)
	var a_rest: StandardMaterial3D = ((built_at_rest.get_meta("parts") as Dictionary)["coal"] as MeshInstance3D).material_override
	var b_rest: StandardMaterial3D = ((released.get_meta("parts") as Dictionary)["coal"] as MeshInstance3D).material_override
	check(is_equal_approx(a_rest.emission_energy_multiplier, b_rest.emission_energy_multiplier),
		"one off the table and one just released look identical - rest has a single definition")

	check(is_equal_approx(SMOKEABLES.draw_heat("cigarette", 1.6), 1.0),
		"holding for the ideal is exactly heat 1.0, so the gauge and the grade agree")
	check(SMOKEABLES.draw_heat("bong", 1.6) < 1.0, "and the bong wants longer before it reads full")

	var bong_parts: Dictionary = bowl_packed.get_meta("parts")
	var bong_chamber: MeshInstance3D = bong_parts["chamber_smoke"]
	var bong_bubbles: Array = bong_parts["bubbles"]
	SMOKEABLES.set_draw(bowl_packed, 0.0)
	check(not bong_chamber.visible and (bong_bubbles as Array).all(func(bubble): return not (bubble as MeshInstance3D).visible),
		"a resting bong has clear water and a clear chamber")
	SMOKEABLES.set_draw(bowl_packed, 0.8)
	check(bong_chamber.visible, "drawing continuously fills the bong chamber")
	check((bong_bubbles as Array).all(func(bubble): return (bubble as MeshInstance3D).visible),
		"and pulls visible bubbles through the water")
	check((bong_parts["light"] as OmniLight3D).light_energy > 0.0,
		"and lights the bowl during the same held draw")
	check((bong_parts["light"] as OmniLight3D).omni_range >= 4.5,
		"the burning bowl reaches beyond the prop into the nearby room")

	var live_spliff := SMOKEABLES.build("spliff", 0.0)
	var spliff_ash: MeshInstance3D = (live_spliff.get_meta("parts") as Dictionary)["ash"]
	SMOKEABLES.set_draw(live_spliff, 0.55)
	check(absf(spliff_ash.rotation.z) > 0.01, "a spliff visibly rolls as it is drawn")
	SMOKEABLES.set_draw(live_spliff, 0.0)
	check(is_zero_approx(spliff_ash.rotation.z), "and settles back into its authored rest")

	for node in [fresh, stub, tank_full, tank_dry, bowl_packed, bowl_ashed, built_at_rest, released, live_spliff]:
		(node as Node3D).free()

	print("SMOKEABLES_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
