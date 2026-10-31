extends Node3D

## The medical monitor prints the body it is looking at, and every number it
## prints is the live field the simulation is writing — not a copy.
##
## Carl 0.8.71's `M` screen (adopted in `DESIGN/CARL_COMPARISON.md`): blood in
## litres and percent, the rate it is leaving at, what is broken, what is
## exposed, and the last hit restated in the wound's own terms. The two things
## this test exists to prove:
##
## - the printed blood and bleed follow a wound, then a heavier one, then stop
##   dead when the bleeding is stopped;
## - circulation is printed from the anatomy's own model, and a missing body
##   prints `UNKNOWN` rather than a number invented to fill the row.

const MedicalMonitor := preload("res://systems/medical_monitor.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func line_starting(lines: Array, prefix: String) -> String:
	for line in lines:
		if str(line).begins_with(prefix):
			return str(line)
	return ""


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	RenderingServer.set_default_clear_color(Color("11100e"))
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.6, 0.0)
	add_child(light)
	var body := BaselineHuman.new()
	add_child(body)
	body.build("subject", {"gore": true})
	await get_tree().physics_frame
	var anatomy := body.anatomy

	# --- a healthy body, before anything has happened to it ------------------
	var lines: Array = MedicalMonitor.lines(body)
	print("FRESH ", lines)
	check(lines.size() >= 10, "the monitor prints a full screen (%d lines)" % lines.size())
	check(str(lines[0]) == "BODY // SUBJECT", "and names whose body it is (%s)" % lines[0])
	check(line_starting(lines, "BLD ") == "BLD 5.00 L  100% OF 5.00 L", "blood is the real capacity, not a rounded guess (%s)" % line_starting(lines, "BLD "))
	check(line_starting(lines, "BLEED ") == "BLEED 0.0 mL/s", "an unwounded body is not bleeding (%s)" % line_starting(lines, "BLEED "))
	check(line_starting(lines, "O2 ") == "O2 100%  PERF 100%", "a whole body carries a full reserve and full flow (%s)" % line_starting(lines, "O2 "))
	check(line_starting(lines, "FRACTURES ") == "FRACTURES NONE", "nothing is broken yet (%s)" % line_starting(lines, "FRACTURES "))
	check(line_starting(lines, "EXPOSED ") == "EXPOSED NONE", "and nothing is exposed (%s)" % line_starting(lines, "EXPOSED "))
	check(line_starting(lines, "HIT ") == "HIT NONE", "with no hit on record (%s)" % line_starting(lines, "HIT "))
	check(line_starting(lines, "VESSELS ") == "VESSELS 0 OPEN", "and every vessel is where it should be")

	# --- a wound: blood starts leaving at a printed rate ---------------------
	body.hit("left_arm", 18.0, 6.0, "cut")
	await get_tree().create_timer(0.25).timeout
	var light_bleed := float(anatomy.bleed_rate)
	var light_blood := float(anatomy.blood_remaining)
	lines = MedicalMonitor.lines(body)
	print("WOUNDED ", lines)
	check(light_bleed > 0.0, "a cut opens a bleed (%.2f mL/s)" % light_bleed)
	check(light_blood < float(anatomy.blood_capacity), "and the body is losing blood (%.1f mL)" % light_blood)
	check(line_starting(lines, "BLEED ") == "BLEED %.1f mL/s" % light_bleed, "the printed rate is the body's own (%.1f)" % light_bleed)
	check(line_starting(lines, "BLD ").contains("%d%%" % roundi(light_blood / float(anatomy.blood_capacity) * 100.0)), "and the printed percent is what is left")
	check(line_starting(lines, "HIT ").contains("CUT") and line_starting(lines, "HIT ").contains("LEFT ARM"),
		"the last hit is restated in its own terms (%s)" % line_starting(lines, "HIT "))

	# --- a heavy hit: more bleeding, less blood -----------------------------
	body.hit("torso", 55.0, 14.0, "ballistic")
	await get_tree().create_timer(0.25).timeout
	var heavy_bleed := float(anatomy.bleed_rate)
	var heavy_blood := float(anatomy.blood_remaining)
	lines = MedicalMonitor.lines(body)
	print("HEAVY ", lines)
	check(heavy_bleed > light_bleed, "a heavier wound bleeds harder (%.1f > %.1f)" % [heavy_bleed, light_bleed])
	check(heavy_blood < light_blood, "and more blood is gone (%.1f < %.1f)" % [heavy_blood, light_blood])
	check(line_starting(lines, "BLEED ") == "BLEED %.1f mL/s" % heavy_bleed, "the screen follows it up (%.1f)" % heavy_bleed)
	check(line_starting(lines, "HIT ").contains("BALLISTIC") and line_starting(lines, "HIT ").contains("TORSO"),
		"and the newest wound is the one stated (%s)" % line_starting(lines, "HIT "))

	# --- a stopped bleed: the rate falls to zero and the blood stops going --
	anatomy.bleed_rate = 0.0
	anatomy.internal_bleed_rate = 0.0
	var frozen := float(anatomy.blood_remaining)
	await get_tree().create_timer(0.3).timeout
	lines = MedicalMonitor.lines(body)
	check(line_starting(lines, "BLEED ") == "BLEED 0.0 mL/s", "stopping the bleed prints zero (%s)" % line_starting(lines, "BLEED "))
	check(is_equal_approx(float(anatomy.blood_remaining), frozen), "and the blood stops going with it")

	# --- no cached copy anywhere --------------------------------------------
	# Writing the field directly has to show up on the very next read; a screen
	# that kept its own copy would still say what it said a frame ago.
	anatomy.blood_remaining = anatomy.blood_capacity * 0.5
	check(line_starting(MedicalMonitor.lines(body), "BLD ").contains("50%"), "the readout has no cache: a changed field is printed at once")

	# --- what is exposed, and what is missing -------------------------------
	anatomy.damage_organ("heart", 999.0)
	lines = MedicalMonitor.lines(body)
	print("RUPTURED ", lines)
	check(line_starting(lines, "EXPOSED ").contains("HEART"), "a ruptured organ is named (%s)" % line_starting(lines, "EXPOSED "))
	# The field `_sever_limb()` writes, so the vessel count is the body's own.
	body.severed.append("left_arm")
	check(line_starting(MedicalMonitor.lines(body), "VESSELS ") == "VESSELS 1 OPEN", "a taken limb is an open vessel (%s)" % line_starting(MedicalMonitor.lines(body), "VESSELS "))
	# The honest case: nothing to read.
	var empty: Array = MedicalMonitor.lines(null)
	check(str(empty[1]) == "BLD UNKNOWN" and line_starting(empty, "O2 ") == "O2 UNKNOWN  PERF UNKNOWN", "a missing body prints UNKNOWN, not zeroes")
	check(empty.size() == lines.size(), "and keeps the same shape, so the panel does not jump")

	print("MEDICAL_MONITOR_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
