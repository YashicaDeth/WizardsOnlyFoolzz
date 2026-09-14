class_name PsychedelicOSC
extends Node

## DESIGN/FINAL_V.md §16, Path C: a live link so a TouchDesigner patch can
## dial `psychedelic_rig.gd`'s uniforms while Greg (or Astra, driving the
## hellscape/angelscape planes through the same six dials) works out a look —
## "nothing from Path C ships." Gated through `DevAffordances`, the project's
## one switch for tooling that exercises a build rather than plays it, and
## opt-in even then via `--osc` — a UDP socket has no business trying to bind
## on every ordinary headless test run.
##
## Deliberately not full OSC: one message, one address, one float argument.
## Bundles, multiple arguments and every other OSC type are more than a dev
## dial bridge needs, and the whole point of Path C is that porting a TD graph
## stays a five-minute job, not a networking project.

const PORT := 9001

var _socket := PacketPeerUDP.new()
var _rig: WeakRef


func _ready() -> void:
	if not (DevAffordances.available() and DevAffordances.accepts_command_line("--osc")):
		queue_free()
		return
	var error := _socket.bind(PORT)
	if error != OK:
		push_warning("PsychedelicOSC: could not bind UDP %d (%s)" % [PORT, error_string(error)])
		queue_free()
		return
	set_process(true)


## The rig this bridge writes into. Held as a weak reference so a rig that
## goes away (a scene reload) does not keep this node from freeing it.
func attach(rig: Control) -> void:
	_rig = weakref(rig)


func _process(_delta: float) -> void:
	while _socket.get_available_packet_count() > 0:
		_dispatch(_socket.get_packet())


## Split out from `_process` so a test can hand it bytes directly without a
## real socket in the loop.
func _dispatch(packet: PackedByteArray) -> void:
	var message := _parse_osc(packet)
	if message.is_empty():
		return
	var rig: Control = _rig.get_ref() if _rig != null else null
	if rig != null and rig.has_method("set_dial"):
		rig.set_dial(str(message.address).trim_prefix("/"), float(message.value))


## `/some/address` + type tag `,f` + one big-endian float32, each field
## null-terminated and padded to a 4-byte boundary per the OSC 1.0 spec.
## Anything that does not match that exact shape is ignored rather than
## guessed at — a malformed dev packet should do nothing, not do the wrong
## thing.
func _parse_osc(packet: PackedByteArray) -> Dictionary:
	var address_end := packet.find(0)
	if address_end <= 0:
		return {}
	var address := packet.slice(0, address_end).get_string_from_ascii()
	var tags_start := ((address_end + 4) / 4) * 4
	if tags_start >= packet.size() or packet[tags_start] != 44: # ','
		return {}
	var tags_end := packet.find(0, tags_start)
	if tags_end <= 0:
		return {}
	var tags := packet.slice(tags_start, tags_end).get_string_from_ascii()
	if tags != ",f":
		return {}
	var value_start := ((tags_end + 4) / 4) * 4
	if value_start + 4 > packet.size():
		return {}
	var value_bytes := packet.slice(value_start, value_start + 4)
	value_bytes.reverse() # OSC floats are big-endian; Godot decodes little-endian.
	return {"address": address, "value": value_bytes.decode_float(0)}
