extends Node3D

## The bench, now the fighting sandbox (Greg, 29 September: "reworked to be
## a combat testing and fighting sandbox"). The gore sandbox underneath, with
## sparring partners that strike with what they hold, a readout down the left
## that measures every frame against 160 fps, and TouchDesigner still wired in.
##
## FINAL_V.md §16: TD is the lab, Godot is the engine, and Path C is the live
## link that stops porting a TD graph from being an afternoon. This scene is
## Path C standing up — the sandbox underneath so there is something violent to
## look at, `PsychedelicRig` over the top so there is something to change, and
## `OSCBridge` listening so TouchDesigner can change it while you watch.
##
## The readout down the left is the part that matters when it is not working.
## A bridge that silently receives nothing looks exactly like a bridge that is
## receiving zeros, and the difference is half an hour of your life, so this
## says out loud whether the port opened, how many packets have arrived, and
## what the last few of them said.
##
## Nothing here ships. `Start-PsyLab.ps1` opens it; the game does not.

const DEMO := preload("res://gore_demo.tscn")
const RIG := preload("res://systems/psychedelic_rig.gd")
const BRIDGE := preload("res://systems/osc_bridge.gd")
const CellOutzType := preload("res://systems/celloutz_type.gd")

var demo: Node3D
var rig: PsychedelicRig
var bridge: OSCBridge
var readout: Control

var port := OSCBridge.DEFAULT_PORT
var packets := 0
var recent: Array[String] = []
var shown := true
## 160 fps is 6.25 ms a frame (Greg, 29 September).
const BUDGET_MS := 1000.0 / 160.0
var _frame_ms := 0.0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--osc-port="):
			port = int(argument.trim_prefix("--osc-port="))

	demo = DEMO.instantiate() as Node3D
	add_child(demo)

	# Over the sandbox and over the sandbox's own HUD. The shader samples what
	# was drawn before it in the frame, so "later" is the whole requirement.
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	rig = RIG.new()
	layer.add_child(rig)

	bridge = BRIDGE.new()
	add_child(bridge)
	bridge.drive(rig)
	bridge.message.connect(_on_message)
	bridge.listen(port)

	var top := CanvasLayer.new()
	top.layer = 3
	add_child(top)
	readout = Control.new()
	readout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.draw.connect(_paint)
	top.add_child(readout)
	set_process(true)
	# The GPU's own time, not frame minus script: the split that says where
	# a slow frame actually goes.
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _on_message(address: String, args: Array) -> void:
	packets += 1
	var value := ""
	if not args.is_empty():
		value = "%.3f" % float(args[0]) if args[0] is float else str(args[0])
	recent.push_front("%s  %s" % [address.get_file().to_upper().replace("_", " "), value])
	while recent.size() > 12:
		recent.pop_back()


func _input(event: InputEvent) -> void:
	# Not `_unhandled_input`: the sandbox underneath already owns that, and this
	# is a readout rather than a verb. Held on its own key so a capture of the
	# look is not a capture of the diagnostics on top of it.
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_F1:
			shown = not shown


func _process(delta: float) -> void:
	_frame_ms = lerpf(_frame_ms, delta * 1000.0, 0.1)
	# Greg, 30 September (the sandbox frame rate): this readout was redrawn
	# every frame, and CellOutzType draws each glyph as polygons, so the thing
	# measuring the frame was 4.6 of its 10 ms (tests/psy_lab_perf). Numbers
	# read at five a second.
	_repaint_clock += delta
	if _repaint_clock >= READOUT_PERIOD and readout != null and is_instance_valid(readout):
		_repaint_clock = 0.0
		readout.queue_redraw()


const READOUT_PERIOD := 0.2
var _repaint_clock := 0.0


func _paint() -> void:
	if not shown:
		return
	var bone := Color("ead4ad")
	var acid := Color("9bf01a")
	var rust := Color("b0552a")
	var dead := Color("7a3b3b")
	var x := 26.0
	var y := 96.0
	var rid := get_viewport().get_viewport_rid()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var lines: Array = [
		["COMBAT SANDBOX", 13.0, bone * Color(1, 1, 1, 0.75)],
		["FRAME  %5.2f MS  %4d FPS  / 6.25" % [_frame_ms, roundi(1000.0 / maxf(_frame_ms, 0.01))], 10.0, acid if _frame_ms <= BUDGET_MS else rust],
		["GPU %5.2f   SCRIPT %5.2f   PHYSICS %5.2f" % [gpu, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0], 10.0, bone * Color(1, 1, 1, 0.7)],
		["DRAWS %d   PRIMS %.2fM" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000000.0], 10.0, bone * Color(1, 1, 1, 0.7)],
	]
	if demo != null and is_instance_valid(demo):
		var sandbox = demo
		var standing := 0
		for entry: Dictionary in sandbox.bodies:
			var body := entry.get("rig") as BaselineHuman
			if body != null and is_instance_valid(body) and not body.anatomy.dead and not body.anatomy.downed:
				standing += 1
		var mode: String = "ENEMIES // %s" % str(sandbox.SPAR_LEVELS[sandbox.spar_level].name) if sandbox.enemies_enabled else "DUMMIES"
		lines.append(["%s   STANDING %d/%d   SIM HEALTH %03d" % [mode, standing, sandbox.bodies.size(), sandbox.simulation_health], 10.0, bone * Color(1, 1, 1, 0.7)])
	lines.append(["TD UDP %d  %s  PACKETS %05d" % [port, "OPEN" if bridge != null and bridge.listening else "CLOSED", packets], 9.0,
		(acid if packets > 0 else dead) * Color(1, 1, 1, 0.6)])
	for line: Array in lines:
		CellOutzType.draw_condensed(readout, Vector2(x, y), str(line[0]), float(line[1]), line[2], 2.0)
		y += float(line[1]) + 8.0
	var keys := "V 3RD PERSON  Z LOCK  LMB SWING / HOLD HEAVY  SPACE ROLL  RMB GUARD  H ENEMIES  N DIFFICULTY  R RESPAWN  X XRAY  F1 HIDE"
	CellOutzType.draw_condensed(readout, Vector2(x, readout.size.y - 44.0), keys, 9.0, bone * Color(1, 1, 1, 0.5), 1.6)
