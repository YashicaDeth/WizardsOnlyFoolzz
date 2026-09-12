class_name OSCBridge
extends Node

## FINAL_V.md §16, "What to build first", item 3: the live link.
##
## Greg: *"the one that matters is TouchDesigner, and it's the one that works
## best"*, and FINAL_V already settled what that means — TD is the **lab**,
## Godot is the **engine**. This is the wire between the two while you work.
## You move a slider in TouchDesigner, the game changes in front of you, and
## when the look is right you read the numbers off and write them into a scene.
## Porting a TD graph stops being an afternoon and becomes five minutes.
##
## **It does not ship.** FINAL_V says so twice and it means it: the bridge
## refuses to open a socket in an exported build unless somebody has gone out of
## their way to ask on the command line. A shipped game that listens on a UDP
## port because a development convenience was left switched on is a security
## bug, not a feature, and it would be an easy one to leave in by accident.
##
## OSC itself is four rules: an address that looks like a path, a type tag
## string that starts with a comma, arguments packed big-endian, everything
## padded to a multiple of four bytes. Bundles are a header, a timetag, then
## sized elements. That is the whole format and it is parsed below in full,
## because half-parsing it is how you get a bridge that works with one TD patch
## and silently drops the next one.

## What TouchDesigner's `OSC Out CHOP` points at by default.
const DEFAULT_PORT := 9000
## Anything above this in one frame is a patch stuck in a loop, not a person
## moving a slider. Drained and dropped rather than allowed to stall the frame.
const MAX_PACKETS_PER_FRAME := 256

## Every message that arrived, already parsed. `address` is the OSC path and
## `args` is whatever came with it.
signal message(address: String, args: Array)
## The common case, lifted out so nothing downstream has to unpack an array to
## find the one float it wanted.
signal dial(name: String, value: float)

var port := DEFAULT_PORT
var listening := false
## Everything that has arrived since the scene opened, newest last. Development
## only, capped, and the reason is the tuning loop: when a patch is not moving
## anything you need to see whether the numbers are arriving at all.
var seen: Array[Dictionary] = []

var _socket := PacketPeerUDP.new()


func _ready() -> void:
	name = "OSCBridge"
	# Time is bent on purpose in several scenes and a bridge that polls on the
	# scene clock would deliver TouchDesigner's sliders in slow motion too.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## Open the port. Returns false and says why rather than half-starting.
##
## `force` is the escape hatch for an exported build — it exists so that a
## packaged demo can be driven from TD on a machine you control, and it has to
## be passed deliberately every time.
func listen(on_port := DEFAULT_PORT, force := false) -> bool:
	if listening:
		return true
	if not _development_build() and not force:
		push_warning("OSCBridge: refusing to listen in an exported build. Development only.")
		return false
	port = on_port
	var opened := _socket.bind(port)
	if opened != OK:
		push_warning("OSCBridge: port %d is not available (%d). Is another patch already bound to it?" % [port, opened])
		return false
	listening = true
	set_process(true)
	return true


func stop() -> void:
	if not listening:
		return
	_socket.close()
	listening = false
	set_process(false)


## Point the bridge at a `PsychedelicRig` and every dial that arrives goes
## straight into that dial. This is the whole of the loop FINAL_V is
## describing: TD sends `/psy/kaleidoscope_segments 6`, the screen folds.
##
## `set_dial` ignores names it does not know, so a patch sending a dial this
## build has never heard of is a no-op rather than a crash.
func drive(rig: Node) -> void:
	dial.connect(func(dial_name: String, value: float) -> void:
		if rig == null or not is_instance_valid(rig):
			return
		rig.set_dial(dial_name, value))


func _process(_delta: float) -> void:
	var drained := 0
	while _socket.get_available_packet_count() > 0 and drained < MAX_PACKETS_PER_FRAME:
		drained += 1
		var packet := _socket.get_packet()
		for parsed: Dictionary in parse(packet):
			_deliver(parsed)


func _deliver(parsed: Dictionary) -> void:
	var address := str(parsed.get("address", ""))
	var args: Array = parsed.get("args", [])
	seen.append(parsed)
	if seen.size() > 240:
		seen.pop_front()
	message.emit(address, args)
	# The dial is the last segment of the address, whatever the patch put in
	# front of it: `/psy/feedback_strength` and `/feedback_strength` both name
	# `feedback_strength`. TouchDesigner builds OSC addresses out of CHOP channel
	# names and different versions prefix them differently, so a bridge that
	# insists on exactly one shape is a bridge that works with exactly one patch.
	# Being liberal costs nothing: `set_dial` ignores every name it does not know.
	# Anything arriving without a leading float is an event rather than a dial,
	# and only the raw `message` signal carries it.
	if not args.is_empty() and args[0] is float:
		dial.emit(address.get_file(), float(args[0]))


