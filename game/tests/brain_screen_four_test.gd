extends Node

## dec-89 (Greg, 6 Oct night): the brain screen offers all four disciplines
## (Brawler, Marksman, Duelist, Shade) and you slot two. A Duelist or Shade
## pick is recorded, lights its lobe and arms its weapon like the other two.

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
	WorldHistory.register_subject("player", {"kind": "person", "name": "THE HUNTER"})
	check(BrainScreen.OFFER_LAB_DISCIPLINES, "the dial is on")
	var ids: Array = BrainScreen.offered().map(func(entry: Dictionary) -> String: return str(entry.id))
	check(ids == ["brawler", "marksman", "duelist", "shade"], "four cards on the chip (%s)" % [ids])
	for id in ids:
		check(DisciplineLobes.LOBES.has(id), "%s runs in a lobe (%s)" % [id, DisciplineLobes.lobe(id)])

	var screen := BrainScreen.new()
	add_child(screen)
	var picked: Array = []
	screen.finished.connect(func(pair: Array) -> void: picked.append_array(pair))
	await get_tree().process_frame
	# Right, right: Duelist. Cross. Right: Shade. Cross. Cross locks.
	screen.move(2)
	screen.confirm()
	check(screen.slotted == ["duelist"], "Duelist slots first (%s)" % [screen.slotted])
	screen.focus = 3
	screen.confirm()
	check(screen.ready_to_lock(), "two of four slotted: ready to lock")
	screen.focus = 0
	screen.confirm()
	check(picked == ["duelist", "shade"], "locking reports the pair in slot order (%s)" % [picked])
	check(WorldHistory.subject("player").get("disciplines", []) == ["duelist", "shade"], "the record holds it")
	check(WorldHistory.event_count("brain_disciplines_slotted") == 1, "slotted once")
	check(DisciplineLobes.slotted() == ["duelist", "shade"], "both light their lobes on the HUD brains")

	# The Hunt arms the pair: the first slot in hand, the second carried.
	var arsenal := HunterArsenal.new()
	add_child(arsenal)
	var held := DisciplineLobes.arm(arsenal, "cleaver")
	check(held == "cleaver", "Duelist first: the cleaver is in hand (%s)" % held)
	check(arsenal.carried().has("shiv"), "Shade second: the shiv is carried")
	WorldHistory.amend_subject("player", {"disciplines": ["shade", "marksman"]})
	var second := HunterArsenal.new()
	add_child(second)
	check(DisciplineLobes.arm(second, "cleaver") == "shiv", "Shade first: the shiv is in hand")

	# A third press on a full chip cannot slot a third.
	var again := BrainScreen.new()
	add_child(again)
	again.focus = 1
	again.confirm()
	again.focus = 2
	again.confirm()
	check(again.slotted.size() == BrainScreen.SLOTS, "never more than two")
	again.back()
	check(again.slotted == ["marksman"], "back unslots the last one")
	again.queue_free()

	print("BRAIN_SCREEN_FOUR_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
