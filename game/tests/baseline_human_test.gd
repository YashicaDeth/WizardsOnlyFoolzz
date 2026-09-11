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
	_test_severing()
	_test_prosthetic()
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
	# Proximity voice needs one consistent place to speak from on any body.
	check(body.head_anchor != null and body.head_anchor.position.y > 1.0, "rig exposes a head anchor for voice")
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
	var body := _rig()
	for i in 12:
		body.hit("right_arm", 40.0, 20.0, "shear")
	check(body.severed.has("right_arm"), "a destroyed arm comes off")
	check(not (body.get_node("right_arm") as MeshInstance3D).visible, "a severed limb stops rendering")
	check(body.zone_nearest(body.to_global(Vector3(0.34, 1.12, 0))) != "right_arm", "a severed limb cannot be hit again")
	for i in 20:
		body.hit("torso", 40.0, 20.0, "blunt")
	check(not body.severed.has("torso"), "a torso is never severed, however destroyed")
	body.queue_free()


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
