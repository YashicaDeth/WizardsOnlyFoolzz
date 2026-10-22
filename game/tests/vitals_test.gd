extends Node3D

## Circulation and oxygen, on the screen and in the one model behind them.
##
## Walks a single body through the four states `DESIGN/CARL_COMPARISON.md` and
## the medical monitor ask about — whole, bleeding, arrested, stopped — and
## asserts the monitor's own printed lines at each one. What is being proved:
##
## - perfusion is computed on every read from blood volume, open vessels, the
##   spine, the heart and the loss still running out of the body, and a field
##   written directly changes it at once because nothing is cached;
## - the pulse is derived the same way — resting on a whole body, faster while
##   it compensates, faltering when the reserve runs out, and none at all once
##   the pump has stopped;
## - oxygen is the one value `Perfusion` remembers, and it falls behind
##   perfusion because delivery is flow times the carriers blood still has;
## - an arrest is a real state the monitor can print, entered through the
##   existing `go_down()` door rather than a death rule invented for it, and
##   the downed resolution's own pulse trace reads the reserve;
## - stopping the bleeding and replacing what was lost brings both numbers back.
##
## Headless it asserts. Windowed it also writes
## `P:/GameDev/Temp/perfusion_monitor.png`, so the panel can be looked at rather
## than only measured — the rule in `wof-verify-by-looking`.

const MedicalMonitor := preload("res://systems/medical_monitor.gd")
const DownedResolution := preload("res://systems/downed_resolution.gd")
const OUT := "P:/GameDev/Temp/perfusion_monitor.png"

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


## The anatomy's own tick, stepped by the test rather than by the tree: the walk
## is then the same on every machine instead of a real-time race.
func step(anatomy: AnatomyComponent, seconds: float) -> void:
	var dt := 0.1
	for _tick in roundi(seconds / dt):
		anatomy._process(dt)


## The tallest sample in a trace, so a flattening line can be measured.
func trace_peak(trace: Array) -> float:
	var peak := 0.0
	for value in trace:
		peak = maxf(peak, absf(float(value)))
	return peak