# ------------------------------------------------------------------ the format
## Parse one datagram into zero or more `{address, args}` dictionaries.
##
## Static and pure, so the format can be tested without opening a socket — which
## matters, because the half of this that breaks in practice is the padding
## arithmetic, not the networking.
static func parse(packet: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_parse_into(packet, 0, packet.size(), out)
	return out


static func _parse_into(data: PackedByteArray, from: int, to: int, out: Array[Dictionary]) -> void:
	if to - from < 4:
		return
	if _read_string(data, from, to).get("text", "") == "#bundle":
		# Header, then a 64-bit timetag, then sized elements. Timetags are
		# ignored: TouchDesigner sends immediates and nothing here schedules.
		var at := from + 16
		while at + 4 <= to:
			var size := _be_s32(data, at)
			at += 4
			if size <= 0 or at + size > to:
				return
			_parse_into(data, at, at + size, out)
			at += size
		return

	var address := _read_string(data, from, to)
	if address.is_empty():
		return
	var at: int = address["next"]
	var tags := _read_string(data, at, to)
	if tags.is_empty():
		return
	at = tags["next"]
	var tag_text := str(tags["text"])
	if not tag_text.begins_with(","):
		# A message with no type tags at all. Ancient, legal, and argument-free.
		out.append({"address": str(address["text"]), "args": []})
		return

	var args: Array = []
	for index in range(1, tag_text.length()):
		match tag_text[index]:
			"f":
				if at + 4 > to:
					return
				args.append(_be_float(data, at))
				at += 4
			"i":
				if at + 4 > to:
					return
				args.append(_be_s32(data, at))
				at += 4
			"d":
				if at + 8 > to:
					return
				args.append(_be_double(data, at))
				at += 8
			"s", "S":
				var text := _read_string(data, at, to)
				if text.is_empty():
					return
				args.append(str(text["text"]))
				at = text["next"]
			"b":
				if at + 4 > to:
					return
				var size := _be_s32(data, at)
				at += 4
				if size < 0 or at + size > to:
					return
				args.append(data.slice(at, at + size))
				at += _padded(size)
			"T":
				args.append(true)
			"F":
				args.append(false)
			"N":
				args.append(null)
			"I":
				args.append(INF)
			_:
				# An argument type this build does not know sits in front of
				# every argument after it, so there is nothing honest to do but
				# keep what was read and stop.
				break
	out.append({"address": str(address["text"]), "args": args})


## OSC strings are null-terminated and then padded with more nulls until the
## total length is a multiple of four. Returns the text and where the next field
## starts, or an empty dictionary if the string runs off the end.
static func _read_string(data: PackedByteArray, from: int, to: int) -> Dictionary:
	var end := from
	while end < to and data[end] != 0:
		end += 1
	if end >= to:
		return {}
	var text := data.slice(from, end).get_string_from_utf8()
	return {"text": text, "next": from + _padded(end - from + 1)}


static func _padded(size: int) -> int:
	return size + ((4 - (size % 4)) % 4)


## Everything in OSC is big-endian and everything in `PackedByteArray` decodes
## little-endian, so every number goes through here.
static func _be_s32(data: PackedByteArray, at: int) -> int:
	var flipped := PackedByteArray([data[at + 3], data[at + 2], data[at + 1], data[at]])
	return flipped.decode_s32(0)


static func _be_float(data: PackedByteArray, at: int) -> float:
	var flipped := PackedByteArray([data[at + 3], data[at + 2], data[at + 1], data[at]])
	return flipped.decode_float(0)


static func _be_double(data: PackedByteArray, at: int) -> float:
	var flipped := PackedByteArray()
	flipped.resize(8)
	for index in 8:
		flipped[index] = data[at + 7 - index]
	return flipped.decode_double(0)


# ------------------------------------------------------------------ the other way
## Build a packet. Godot does not need to send OSC to play the game, but a
## bridge you cannot send through is a bridge you cannot test, and TD is just as
## happy receiving — a game that reports the player's own state back into the
## patch is how you build a visual that reacts to the game rather than at it.
static func encode(address: String, args: Array = []) -> PackedByteArray:
	var packet := PackedByteArray()
	packet.append_array(_write_string(address))
	var tags := ","
	var body := PackedByteArray()
	for argument in args:
		if argument is float:
			tags += "f"
			body.append_array(_write_be_float(float(argument)))
		elif argument is int:
			tags += "i"
			body.append_array(_write_be_s32(int(argument)))
		elif argument is bool:
			tags += "T" if argument else "F"
		elif argument is String:
			tags += "s"
			body.append_array(_write_string(str(argument)))
	packet.append_array(_write_string(tags))
	packet.append_array(body)
	return packet


static func _write_string(text: String) -> PackedByteArray:
	var raw := text.to_utf8_buffer()
	raw.append(0)
	while raw.size() % 4 != 0:
		raw.append(0)
	return raw


static func _write_be_float(value: float) -> PackedByteArray:
	var raw := PackedByteArray()
	raw.resize(4)
	raw.encode_float(0, value)
	return PackedByteArray([raw[3], raw[2], raw[1], raw[0]])


static func _write_be_s32(value: int) -> PackedByteArray:
	var raw := PackedByteArray()
	raw.resize(4)
	raw.encode_s32(0, value)
	return PackedByteArray([raw[3], raw[2], raw[1], raw[0]])


## An exported game is not a lab. `OS.is_debug_build()` is false in an export
## template, `has_feature("editor")` is true only with the editor's own build.
static func _development_build() -> bool:
	return OS.is_debug_build() or OS.has_feature("editor")


func _exit_tree() -> void:
	stop()
