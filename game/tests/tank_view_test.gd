extends Node

## Greg, 28 September: inside the tank, the room through the medium, bubbles,
## breath, a heartbeat that speeds with panic, everything muffled; gone once
## the tank drains.

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
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	for i in 3:
		await get_tree().physics_frame
	var view: TankView = vat.tank_view
	view._process(2.0)
	check(view.in_tank and view.amount > 0.9 and view.visible, "in the intake you are in the tank")
	check(view.muffled(), "the room is muffled")
	check(view.heart.playing and view.breath.playing, "heartbeat and breathing")
	var calm: float = view.heart.pitch_scale
	vat.phase = "hacked"
	vat._physics_process(0.016)
	view._process(0.016)
	check(view.heart.pitch_scale > calm, "the hack speeds the heart (%.2f -> %.2f)" % [calm, view.heart.pitch_scale])
	vat.phase = "aisle"
	vat._physics_process(0.016)
	view._process(2.0)
	check(not view.in_tank and not view.visible, "once out, the tank view is gone")
	check(not view.muffled(), "and the room is not muffled any more")
	check(not view.heart.playing, "the heartbeat stops")
	vat.queue_free()
	await get_tree().process_frame
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Master")) == 0, "no filter left on the master bus")
	print("TANK_VIEW_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
