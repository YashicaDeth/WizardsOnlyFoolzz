extends Node

## FINAL_V.md §16 item 3. The bridge is only worth anything if a slider moved in
## TouchDesigner arrives here as the same number, so this checks the wire format
## against hand-counted bytes rather than only against itself — a parser and an
## encoder that agree with each other and with nobody else is the classic way to
## ship an OSC implementation that works with exactly zero real patches.

const BRIDGE := preload("res://systems/osc_bridge.gd")
const RIG := preload("res://systems/psychedelic_rig.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var tree := get_tree()
	tree.create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		print("osc bridge: TIMED OUT")
		tree.quit(3))
	await tree.process_frame

	# ---- the format, counted by hand.
	#
	# "/psy/feedback_strength" is 22 characters, so with its terminator it is 23
	# and pads to 24. ",f" is 2, terminates at 3, pads to 4. One float is 4.
	# Thirty-two bytes, and the float is big-endian: 0.5 is 3F 00 00 00.
	var packet := OSCBridge.encode("/psy/feedback_strength", [0.5])
	check(packet.size() == 32, "a one-float message is thirty-two bytes")
	check(packet[23] == 0, "the address pads out with nulls")
	check(packet[24] == 44 and packet[25] == 102, "the type tag is a comma and an f")
	check(packet[28] == 0x3F and packet[29] == 0x00 and packet[30] == 0x00 and packet[31] == 0x00,
		"and the float is big-endian, not the machine's way round")

	# ---- and read back.
	var parsed := OSCBridge.parse(packet)
	check(parsed.size() == 1, "one message in, one message out")
	check(str(parsed[0]["address"]) == "/psy/feedback_strength", "the address survives")
	check(absf(float((parsed[0]["args"] as Array)[0]) - 0.5) < 0.0001, "so does the value")

	# ---- an address whose length lands exactly on a boundary is the case that
	# breaks naive padding: four characters still need a whole null word.
	var flush := OSCBridge.encode("/psy", [1.0])
	check(flush.size() == 16, "an address that fills its last word still gets a null word")
	var flush_back := OSCBridge.parse(flush)
	check(flush_back.size() == 1 and str(flush_back[0]["address"]) == "/psy",
		"and still reads back")

	# ---- mixed arguments, because TD sends more than floats.
	var mixed := OSCBridge.parse(OSCBridge.encode("/game/state", [3, 0.25, "ASHLINE", true]))
	var args: Array = mixed[0]["args"]
	check(args.size() == 4, "four arguments in, four out")
	check(args[0] is int and int(args[0]) == 3, "an int stays an int")
	check(args[1] is float and absf(float(args[1]) - 0.25) < 0.0001, "a float stays a float")
	check(str(args[2]) == "ASHLINE", "a string survives its own padding")
	check(args[3] == true, "and a true carries no bytes at all")

	# ---- a bundle, which is what an OSC Out CHOP sends when it has more than
	# one channel to report and is the packet a message-only parser drops.
	var one := OSCBridge.encode("/psy/chromatic_offset", [0.02])
	var two := OSCBridge.encode("/psy/cut_intensity", [0.75])
	var bundle := PackedByteArray()
	bundle.append_array("#bundle".to_utf8_buffer())
	bundle.append(0)
	for _timetag in 8:
		bundle.append(0)
	for element: PackedByteArray in [one, two]:
		var size := PackedByteArray()
		size.resize(4)
		size.encode_s32(0, element.size())
		bundle.append_array(PackedByteArray([size[3], size[2], size[1], size[0]]))
		bundle.append_array(element)
	var unbundled := OSCBridge.parse(bundle)
	check(unbundled.size() == 2, "a bundle yields both of its messages")
	check(str(unbundled[1]["address"]) == "/psy/cut_intensity", "in the order they were packed")

	# ---- rubbish does not crash it. A patch mid-edit sends half a packet.
	check(OSCBridge.parse(PackedByteArray([47, 112, 115])).is_empty(), "a truncated address is dropped")
	check(OSCBridge.parse(PackedByteArray()).is_empty(), "so is an empty datagram")
	var starved := OSCBridge.encode("/psy/feedback_strength", [0.5]).slice(0, 30)
	check(OSCBridge.parse(starved).is_empty(), "and so is a message whose float is cut in half")

	# ---- the wire itself.
	var bridge: OSCBridge = BRIDGE.new()
	add_child(bridge)
	var port := 9137
	var opened := bridge.listen(port)
	check(opened, "the bridge opens its port in a development build")
	if not opened:
		_finish(tree)
		return

	var heard: Array = []
	bridge.dial.connect(func(dial_name: String, value: float) -> void:
		heard.append([dial_name, value]))

	var sender := PacketPeerUDP.new()
	sender.set_dest_address("127.0.0.1", port)
	sender.put_packet(OSCBridge.encode("/psy/kaleidoscope_segments", [6.0]))
	var waited := 0
	while heard.is_empty() and waited < 120:
		await tree.process_frame
		waited += 1
	check(not heard.is_empty(), "a packet sent over UDP arrives")
	if not heard.is_empty():
		check(str(heard[0][0]) == "kaleidoscope_segments", "and the prefix is stripped off the dial name")
		check(absf(float(heard[0][1]) - 6.0) < 0.0001, "with the value intact")

	# ---- and it reaches the shader, which is the only reason any of this exists.
	var rig: PsychedelicRig = RIG.new()
	add_child(rig)
	await tree.process_frame
	bridge.drive(rig)
	sender.put_packet(OSCBridge.encode("/psy/chromatic_offset", [0.03]))
	waited = 0
	while absf(rig.dial("chromatic_offset") - 0.03) > 0.0001 and waited < 120:
		await tree.process_frame
		waited += 1
	check(absf(rig.dial("chromatic_offset") - 0.03) < 0.0001,
		"a slider in TouchDesigner moves a dial in the shader")

	# ---- and it does not care how the patch spelled the address. TD versions
	# differ on what they put in front of a channel name; the dial is the last
	# segment either way.
	sender.put_packet(OSCBridge.encode("/cut_intensity", [0.6]))
	waited = 0
	while absf(rig.dial("cut_intensity") - 0.6) > 0.0001 and waited < 120:
		await tree.process_frame
		waited += 1
	check(absf(rig.dial("cut_intensity") - 0.6) < 0.0001,
		"a bare address with no prefix lands on the same dial")
	sender.put_packet(OSCBridge.encode("/anything/you/like/lut_strength", [0.4]))
	waited = 0
	while absf(rig.dial("lut_strength") - 0.4) > 0.0001 and waited < 120:
		await tree.process_frame
		waited += 1
	check(absf(rig.dial("lut_strength") - 0.4) < 0.0001,
		"and so does one buried under a path nobody planned for")

	# ---- a dial this build has never heard of is ignored, not fatal.
	sender.put_packet(OSCBridge.encode("/psy/nonsense_dial", [1.0]))
	for _frame in 12:
		await tree.process_frame
	check(true, "an unknown dial name does not bring the scene down")

	# ---- and it lets go of the port.
	bridge.stop()
	check(not bridge.listening, "the bridge closes when told to")
	var reopened := PacketPeerUDP.new()
	check(reopened.bind(port) == OK, "and the port is genuinely free afterwards")
	reopened.close()

	_finish(tree)


func _finish(tree: SceneTree) -> void:
	if failures.is_empty():
		print("osc bridge: open")
		tree.quit(0)
	else:
		print("osc bridge FAILURES: ", failures)
		tree.quit(1)
