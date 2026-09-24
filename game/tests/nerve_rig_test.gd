extends Node

## The rig's marks are readings, not decoration: vertebrae track health,
## the rack tracks real pockets, and a full-sheet panel hides it.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var rig := NerveRig.new()
	add_child(rig)
	rig.set_state({"health": 100.0})
	check(rig.intact_vertebrae() == NerveRig.VERTEBRAE, "a whole body seats every vertebra")
	rig.set_state({"health": 50.0})
	check(rig.intact_vertebrae() == NerveRig.VERTEBRAE / 2, "half health seats half the column")
	rig.set_state({"health": 1.0})
	check(rig.intact_vertebrae() == 1, "one point of health still holds one vertebra")
	rig.set_state({"health": 0.0})
	check(rig.intact_vertebrae() == 0, "nothing left seats nothing")
	rig.set_state({"pockets": [{"label": "a"}, {"label": "b"}]})
	check(rig.filled_pockets() == 2, "the rack shows the pockets actually filled")
	rig.set_state({"pockets": [{}, {}, {}, {}]})
	check(rig.filled_pockets() == NerveRig.POCKETS, "never more bottles than carry.gd allows pockets")
	rig.set_state({"menu_open": true})
	check(not rig.visible, "a full-sheet panel owns the screen")

	var calm := NerveRig.new()
	add_child(calm)
	calm.set_process(false)
	calm.set_state({"health": 100.0, "stamina": 100.0})
	for _second in 4 * 10:
		calm.step_presence(0.1)
	check(is_equal_approx(calm.presence, NerveRig.IDLE_PRESENCE), "a whole, untouched body recedes (%.2f)" % calm.presence)
	calm.set_state({"health": 100.0, "stamina": 92.0})
	calm.step_presence(0.2)
	check(calm.presence > 0.95, "spending stamina brings it straight back (%.2f)" % calm.presence)
	calm.set_state({"health": 55.0, "stamina": 100.0})
	for _second in 10 * 10:
		calm.step_presence(0.1)
	check(calm.presence > 0.95, "a hurt body never fades, however long it waits (%.2f)" % calm.presence)

	var hud := preload("res://systems/gothic_field_hud.gd").new()
	add_child(hud)
	hud.set_state({"health": 25.0, "pockets": [{"label": "x"}]})
	check(hud.nerve_rig != null and hud.nerve_rig.intact_vertebrae() == 3, "the field HUD drives the rig from its own state")

	print("NERVE_RIG_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
