extends Node

## C8.1 `v8`. Pocketing is a lowering transition, not a visibility cut, and
## the world light must follow that same transition instead of surviving after
## the object has left the hand.

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
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	await get_tree().process_frame

	hunt.handheld.set_process(false)
	hunt.handheld.battery = 1.0
	hunt.handheld.open_device()
	hunt.handheld.raised = 1.0
	hunt._update_handheld_lamp(0.016)
	check(hunt.handheld_lamp.visible, "the control starts with the held light present")

	hunt.handheld.close_device()
	hunt.handheld._process(0.016)
	hunt._update_handheld_lamp(0.016)
	check(hunt.handheld.raised > 0.0 and hunt.handheld.raised < 1.0, "pocketing begins a lowering movement instead of hiding instantly")
	check(hunt.handheld_lamp.visible, "the light remains while the still-raised screen is physically leaving the hand")

	var crossed_dark := false
	for _step in 80:
		hunt.handheld._process(0.025)
		hunt._update_handheld_lamp(0.025)
		if hunt.handheld.raised <= 0.5 and not hunt.handheld_lamp.visible:
			crossed_dark = true
	check(crossed_dark, "the beam leaves at the same held threshold as the screen")
	check(hunt.handheld.raised <= 0.001 and not hunt.handheld_lamp.visible, "the pocketed end state has neither held object nor leftover light")

	print("HANDHELD_POCKET_LIGHT_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
