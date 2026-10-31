extends Node

## Checklist: "every opening overlay tested in the real route, not only in the
## test scenes". In the real vat room and Support Unit: each overlay shows,
## goes away again, and leaves nothing on screen that eats the mouse.

const FIELD_MEDS := preload("res://systems/field_meds.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## Visible full-screen controls that stop the mouse: a stuck overlay.
func blockers(root: Node) -> Array:
	var out: Array = []
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control.is_visible_in_tree() and control.mouse_filter == Control.MOUSE_FILTER_STOP and control.size.x >= 1000.0:
			out.append(str(root.get_path_to(control)))
	return out


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	get_window().size = Vector2i(1280, 720)
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	await frames(2)

	# The brain hack card, in its real place in the sequence.
	vat.brain_hack.begin_hack()
	await frames(2)
	check(vat.brain_hack.visible, "vat: the brain hack card shows")
	vat.brain_hack.skip_hack()
	await frames(90)
	check(not vat.brain_hack.visible, "vat: and goes away when skipped")

	vat.intake._finish_filing()
	await frames(1)
	check(vat.intake == null or not vat.intake.is_visible_in_tree(), "vat: the intake is gone once filed")
	vat.departure_clock = vat.DEPARTURE_SECONDS
	vat._update_departure(0.0)
	vat.clock = vat.DRAINED_AT
	vat.phase = "voiding"
	vat._update_sequence(0.05)
	while not vat.umbilicals.is_empty():
		for _tug in vat.WIRE_TUGS:
			vat._tug_wire(vat.umbilicals[0])
	vat._physics_process(vat.REVENGE_HOLD + 0.1)
	for step in 40:
		vat._physics_process(0.1)
	await frames(2)
	check(vat.can_move, "vat: standing")
	check(blockers(vat).is_empty(), "vat: nothing on screen eats the mouse once you stand %s" % str(blockers(vat)))

	# K and J.
	vat.sight.enabled = true
	vat.sight.toggle_wizard()
	await frames(2)
	check(vat.sight.layer.visible and vat.sight.mode == "wizard", "vat: K shows wizard eyes")
	vat.sight.toggle_wizard()
	vat.sight.strain = 0.0
	await frames(2)
	check(not vat.sight.layer.visible, "vat: K again clears it (the layer sleeps)")
	vat.sight.hold_depth(true)
	await frames(2)
	check(vat.sight.mode == "depth", "vat: held J is the depth scan")
	vat.sight.hold_depth(false)
	vat.sight.strain = 0.0
	await frames(2)
	check(not vat.sight.layer.visible, "vat: let go and it clears")

	# The meds line.
	WorldHistory.update_subject("inventory", {"items": [{"label": "FIELD DRESSING"}]}, "carry_changed")
	vat.meds.step(vat, 3.0, func() -> void: pass, true)
	var line := vat.get_node_or_null("FieldMedsLine/Line") as Label
	check(line != null and line.visible, "vat: the field dressing line shows")
	vat.meds.step(vat, 0.1, func() -> void: pass, false)
	await get_tree().create_timer(2.6).timeout
	check(line != null and not line.visible, "vat: and fades on its own")

	# The examiner's bar.
	var fight = vat.doctor_route.fight
	fight._notice()
	await frames(1)
	check(fight.bar.visible, "office: the examiner's bar shows when he turns")
	fight._win()
	await frames(1)
	check(not fight.bar.visible, "office: and goes when he is down")
	check(blockers(vat).is_empty(), "vat: still nothing eating the mouse %s" % str(blockers(vat)))
	vat.queue_free()
	await frames(2)

	# The Support Unit: its K and its meds line.
	var unit = load("res://support_unit.tscn").instantiate()
	add_child(unit)
	await frames(3)
	unit.sight.enabled = true
	unit.sight.toggle_wizard()
	await frames(2)
	check(unit.sight.layer.visible, "support unit: K shows wizard eyes")
	unit.sight.toggle_wizard()
	unit.sight.strain = 0.0
	await frames(2)
	check(not unit.sight.layer.visible, "support unit: and clears")
	check(blockers(unit).is_empty(), "support unit: nothing eats the mouse %s" % str(blockers(unit)))
	unit.queue_free()
	await frames(2)

	# The run card on surfacing: shows, then frees itself.
	RunTimer.start()
	var card := RunCard.new()
	add_child(card)
	card.show_summary(RunTimer.finish())
	await frames(1)
	check(is_instance_valid(card) and card.sheet != null, "surfacing: the run card shows")
	card.age = card.HOLD_SECONDS + card.FADE_SECONDS
	await frames(2)
	check(not is_instance_valid(card), "surfacing: and removes itself")

	print("OPENING_OVERLAYS_ROUTE_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
