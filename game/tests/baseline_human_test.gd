extends Node

## Covers the defect the rig exists to fix: zone names that did not match
## AnatomyComponent's vocabulary resolved to "torso" in silence, so a leg wound
## was recorded as a chest wound. Bounds are asserted in both directions — the
## named zone must take the damage AND the torso must not.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	_test_rig_shape()
	_test_legacy_names()
	_test_damage_lands_where_aimed()
	_test_hit_geometry()
	_test_pain_posture()
	_test_severing()
	_test_prosthetic()
	_test_gore()
	_test_organs()
	_test_downed()
	print("BASELINE_HUMAN_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _rig(seated := false) -> BaselineHuman:
	var body := BaselineHuman.new()
	add_child(body)
	body.build("test_subject", {"seated": seated})
	return body


func _test_rig_shape() -> void:
	var body := _rig()
	var missing: Array[String] = []
	for zone_id in BaselineHuman.ZONES:
		if body.get_node_or_null(zone_id) == null:
			missing.append(zone_id)
		var hitbox := body.get_node_or_null("%s_hitbox" % zone_id) as Area3D
		if hitbox == null or str(hitbox.get_meta("body_zone", "")) != zone_id:
			missing.append("%s_hitbox" % zone_id)
	check(missing.is_empty(), "every canonical zone has a mesh and a tagged hitbox (missing %s)" % str(missing))
	# Shoulders are chest-owned bridges, not arm-owned spheres. That makes the
	# silhouette read as one body and leaves a physical shoulder behind when an
	# arm is severed instead of exposing a daylight seam at the torso.
	check(body.shoulders.size() == 2 \
		and body.shoulders.get("left_arm") != null \
		and body.shoulders.get("right_arm") != null, "the torso carries both shoulder caps")
	# Proximity voice needs one consistent place to speak from on any body.
	check(body.head_anchor != null and body.head_anchor.position.y > 1.0, "rig exposes a head anchor for voice")
	check((body.bones.torso as Node3D).get_child_count() >= BaselineHuman.SPINE_VERTEBRAE, "the torso rig carries all 33 vertebrae")
	var seated := _rig(true)
	check(seated.get_node_or_null("left_leg") != null, "a seated driver keeps the same zones, folded into the cab")
	check(seated.head_anchor.position.y < body.head_anchor.position.y, "seated head sits lower than standing")
	body.queue_free()
	seated.queue_free()


func _test_legacy_names() -> void:
	# Each of these existed at a real call site and silently became "torso".
	var expected := {
		"legs": "left_leg", "leg": "left_leg", "left arm": "left_arm",
		"right arm": "right_arm", "LEFT_LEG": "left_leg", "Head": "head",
		"chest": "torso", "torso": "torso",
	}
	var wrong: Array[String] = []
	for loose in expected:
		var got := BaselineHuman.canonical_zone(loose)
		if got != str(expected[loose]):
			wrong.append("%s -> %s (wanted %s)" % [loose, got, expected[loose]])
	check(wrong.is_empty(), "legacy zone spellings map onto canonical zones (%s)" % str(wrong))
	# Degrading safely still matters: genuine nonsense must not crash or invent
	# a zone, it lands on the torso.
	check(BaselineHuman.canonical_zone("elbow_of_the_soul") == "torso", "an unknown zone falls back to torso rather than failing")


func _test_damage_lands_where_aimed() -> void:
	var body := _rig()
	var torso_before := body.zone_health("torso")
	var leg_before := body.zone_health("left_leg")
	body.hit("legs", 30.0, 10.0, "cut")
	check(body.zone_health("left_leg") < leg_before, "a hit spelled 'legs' damages a leg (%.0f -> %.0f)" % [leg_before, body.zone_health("left_leg")])
	check(is_equal_approx(body.zone_health("torso"), torso_before), "...and leaves the torso untouched (%.0f)" % body.zone_health("torso"))
	var head_before := body.zone_health("head")
	body.hit("left arm", 25.0, 8.0, "cut")
	check(body.zone_health("left_arm") < 65.0, "a hit spelled 'left arm' damages the left arm")
	check(is_equal_approx(body.zone_health("head"), head_before), "...and does not bleed into the head")
	body.queue_free()


func _test_hit_geometry() -> void:
	var body := _rig()
	check(body.zone_nearest(body.to_global(Vector3(0, 1.62, 0))) == "head", "a blow at head height resolves to the head")
	check(body.zone_nearest(body.to_global(Vector3(-0.14, 0.42, 0))) == "left_leg", "a blow at the left shin resolves to the left leg")
	check(body.zone_nearest(body.to_global(Vector3(0.34, 1.12, 0))) == "right_arm", "a blow at the right arm resolves to the right arm")
	body.queue_free()


func _test_severing() -> void:
	# Health loss and detachment are intentionally separate. A club can ruin a
	# limb, but it cannot behave like an invisible sword.
	var broken := _rig()
	broken.gore = false
	for i in 4:
		broken.hit("right_arm", 25.0, 20.0, "blunt", "", Vector3.RIGHT)
	check(is_zero_approx(broken.zone_health("right_arm")), "blunt force can fully disable an arm")
	check(not broken.severed.has("right_arm") and broken.parts.right_arm.visible, "...but a blunt-disabled arm remains attached")
	broken.queue_free()

	# A weak cut from the wrong angle can also disable without detaching. The
	# direction is gameplay data, not decoration on the particle effect.
	var lengthwise := _rig()
	lengthwise.gore = false
	lengthwise.hit("left_arm", 44.0, 28.0, "cut", "", Vector3.UP)
	lengthwise.hit("left_arm", 44.0, 28.0, "cut", "", Vector3.UP)
	check(not lengthwise.severed.has("left_arm"), "lengthwise cuts do not satisfy the cross-cut sever threshold")
	lengthwise.queue_free()

	var body := _rig()
	body.gore = false
	var combat_before := body.anatomy.combat_ratio()
	var first := body.hit("right_arm", 44.0, 28.0, "cut", "", Vector3.RIGHT)
	check(not bool(first.get("severed", false)), "the first directional sword blow wounds but does not detach")
	var second := body.hit("right_arm", 44.0, 28.0, "cut", "", Vector3.RIGHT)
	check(bool(second.get("severed", false)) and body.severed.has("right_arm"), "the cross-cut crossing the limb threshold severs mid-fight")
	check(not (body.get_node("right_arm") as MeshInstance3D).visible, "a severed limb stops rendering")
	var right_shoulder := body.shoulders.get("right_arm") as MeshInstance3D
	check(right_shoulder != null and right_shoulder.visible, "the chest keeps its shoulder after an arm is severed")
	check(not body.anatomy.dead and not body.anatomy.downed, "losing an arm leaves the person alive and still in the fight")
	check(body.anatomy.combat_ratio() < combat_before, "arm loss reduces combat ability (%.2f -> %.2f)" % [combat_before, body.anatomy.combat_ratio()])
	check(body.zone_nearest(body.to_global(Vector3(0.34, 1.12, 0))) != "right_arm", "a severed limb cannot be hit again")

	var state := body.snapshot()
	var restored := BaselineHuman.new()
	add_child(restored)
	restored.gore = false
	restored.build("restored_amputee", {"restore": state, "gore": false})
	check(restored.severed.has("right_arm") and not restored.parts.right_arm.visible, "save/load preserves the actual missing limb")
	check(is_equal_approx(float(restored.sever_stress.get("right_arm", 0.0)), float(body.sever_stress.get("right_arm", 0.0))) and float(restored.sever_stress.get("right_arm", 0.0)) > 0.0, "save records accumulated sever stress")
	restored.queue_free()

	for i in 20:
		body.hit("torso", 40.0, 20.0, "blunt")
	check(not body.severed.has("torso"), "a torso is never severed, however destroyed")
	body.queue_free()


func _test_pain_posture() -> void:
	var body := _rig()
	body.gore = false
	var mobility_before := body.anatomy.mobility_ratio()
	body.hit("torso", 24.0, 10.0, "blunt")
	var posture := body.anatomy.posture()
	check(str(posture.state) == "guarded" and float(posture.hunch) < 0.0, "ordinary pain produces a guarded posture before a performance penalty")
	check(is_equal_approx(body.anatomy.mobility_ratio(), mobility_before), "guarded pain does not yet reduce mobility")
	body._apply_pain_posture(1.0)
	check(body.rotation.x < -0.01, "the rig visibly hunches when its anatomy reports pain")
	var spine_before := body.anatomy.mobility_ratio()
	body.anatomy.damage_organ("spine", 10.0)
	check(body.anatomy.xray_findings().any(func(finding): return str(finding).contains("33 VERTEBRAE")), "spinal damage is counted against the body's 33 vertebrae")
	check(body.anatomy.mobility_ratio() < spine_before, "partial spinal damage changes mobility before the spine is destroyed")
	body._refresh_spine_vertebrae()
	var marked := 0
	for piece in (body.bones.torso as Node3D).get_children():
		if piece.has_meta("vertebra") and int(piece.get_meta("vertebra")) in body.anatomy.organs.spine.vertebrae_damaged:
			marked += 1
	check(marked > 0, "the 3D spine carries the same damaged vertebrae the X-ray reports")
	body.queue_free()


func _test_downed() -> void:
	# The window every resolution happens inside. Two-sided throughout: going
	# down must not be death, and death must not be survivable.
	var body := _rig()
	body.gore = false
	check(not body.is_downed(), "an unhurt body is not down")
	for i in 5:
		body.hit("torso", 30.0, 12.0, "blunt")
	check(body.is_downed(), "caving in the chest drops them")
	check(not body.anatomy.dead, "...but dropping them is not killing them")
	check(body.rotation.x < -0.1, "a downed body goes off its feet")

	# Spared: alive, upright, and still carrying what was done to them.
	body.spare()
	check(not body.is_downed(), "sparing brings them back up")
	check(not body.anatomy.dead, "a spared body is alive")
	check(body.zone_health("torso") <= 0.0, "...and still wrecked — sparing is not healing")
	body.queue_free()

	var doomed := _rig()
	doomed.gore = false
	for i in 5:
		doomed.hit("torso", 30.0, 12.0, "blunt")
	doomed.execute("gutted")
	check(doomed.anatomy.dead, "executing a downed body kills it")
	check(not doomed.is_downed(), "an executed body is no longer merely down")
	doomed.queue_free()

	var headless := _rig()
	headless.gore = false
	for i in 5:
		headless.hit("torso", 30.0, 12.0, "blunt")
	headless.behead()
	check(headless.severed.has("head"), "beheading takes the head")
	check(not headless.parts["head"].visible, "a taken head stops rendering")
	check(headless.anatomy.dead, "beheading is fatal")
	headless.queue_free()

	# Bleeding out is the one outcome nobody gets to decide about.
	var bleeder := _rig()
	bleeder.gore = false
	bleeder.anatomy.bleed_rate = 60.0
	bleeder.anatomy.blood_remaining = 1.0
	bleeder.anatomy._process(1.0)
	check(bleeder.anatomy.dead, "running out of blood kills regardless")
	bleeder.queue_free()


func _test_organs() -> void:
	var body := _rig()
	var missing: Array[String] = []
	for organ_id in AnatomyComponent.ORGANS:
		if body.organ_parts.get(organ_id) == null:
			missing.append(str(organ_id))
	check(missing.is_empty(), "every organ has geometry inside its zone (missing %s)" % str(missing))
	check(not body.organ_parts["heart"].visible, "organs are not visible from outside the body")

	# A club breaks ribs. It does not perforate a liver — if blunt damage
	# reached organs, every zone hit would be a lethal one.
	for i in 6:
		body.hit("torso", 30.0, 15.0, "blunt")
	var blunt_ruptures := 0
	for organ_id in body.anatomy.organs:
		if not body.anatomy.organ_ok(organ_id):
			blunt_ruptures += 1
	check(blunt_ruptures == 0, "blunt damage leaves organs intact (%d ruptured)" % blunt_ruptures)
	body.queue_free()

	# Named organ, named consequence.
	var gutted := _rig()
	gutted.hit("torso", 90.0, 20.0, "cut", "gut")
	check(not gutted.anatomy.organ_ok("gut"), "a blade through the gut ruptures the gut")
	check(gutted.anatomy.organ_ok("heart"), "...and leaves the heart alone")
	check(gutted.anatomy.has_internal_bleeding(), "a ruptured gut carries a hidden internal bleed in addition to any surface wound")
	check(gutted.anatomy.xray_findings().has("INTERNAL BLEED: GUT"), "only an X-ray finding names the hidden bleed")
	check(not gutted.anatomy.dead, "a gut wound is not instantly fatal")
	var gut_bleed: float = gutted.anatomy.bleed_rate
	gutted.queue_free()

	var shot := _rig()
	shot.hit("torso", 90.0, 20.0, "cut", "heart")
	check(shot.anatomy.internal_bleed_rate > gutted.anatomy.internal_bleed_rate, "a heart shot bleeds harder inside than a gut wound (%.1f vs %.1f)" % [shot.anatomy.internal_bleed_rate, gutted.anatomy.internal_bleed_rate])
	check(not shot.organ_parts["heart"].visible, "a ruptured organ leaves the body")
	shot.queue_free()

	var executed := _rig()
	executed.hit("head", 90.0, 20.0, "cut", "brain")
	check(executed.anatomy.dead, "destroying the brain kills outright")
	executed.queue_free()

	var broken := _rig()
	var mobile_before: float = broken.anatomy.mobility_ratio()
	broken.hit("torso", 90.0, 20.0, "cut", "spine")
	check(broken.anatomy.mobility_ratio() < mobile_before * 0.4, "a severed spine floors mobility (%.2f -> %.2f)" % [mobile_before, broken.anatomy.mobility_ratio()])
	broken.queue_free()

	# The X-ray needs to see inside without opening anyone up.
	var scanned := _rig()
	scanned.reveal_organs(true)
	check(scanned.organ_parts["liver"].visible, "the X-ray reveals organs")
	check(scanned.get_node("torso").transparency > 0.0, "...by making the body translucent, not by removing it")
	scanned.reveal_organs(false)
	check(not scanned.organ_parts["liver"].visible, "and hides them again")
	scanned.queue_free()

	# Bodies remember which organ they lost, not just that they were hurt.
	var donor := _rig()
	donor.hit("torso", 90.0, 20.0, "cut", "liver")
	var state: Dictionary = donor.snapshot()
	donor.queue_free()
	var heir := BaselineHuman.new()
	add_child(heir)
	heir.build("test_heir", {"restore": state})
	check(not heir.anatomy.organ_ok("liver"), "a restored body still has the ruptured liver")
	check(heir.anatomy.organ_ok("heart"), "...and still has everything it did not lose")
	check(not heir.organ_parts["liver"].visible, "a restored missing organ is not rendered back in")
	heir.queue_free()

	# Saves written before organs existed must still load.
	var legacy := BaselineHuman.new()
	add_child(legacy)
	legacy.build("test_legacy", {"restore": {"blood": 4000, "zones": {}, "wounds": []}})
	check(legacy.anatomy.organs.size() == AnatomyComponent.ORGANS.size(), "a save with no organs migrates to a full set")
	legacy.queue_free()


func _test_gore() -> void:
	BaselineHuman.live_gore = 0
	var body := _rig()
	# Two-sided: an undamaged limb has no bone showing.
	check(body.get_node("left_leg").get_node_or_null("Fracture") == null, "a healthy limb has no fracture")
	check(body._loose.is_empty(), "an untouched body has not bled")
	body.hit("left_leg", 30.0, 12.0, "blunt")
	check(not body._loose.is_empty(), "a cut draws blood")
	# A flesh wound is not a broken bone. The threshold has to mean something in
	# both directions, so check it does not fire early either.
	check(body.get_node("left_leg").get_node_or_null("Fracture") == null, "a leg at 60 percent is hurt, not broken")
	body.hit("left_leg", 30.0, 12.0, "blunt")
	check(body.anatomy.fracture_kind("left_leg") == "closed" and body.get_node("left_leg").get_node_or_null("Fracture") == null, "a blunt fracture is closed and remains under the skin")
	body.hit("right_leg", 36.0, 12.0, "puncture")
	body.hit("right_leg", 36.0, 12.0, "puncture")
	check(body.anatomy.fracture_kind("right_leg") == "compound" and body.get_node("right_leg").get_node_or_null("Fracture") != null, "a penetrating fracture is a different injury and breaks through the skin")
	# Torso opens up only once the chest is actually gone.
	check(not body.has_meta("gutted"), "an intact chest holds its organs")
	for i in 8:
		body.hit("torso", 40.0, 20.0, "shear")
	check(body.has_meta("gutted"), "a destroyed chest spills organs")
	var spilled: int = BaselineHuman.live_gore
	# Blunt, so nothing new ruptures and only spray is added. A second full set
	# of organs coming out of the same chest would mean the guard had failed.
	body.hit("torso", 40.0, 20.0, "blunt")
	check(BaselineHuman.live_gore <= spilled + 6, "the chest does not spill a second full set of organs")
	for i in 12:
		body.hit("right_arm", 40.0, 20.0, "shear")
	check(body.get_node_or_null("right_arm_stump") != null, "a severed arm leaves exposed bone at the joint")
	body.queue_free()

	# The viscera toggle has to actually suppress it, not just dim it.
	BaselineHuman.live_gore = 0
	var clean := _rig()
	clean.gore = false
	for i in 10:
		clean.hit("left_arm", 40.0, 20.0, "shear")
	check(BaselineHuman.live_gore == 0, "viscera off spawns no gore at all (%d)" % BaselineHuman.live_gore)
	check(clean.severed.has("left_arm"), "...but the limb is still lost — the simulation does not depend on the effect")
	clean.queue_free()

	# The cap is the difference between atmosphere and a frame-rate bug.
	BaselineHuman.live_gore = 0
	var bleeder := _rig()
	for i in 60:
		bleeder.hit("torso", 30.0, 10.0, "cut")
	check(BaselineHuman.live_gore <= BaselineHuman.MAX_LIVE_GORE, "loose gore stays under the global cap (%d)" % BaselineHuman.live_gore)
	bleeder.queue_free()


func _test_prosthetic() -> void:
	var body := _rig()
	for i in 12:
		body.hit("left_arm", 40.0, 20.0, "shear")
	check(body.severed.has("left_arm"), "arm destroyed before fitting")
	body.install_prosthetic("left_arm", {"name": "Ashline scrap arm", "restores": 0.6, "armor": 0.2})
	check(not body.severed.has("left_arm"), "a prosthetic restores the limb")
	check(body.zone_health("left_arm") > 0.0, "a fitted limb carries function again (%.0f)" % body.zone_health("left_arm"))
	# It restores function, not the person: never back to a whole arm.
	check(body.zone_health("left_arm") < 65.0, "...but never back to an undamaged arm")
	check(body.anatomy.installed_parts.has("left_arm"), "the fitting is recorded on the anatomy for the dossier")
	body.queue_free()
