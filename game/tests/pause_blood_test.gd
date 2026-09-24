extends Node

## The pause menu matches the logo: the live seal in its corner, blood poured
## under the row you're on (fresh on every move), a tear on opening or a new
## page, and a tick when you move.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var gate = get_node("/root/PauseGate")
	check(gate.seal != null and (gate.seal.material as ShaderMaterial).shader == gate.LOGO_FX, "the live seal sits in the pause plate")
	gate.open_gate()
	check(gate.tear > 0.0 and gate.sounds.played.has("tear"), "opening tears the rows, with static")
	for _step in 20:
		gate._process(0.05)
	check(gate.pour >= 1.0 and gate.tear <= 0.0, "the blood pours under the row, and the tear settles")
	gate.highlighted = 1
	gate._process(0.01)
	check(gate.pour < 0.2 and gate.sounds.played.has("drip"), "moving starts a fresh pour, and ticks")
	gate.page = "settings"
	gate._process(0.01)
	check(gate.tear > 0.0, "a new page tears too")
	gate.close()
	get_tree().paused = false
	print("PAUSE_BLOOD_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
