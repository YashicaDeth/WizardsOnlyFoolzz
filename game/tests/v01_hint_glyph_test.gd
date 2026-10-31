extends Node

## bughunt-79-c. The facility fight teacher named fixed buttons, "(B / SPACE)":
## an Xbox letter beside a key, whatever you were holding. Each line now names
## the button on the device last used.

var failures: Array[String] = []


class FakeChamber extends Node3D:
	var subtitle := Label.new()


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _say_for(family: String, spec: Dictionary) -> String:
	InputProfile.device_family_override = family
	var encounters := V01Encounters.new()
	var chamber := FakeChamber.new()
	encounters.chamber = chamber
	encounters._teach_colour(spec)
	var line := chamber.subtitle.text
	chamber.subtitle.free()
	chamber.free()
	encounters.free()
	return line


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	InputProfile.ensure_actions()
	var red := {"blockable": false}
	var copper := {"parryable": true}
	var pad_red := _say_for("ps5", red)
	var key_red := _say_for("keyboard", red)
	print("pad: ", pad_red, " | keys: ", key_red)
	check(pad_red.ends_with("(CIRCLE)"), "on a pad the red glint names CIRCLE: %s" % pad_red)
	check(key_red.ends_with("(SPACE)"), "on the keyboard it names SPACE: %s" % key_red)
	var pad_copper := _say_for("ps4", copper)
	var key_copper := _say_for("keyboard", copper)
	print("pad: ", pad_copper, " | keys: ", key_copper)
	check(pad_copper.contains("(L2)") and pad_copper.contains("(L1)"), "on a pad the copper glint names L2 and L1: %s" % pad_copper)
	check(key_copper.contains("(X)") and key_copper.contains("(RMB)"), "on the keyboard it names X and RMB: %s" % key_copper)
	check(not pad_copper.contains("RMB") and not pad_red.contains("SPACE"), "no keyboard key shows on a pad")
	InputProfile.device_family_override = ""
	print("V01_HINT_GLYPH_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