## The panel as the player reads it, drawn by the production painter so the
## capture cannot drift from the screen.
class ReadoutPanel extends Control:
	const Monitor := preload("res://systems/medical_monitor.gd")
	var body: Node

	func _draw() -> void:
		Monitor.paint(self, Vector2(40, 34), body, 1.0)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	RenderingServer.set_default_clear_color(Color("11100e"))
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.6, 0.0)
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.85, 1.3, 1.75)
	camera.look_at(Vector3(0, 0.98, 0), Vector3.UP)
	# Framed so the body sits clear of the panel, not underneath it.
	camera.h_offset = -0.5
	var body := BaselineHuman.new()
	add_child(body)
	# No gore on this one: the test is about numbers, and a severed arm's chunks
	# are physics the walk does not need.
	body.build("vitals", {"gore": false})
	await get_tree().physics_frame
	var anatomy := body.anatomy
	# The tree must not tick the anatomy while the test does, or the walk would
	# be a mixture of two clocks.
	anatomy.set_process(false)

	# --- 1. whole: a full reserve and full flow ------------------------------
	var lines: Array = MedicalMonitor.lines(body)
	print("WHOLE ", lines)
	check(line_starting(lines, "O2 ") == "O2 100%  PERF 100%", "a whole body reads full oxygen and full flow (%s)" % line_starting(lines, "O2 "))
	check(anatomy.perfusion_pct() == 100 and anatomy.oxygen_pct() == 100, "and the anatomy's own numbers agree")
	check(line_starting(lines, "PULSE ") == "PULSE 62 BPM", "a whole body beats at rest (%s)" % line_starting(lines, "PULSE "))
	var resting_pulse := anatomy.pulse_bpm()
	check(resting_pulse == 62, "and the anatomy's own rate is the same number (%d BPM)" % resting_pulse)
	check(not str(lines[0]).contains("DOWN"), "with nothing downed about it (%s)" % lines[0])
	# The common case has to be free: a body nobody has hurt must not enter the
	# model at all.
	check(not bool(anatomy.vitals.advance(anatomy, 0, 1.0)), "an intact body is one compare and out of the model")
	# No cached copy anywhere: writing the field the simulation writes moves the
	# readout on the very next call.
	anatomy.blood_remaining = anatomy.blood_capacity * 0.5
	check(anatomy.perfusion_pct() < 100, "perfusion is derived on read, not cached (%d%%)" % anatomy.perfusion_pct())
	anatomy.blood_remaining = anatomy.blood_capacity
	check(anatomy.perfusion_pct() == 100, "and comes back with the blood")

	# --- the three inputs the model is derived from, one at a time -----------
	# A stump shunts blood away from what is still attached.
	body.severed.append("left_arm")
	check(anatomy.perfusion_pct() < 100 and anatomy.perfusion_pct() > 80,
		"an open vessel costs flow while the body still has blood (%d%%)" % anatomy.perfusion_pct())
	body.severed.clear()
	# A severed column is no vasomotor tone: pressure falls with the blood still
	# in the body.
	anatomy.organs["spine"]["ruptured"] = true
	check(anatomy.perfusion_pct() <= 55, "a ruptured spine collapses flow (%d%%)" % anatomy.perfusion_pct())
	anatomy.organs["spine"]["ruptured"] = false
	check(anatomy.perfusion_pct() == 100, "and an intact one restores it")

	# --- 2. bleeding: both numbers fall, delivery below flow -----------------
	var wound: Dictionary = body.hit("left_arm", 60.0, 10.0, "cut")
	check(bool(wound.get("severed", false)) and body.severed.size() == 1,
		"the blow takes the arm and leaves an open vessel")
	check(anatomy.bleed_rate > 10.0, "which bleeds hard (%.1f mL/s)" % anatomy.bleed_rate)
	step(anatomy, 100.0)
	var bleeding_perf := anatomy.perfusion_pct()
	var bleeding_oxygen := anatomy.oxygen_pct()
	check(anatomy.blood_remaining < anatomy.blood_capacity * 0.75, "a hundred seconds of that is a fifth of the body (%.2f L left)" % (anatomy.blood_remaining / 1000.0))
	check(bleeding_perf < 80 and bleeding_perf > 20, "flow has fallen but not stopped (%d%%)" % bleeding_perf)
	check(bleeding_oxygen < bleeding_perf, "oxygen has fallen further than flow: delivery is flow times carriers (%d%% < %d%%)" % [bleeding_oxygen, bleeding_perf])
	lines = MedicalMonitor.lines(body)
	print("BLEEDING ", lines)
	check(line_starting(lines, "O2 ") == "O2 %d%%  PERF %d%%" % [bleeding_oxygen, bleeding_perf],
		"the screen prints the body's own two numbers (%s)" % line_starting(lines, "O2 "))
	var bleeding_pulse := anatomy.pulse_bpm()
	check(bleeding_pulse > resting_pulse,
		"and the heart is working harder for what is left (%d > %d BPM)" % [bleeding_pulse, resting_pulse])
	check(line_starting(lines, "PULSE ") == "PULSE %d BPM" % bleeding_pulse,
		"which the screen prints (%s)" % line_starting(lines, "PULSE "))

	# --- 3. arrested: the pump stops, the reserve spends itself ---------------
	anatomy.damage_organ("heart", 999.0)
	step(anatomy, 14.0)
	var arrested_perf := anatomy.perfusion_pct()
	var arrested_oxygen := anatomy.oxygen_pct()
	lines = MedicalMonitor.lines(body)
	print("ARRESTED ", lines)
	check(anatomy.downed and not anatomy.dead, "a stopped heart puts the body down alive, through the existing door")
	check(arrested_perf <= 6, "with almost no flow left (%d%%)" % arrested_perf)
	check(arrested_oxygen <= 10 and arrested_oxygen < bleeding_oxygen, "and the reserve spent down to it (%d%%)" % arrested_oxygen)
	check(str(lines[0]).ends_with("DOWN"), "the monitor says so in its header (%s)" % lines[0])
	check(line_starting(lines, "O2 ") == "O2 %d%%  PERF %d%%" % [arrested_oxygen, arrested_perf],
		"and prints the arrest rather than hiding it (%s)" % line_starting(lines, "O2 "))
	check(anatomy.pulse_bpm() == 0 and line_starting(lines, "PULSE ") == "PULSE NONE",
		"a stopped heart has no beat to find (%s)" % line_starting(lines, "PULSE "))

	# The reserve reaches the downed resolution's own trace, which is the other
	# existing reader of a failing body — no new UI, no second number.
	var sheet: Control = DownedResolution.new()
	# The buffer `_ready()` would give it; the sheet is driven here without being
	# put on screen, since the claim is about the trace and not the layout.
	sheet._trace.resize(150)
	sheet.anatomy = {"consciousness": 100.0, "bleed_rate": 20.0, "oxygen": 100.0}
	for _beat in 40:
		sheet.clock += 0.05
		sheet._advance_trace(0.05)
	var strong := trace_peak(sheet._trace)
	sheet.anatomy = {"consciousness": 100.0, "bleed_rate": 20.0, "oxygen": 5.0}
	for _beat in 40:
		sheet.clock += 0.05
		sheet._advance_trace(0.05)
	var gasping := trace_peak(sheet._trace)
	sheet.free()
	check(gasping < strong * 0.5, "the downed sheet's pulse flattens as the reserve does (%.2f < %.2f)" % [gasping, strong])

	# --- 4. stopped: the repair seam and a closed wound; both come back ------
	anatomy.replace_organ("heart")
	anatomy.bleed_rate = 0.0
	anatomy.internal_bleed_rate = 0.0
	step(anatomy, 10.0)
	var stopped_perf := anatomy.perfusion_pct()
	var stopped_oxygen := anatomy.oxygen_pct()
	check(stopped_perf > arrested_perf, "closing the wound restores flow at once (%d%% > %d%%)" % [stopped_perf, arrested_perf])
	check(stopped_oxygen > arrested_oxygen, "and the reserve climbs back (%d%% > %d%%)" % [stopped_oxygen, arrested_oxygen])
	check(stopped_oxygen < 100, "but a body that lost half its blood never gets all of it back (%d%%)" % stopped_oxygen)
	# The existing resolution seam, not a new revive.
	anatomy.stabilise()
	lines = MedicalMonitor.lines(body)
	print("STOPPED ", lines)
	check(not anatomy.downed and not str(lines[0]).contains("DOWN"), "sparing brings the body up (%s)" % lines[0])
	check(line_starting(lines, "O2 ") == "O2 %d%%  PERF %d%%" % [stopped_oxygen, stopped_perf],
		"with the recovered numbers still the body's own (%s)" % line_starting(lines, "O2 "))
	check(anatomy.pulse_bpm() > 0 and line_starting(lines, "PULSE ").ends_with("BPM"),
		"and a replaced heart beats again (%s)" % line_starting(lines, "PULSE "))
	# The falter: same body, same flow, only the reserve moved. A body nearly out
	# of oxygen beats slower than one that is merely short of it, which is the
	# reading that says stop fighting and start treating.
	var kept_oxygen := anatomy.vitals.oxygen
	anatomy.vitals.oxygen = 60.0
	var short_of_breath := anatomy.pulse_bpm()
	anatomy.vitals.oxygen = 8.0
	var faltering := anatomy.pulse_bpm()
	anatomy.vitals.oxygen = kept_oxygen
	check(faltering < short_of_breath,
		"a body nearly out of oxygen goes slow before it goes quiet (%d < %d BPM)" % [faltering, short_of_breath])
	# And the reserve travels with the body the way dose does.
	check(is_equal_approx(float(body.snapshot().get("oxygen", -1.0)), snappedf(anatomy.vitals.oxygen, 0.1)),
		"the reserve is in the snapshot, so a carried body arrives short of breath")

	# --- look at it, when there is a screen to look with ---------------------
	if DisplayServer.get_name() != "headless":
		var panel := ReadoutPanel.new()
		panel.body = body
		panel.size = Vector2(560, 260)
		# The screen's type is set for a field display at arm's length; scaled up
		# here so the capture can be read rather than squinted at.
		panel.scale = Vector2(1.4, 1.4)
		add_child(panel)
		panel.queue_redraw()
		for _frame in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(OUT)
		print("CAPTURE ", OUT, " error=", error)

	print("VITALS_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
