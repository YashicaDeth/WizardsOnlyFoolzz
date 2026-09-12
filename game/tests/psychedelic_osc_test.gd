extends Node

## FINAL_V.md §16, Path C. Never bound to a socket in a normal test run —
## `_ready()`'s own gate gets exercised by never adding this to the tree with
## `--osc` on the command line — but the wire parsing has to be right, because
## a live TD patch is the one thing that will actually exercise it.

const OSC := preload("res://systems/psychedelic_osc.gd")
const RIG := preload("res://systems/psychedelic_rig.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## One null terminator, always, then more nulls until the length is a
## multiple of 4 — the OSC padding rule, applied the same way to both the
## address and the type-tag string.
func _pad4(raw: PackedByteArray) -> PackedByteArray:
	var out := raw.duplicate()
	out.append(0)
	while out.size() % 4 != 0:
		out.append(0)
	return out


## Builds a real OSC message: an address, `,f`, and one big-endian float,
## each field null-terminated and padded to a 4-byte boundary — by the spec's
## own rule, not by copying `_parse_osc`'s offsets back at it.
func _build_osc(address: String, value: float) -> PackedByteArray:
	var packet := _pad4(address.to_ascii_buffer())
	packet.append_array(_pad4(",f".to_ascii_buffer()))
	var value_bytes := PackedByteArray()
	value_bytes.resize(4)
	value_bytes.encode_float(0, value)
	value_bytes.reverse()
	packet.append_array(value_bytes)
	return packet


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# Not added to the scene tree, so `_ready()`'s own dev-gate never runs and
	# no socket is ever touched — only the parser is under test here.
	var bridge: Node = OSC.new()

	var packet := _build_osc("/lut_strength", 0.75)
	var message: Dictionary = bridge._parse_osc(packet)
	check(str(message.get("address", "")) == "/lut_strength", "the address decodes intact (%s)" % message.get("address", ""))
	check(absf(float(message.get("value", -1.0)) - 0.75) < 0.0001, "and the float survives the round trip (%s)" % message.get("value", "?"))

	var longer := _build_osc("/feedback_zoom", 1.25)
	var longer_message: Dictionary = bridge._parse_osc(longer)
	check(str(longer_message.get("address", "")) == "/feedback_zoom", "a longer address that lands exactly on a 4-byte boundary still decodes")
	check(absf(float(longer_message.get("value", -1.0)) - 1.25) < 0.0001, "with its own value intact (%s)" % longer_message.get("value", "?"))

	check(bridge._parse_osc(PackedByteArray()).is_empty(), "an empty packet is ignored, not crashed on")
	check(bridge._parse_osc(PackedByteArray([47, 97, 0, 0])).is_empty(), "a packet with no type tag is ignored")

	# End to end: bytes in, a rig's own dial moved — no socket involved.
	var rig: Control = RIG.new()
	add_child(rig)
	bridge.attach(rig)
	bridge._dispatch(packet)
	check(absf(rig.dial("lut_strength") - 0.75) < 0.0001, "a packet actually moves the attached rig's dial")

	# An address this rig does not recognise is dropped, same as `set_dial`
	# already drops one called directly.
	bridge._dispatch(_build_osc("/not_a_real_dial", 9.0))
	check(not ("not_a_real_dial" in rig._dials), "an unknown dial from the wire is ignored, not adopted")

	if failures.is_empty():
		print("psychedelic OSC: the wire parses right")
		get_tree().quit(0)
	else:
		print("psychedelic OSC FAILURES: ", failures)
		get_tree().quit(1)
