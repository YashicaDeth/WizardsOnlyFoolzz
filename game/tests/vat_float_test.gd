extends Node

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
	for frame in 3:
		await get_tree().process_frame

	var rigs: Array[BaselineHuman] = []
	for node in vat.find_children("CradledSubject_*", "", true, false):
		if node is BaselineHuman:
			rigs.append(node as BaselineHuman)
	var preview = vat.intake.body_preview
	check(preview != null and preview.rig != null, "the real intake route builds IntakeSpecimen")
	if preview != null and preview.rig != null:
		rigs.append(preview.rig as BaselineHuman)
	check(rigs.size() >= 3, "the chamber exposes its floating tank subjects (%d)" % rigs.size())

	for rig in rigs:
		var motion := rig.get_node_or_null("VatFloat")
		check(not bool(rig.get("_seated")), "%s is not built seated" % rig.name)
		check(motion != null, "%s is wired to VatFloat" % rig.name)
		if motion == null:
			continue
		var start := rig.position
		var farthest := 0.0
		var stayed_inside := true
		for step in 100:
			motion.advance(0.1)
			farthest = maxf(farthest, rig.position.distance_to(start))
			stayed_inside = stayed_inside and motion.inside_tank()
		check(farthest > 0.02, "%s drifts more than 2 cm over ten seconds (%.3f m)" % [rig.name, farthest])
		check(stayed_inside, "%s stays inside its tank radius and above its floor" % rig.name)

	var expected_gore := BaselineHuman.apply_gore_setting()
	for rig in rigs:
		if rig.name.begins_with("CradledSubject_"):
			check(rig.gore == expected_gore, "%s retains the global gore setting" % rig.name)

	var horror: VatHorror = vat.horror
	var alive: BaselineHuman = horror._subject(1)
	var arm := alive.parts.get("left_arm") as Node3D
	var before := arm.rotation
	var horror_moved := false
	for tick in 80:
		horror.clock = float(tick) * 0.1
		horror._convulse(alive, 1.0)
		if arm.rotation.distance_to(before) > 0.01:
			horror_moved = true
			break
	check(horror_moved, "VatHorror convulsion still moves a floating subject's parts")

	VatHorror.force_in_tests = false
	print("VAT_FLOAT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
