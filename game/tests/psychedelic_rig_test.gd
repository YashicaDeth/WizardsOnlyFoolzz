extends Node

## FINAL_V.md §16. The rig has to stay inert until something asks it to be
## more, and the six dials have to be the whole interface to it.

const RIG := preload("res://systems/psychedelic_rig.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var rig: Control = RIG.new()
	add_child(rig)

	check(rig.get_child_count() == 2, "the echo viewport and a display, nothing else")
	check(absf(rig.dial("feedback_strength")) < 0.001, "feedback starts at zero")
	check(absf(rig.dial("feedback_zoom") - 1.0) < 0.001, "zoom starts neutral, not zero")

	rig._process(0.0)
	var display: ColorRect = rig.get_node("Display")
	check(not display.visible, "nothing has touched a dial, so nothing is shown over the real frame")

	rig.set_dial("kaleidoscope_segments", 6.0)
	rig._process(0.0)
	check(display.visible, "a live dial engages the display")
	check(absf(rig.dial("kaleidoscope_segments") - 6.0) < 0.001, "the dial actually took")

	rig.set_dial("not_a_real_dial", 5.0)
	check(not ("not_a_real_dial" in rig._dials), "an unknown dial name is ignored rather than adopted")

	rig.reset_dials()
	rig._process(0.0)
	check(not display.visible, "resetting every dial disengages the rig again")
	check(absf(rig.dial("kaleidoscope_segments")) < 0.001, "including the one that was just set")

	if failures.is_empty():
		print("psychedelic rig: inert until asked, and only the dials move it")
		get_tree().quit(0)
	else:
		print("psychedelic rig FAILURES: ", failures)
		get_tree().quit(1)
