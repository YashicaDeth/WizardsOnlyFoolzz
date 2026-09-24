extends Node

## The seam wipe covers fully, uncovers fully, hides itself when clear, and
## Interstitial actually owns one (so every scene change gets it).

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var kit := TransitionKit.new()
	add_child(kit)
	var wipe := kit.get_node("Wipe") as ColorRect
	check(not wipe.visible, "a clear wipe draws nothing")

	kit.set_style("flesh")
	check(kit.style_name() == "flesh", "styles select by name")
	kit.set_style("no-such-wipe")
	check(kit.style_name() == "flesh", "an unknown name keeps the current style")
	kit.set_style(-1)
	check(kit.style_name() == "crt", "indices wrap, so any hash picks a real style")

	await kit.cover(0.1)
	check(is_equal_approx(kit.progress, 1.0) and wipe.visible, "cover ends fully covered")
	await kit.reveal(0.1)
	check(is_equal_approx(kit.progress, 0.0) and not wipe.visible, "reveal ends clear and hidden")

	check(Interstitial.wipe is TransitionKit, "every scene change goes through the wipe")

	print("TRANSITION_KIT_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
