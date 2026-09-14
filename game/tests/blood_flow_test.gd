extends Node

## Greg: "add in blood to there body as a fluid ... blood leaking from when you
## kill them". The test that matters is that what you see is what is killing
## them — the drip is driven by `anatomy.bleed_rate`, the same number the death
## model uses, not by a separate effect that happens to look similar.

const HUMAN := preload("res://systems/baseline_human.gd")
const FLOW := preload("res://systems/blood_flow.gd")

var failures: Array[String] = []

func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	# --- rate is a rate ----------------------------------------------------
	# Values are the measured ones, not round numbers: a 12-damage round leaves
	# bleed_rate at 0.38, a 34 at 1.07, a 95 at 2.99. Testing against 12.0 and
	# 40.0 tested two points that are both past the cap and told us nothing.
	check(FLOW.drops_for(0.1, 1.0) == 0.0, "a body that is barely bleeding does not drip — every bruise dripping means nothing reads as serious")
	var light := FLOW.drops_for(0.38, 1.0)
	var heavy := FLOW.drops_for(2.99, 1.0)
	check(light > 0.0, "a real wound does drip")
	check(heavy > light, "and bleeding harder drips faster")
	check(FLOW.drops_for(9999.0, 1.0) <= FLOW.MAX_DROPS_PER_SECOND + 0.001, "but it is capped, so one body cannot spend the whole gore budget")
	# Sub-frame rates are the normal case and must not round away.
	var per_frame := FLOW.drops_for(1.07, 1.0 / 60.0)
	check(per_frame > 0.0 and per_frame < 1.0, "at 60fps a real wound is a fraction of a drop per frame (%.4f) — which is why it accumulates rather than rounding" % per_frame)

	# --- a drip is not a spray ---------------------------------------------
	var v: Vector3 = FLOW.drip_velocity(Vector3.FORWARD)
	check(v.length() < 1.2, "blood runs out of a wound slowly (%.2f m/s), unlike the 1.9-5.5 m/s a hit throws it" % v.length())
	check(v.y < 0.0, "and it goes down, because it is falling rather than being thrown")

	# --- it dries ----------------------------------------------------------
	var wet: StandardMaterial3D = FLOW.streak_material(0.0)
	var dry: StandardMaterial3D = FLOW.streak_material(1.0)
	check(dry.roughness > wet.roughness, "a streak dries: old blood is matte, fresh blood is wet")
	check(dry.albedo_color.v < wet.albedo_color.v, "and darkens as it does")

	# --- end to end: a shot body actually bleeds ---------------------------
	var rig: BaselineHuman = HUMAN.new()
	add_child(rig)
	rig.build("bleeder", {})
	await get_tree().process_frame
	var torso := rig.parts.get("torso") as Node3D
	var at := torso.global_position + Vector3(-0.04, 0.10, 0.16)
	var zone := rig.zone_nearest(at)
	rig.hit_at(at, 34.0, 7.0, "ballistic", Vector3(0, 0, -1))
	check(rig.anatomy.bleed_rate > 0.0, "sanity: the hit opened something that bleeds")

	var sites: Array = rig.call("_bleeding_sites")
	check(not sites.is_empty(), "the wound is registered as somewhere blood can come out of")
	check(str(sites[0]["zone"]) == zone, "and it is the limb that was actually shot")

	var before: float = rig.get("_bleed_seconds")
	for _f in 90:
		await get_tree().process_frame
	check(float(rig.get("_bleed_seconds")) > float(before), "time bleeding accumulates while the wound is open")

	var part := rig.parts.get(zone) as Node3D
	var streak := part.get_node_or_null("BloodStreak")
	check(streak != null, "and a run of blood appears on the limb below the wound")

	# The streak has to hang the way gravity points, not the way the limb does,
	# or it is a texture rather than a fluid.
	# The streak's own +Y is its taper axis and points *down* — wide at the wound,
	# thin where it runs out — so the test asks whether that axis is parallel to
	# world vertical, not which end of it is up. What matters is that a run of
	# blood follows gravity rather than the limb, which is the whole reason it
	# reads as fluid instead of as a painted stripe.
	var axis: Vector3 = (part.global_transform.basis * (streak as Node3D).transform.basis.y).normalized()
	check(absf(axis.dot(Vector3.UP)) > 0.5, "the streak runs along world vertical rather than along the limb's own axis")
	check(axis.dot(Vector3.DOWN) > 0.5, "and it runs downward from the wound, not upward out of it")

	# --- a severed limb does not keep bleeding from a wound it took with it --
	rig.severed.append(zone)
	var after_sever: Array = rig.call("_bleeding_sites")
	var still_there := false
	for site: Dictionary in after_sever:
		if str(site["zone"]) == zone:
			still_there = true
	check(not still_there, "a limb that has come off stops being a place this body bleeds from")

	print("BLOOD_FLOW_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
