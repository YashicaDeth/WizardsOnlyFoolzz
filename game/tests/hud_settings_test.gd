extends Node

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func select_row(gate: Node, id: String) -> bool:
	gate._build_rows()
	for index in gate._rows.size():
		if str(gate._rows[index].id) == id:
			gate.highlighted = index
			return true
	check(false, "menu row exists: %s" % id)
	return false


func _ready() -> void:
	# Test mode isolates the live save; the round trip below checks the same
	# settings dictionary that WorldHistory includes in its JSON save.
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var gate := get_node_or_null("/root/PauseGate")
	check(gate != null, "pause gate is available")
	if gate == null:
		get_tree().quit(1)
		return
	check(is_equal_approx(gate._hud_opacity(), 0.9), "new saves start with 90 percent opacity")
	check(gate._hud_style() == "rails" and not gate._reduced_glitch(), "style and glitch defaults are registered")
	WorldHistory.update_subject("settings", {"volume_music": 0.37, "gore": "REDUCED"})
	gate.open_gate()
	if select_row(gate, "settings"):
		gate._activate()
	if select_row(gate, "hud"):
		gate._activate()
	check(gate.page == "hud", "HUD controls are reachable from the pause menu")
	if select_row(gate, "hud_opacity"):
		gate._nudge(-1)
	check(is_equal_approx(gate._hud_opacity(), 0.85), "left lowers opacity by five percent")
	gate._set_hud_opacity(-5.0)
	check(is_equal_approx(gate._hud_opacity(), 0.25), "opacity clamps to 25 percent")
	gate._set_hud_opacity(5.0)
	check(is_equal_approx(gate._hud_opacity(), 1.0), "opacity clamps to 100 percent")
	gate._set_hud_opacity(0.65)
	if select_row(gate, "hud_style"):
		gate._activate()
	check(gate._hud_style() == "arcs", "Enter switches rails to arcs")
	gate._nudge(-1)
	check(gate._hud_style() == "rails", "left switches arcs back to rails")
	gate._nudge(1)
	if select_row(gate, "reduced_glitch"):
		gate._activate()
	check(gate._reduced_glitch(), "Enter enables reduced glitch")
	gate._nudge(-1)
	check(not gate._reduced_glitch(), "left disables reduced glitch")
	gate._nudge(1)
	if select_row(gate, "settings_back"):
		gate._activate()
	check(gate.page == "settings", "HUD Back returns to settings")
	if select_row(gate, "back"):
		gate._activate()
	check(gate.page == "root", "settings Back returns to pause root")
	gate.close()
	gate.open_gate()
	check(is_equal_approx(gate._hud_opacity(), 0.65) and gate._hud_style() == "arcs" and gate._reduced_glitch(), "closing and reopening keeps all HUD settings")
	gate.close()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(WorldHistory.subject("settings")))
	WorldHistory.subjects["settings"] = saved
	check(is_equal_approx(gate._hud_opacity(), 0.65) and gate._hud_style() == "arcs" and gate._reduced_glitch(), "HUD settings survive the save JSON round trip")
	check(is_equal_approx(float(saved.volume_music), 0.37) and saved.gore == "REDUCED", "HUD changes preserve existing audio and violence settings")
	WorldHistory.register_subject("settings", {"hud_opacity": 0.9, "hud_style": "rails", "reduced_glitch": false})
	check(is_equal_approx(gate._hud_opacity(), 0.65) and gate._hud_style() == "arcs" and gate._reduced_glitch(), "startup defaults preserve returning player settings")
	print("HUD_SETTINGS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
