extends Node3D

## The bench. The gore sandbox with TouchDesigner wired into its look.
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


func _process(_delta: float) -> void:
	if readout != null and is_instance_valid(readout):
		readout.queue_redraw()


func _paint() -> void:
	if not shown:
		return
	var bone := Color("ead4ad")
	var acid := Color("9bf01a")
	var rust := Color("b0552a")
	var dead := Color("7a3b3b")
	var y := 96.0
	var x := 26.0

	CellOutzType.draw_condensed(readout, Vector2(x, y), "TOUCHDESIGNER", 13.0, bone * Color(1, 1, 1, 0.75), 3.0)
	y += 20.0
	if bridge != null and bridge.listening:
		CellOutzType.draw_condensed(readout, Vector2(x, y), "LISTENING	UDP %d" % port, 10.0, acid * Color(1, 1, 1, 0.8), 2.0)
	else:
		# The failure that costs the most time, said plainly.
		CellOutzType.draw_condensed(readout, Vector2(x, y), "PORT %d NOT OPEN" % port, 10.0, dead, 2.0)
	y += 16.0
	CellOutzType.draw_condensed(readout, Vector2(x, y), "PACKETS  %05d" % packets, 10.0,
		(acid if packets > 0 else dead) * Color(1, 1, 1, 0.8), 2.0)
	y += 16.0
	if packets == 0 and bridge != null and bridge.listening:
		CellOutzType.draw_condensed(readout, Vector2(x, y), "NOTHING ARRIVING YET", 9.0, bone * Color(1, 1, 1, 0.35), 2.0)
		y += 14.0
		CellOutzType.draw_condensed(readout, Vector2(x, y), "RUN tools/touchdesigner/build_psy_dials.py", 9.0, bone * Color(1, 1, 1, 0.35), 1.6)
		y += 14.0
		CellOutzType.draw_condensed(readout, Vector2(x, y), "IN THE TEXTPORT  (ALT+T)", 9.0, bone * Color(1, 1, 1, 0.35), 1.6)

	y += 12.0
	for line: String in recent:
		CellOutzType.draw_condensed(readout, Vector2(x, y), line, 9.0, rust * Color(1, 1, 1, 0.8), 1.8)
		y += 13.0

	# What the shader is actually set to, which is not always what was sent —
	# a dial this build does not have is dropped on the way in.
	if rig != null and is_instance_valid(rig):
		var right := readout.size.x - 26.0
		var dial_y := 96.0
		CellOutzType.draw_condensed(readout, Vector2(right - CellOutzType.width_condensed("SHADER", 13.0, 3.0), dial_y),
			"SHADER", 13.0, bone * Color(1, 1, 1, 0.75), 3.0)
		dial_y += 20.0
		for key: String in PsychedelicRig.NEUTRAL:
			var value := rig.dial(key)
			var neutral := absf(value - float(PsychedelicRig.NEUTRAL[key])) < 0.0001
			var line := "%s	 %.3f" % [key.to_upper().replace("_", " "), value]
			var width := CellOutzType.width_condensed(line, 9.0, 1.8)
			CellOutzType.draw_condensed(readout, Vector2(right - width, dial_y), line, 9.0,
				(bone * Color(1, 1, 1, 0.3)) if neutral else acid, 1.8)
			dial_y += 13.0

	CellOutzType.draw_condensed(readout, Vector2(x, readout.size.y - 44.0), "F1", 10.0, rust, 2.0)
	CellOutzType.draw_condensed(readout, Vector2(x + 20.0, readout.size.y - 44.0), "HIDE THIS", 9.0, bone * Color(1, 1, 1, 0.5), 1.6)
