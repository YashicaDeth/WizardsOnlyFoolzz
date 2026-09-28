class_name OpeningAudio
extends Node

## G6.2. The Growing Floor has its own sound grammar: a wet electrical room
## under the tank, the player's pulse inside it, then short mechanical events
## that belong to the drain, glass and door rather than one generic sting.
## These generated sounds are original placeholders and stay behind the same
## calls when authored recordings replace them.

const RATE := 22050

var room: AudioStreamPlayer
var pulse: AudioStreamPlayer
var cue_voice: AudioStreamPlayer
var played_cues: Array[String] = []


func _ready() -> void:
	room = _player("GrowingFloorRoom", _wave("room", 4.0, true), "Ambience", -25.0)
	pulse = _player("InsidePulse", _wave("pulse", 1.2, true), "SFX", -17.0)
	cue_voice = _player("OpeningCue", null, "SFX", -8.0)
	room.play()
	pulse.play()


func set_phase(phase_name: String, amount: float = 0.0) -> void:
	if room == null:
		return
	match phase_name:
		"intake":
			room.pitch_scale = 0.78
			pulse.volume_db = -15.0
		"submerged":
			room.pitch_scale = 0.84 + amount * 0.05
			pulse.volume_db = lerpf(-15.0, -11.0, amount)
		"voiding":
			room.pitch_scale = 0.92 + amount * 0.18
			pulse.volume_db = lerpf(-11.0, -23.0, amount)
		"wired":
			# Out of the fluid the room goes thin and the pulse is all there is.
			room.pitch_scale = 0.7
			pulse.volume_db = -8.0
		_:
			room.pitch_scale = 1.0
			pulse.volume_db = -34.0


func cue(kind: String) -> void:
	played_cues.append(kind)
	if cue_voice == null:
		return
	cue_voice.stream = _wave(kind, {"drain": 0.85, "revenge": 1.4, "tap": 0.25}.get(kind, 0.55), false)
	cue_voice.volume_db = -5.0 if kind in ["glass", "rip", "revenge", "tap"] else -9.0
	cue_voice.play()


func _player(node_name: String, stream: AudioStream, bus_name: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	player.volume_db = volume
	if AudioServer.get_bus_index(bus_name) != -1:
		player.bus = bus_name
	add_child(player)
	return player


func _wave(kind: String, duration: float, looping: bool) -> AudioStreamWAV:
	var frame_count := roundi(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for frame in frame_count:
		var t := float(frame) / RATE
		var sample := 0.0
		match kind:
			"room":
				var hum := sin(TAU * 38.0 * t) * 0.28 + sin(TAU * 61.0 * t) * 0.12
				var wet := sin(TAU * (2.1 + sin(t * 0.7)) * t) * 0.08
				sample = hum * (0.76 + wet) + (_noise(frame) - 0.5) * 0.035
			"pulse":
				var beat := fmod(t, 1.2)
				var first := exp(-beat * 18.0) * sin(TAU * 48.0 * beat)
				var second_t := maxf(0.0, beat - 0.22)
				var second := exp(-second_t * 24.0) * sin(TAU * 56.0 * second_t) if beat >= 0.22 else 0.0
				sample = first * 0.55 + second * 0.32
			"drain":
				var fall := lerpf(170.0, 43.0, t / duration)
				sample = sin(TAU * fall * t) * 0.32 + (_noise(frame * 3) - 0.5) * 0.4
				sample *= sin(clampf(t / duration, 0.0, 1.0) * PI)
			"glass":
				var envelope := exp(-t * 9.0)
				sample = ((_noise(frame * 7) * 2.0 - 1.0) * 0.65 + sin(TAU * 2460.0 * t) * 0.25) * envelope
			"tug":
				# Something elastic under load, and it is attached to you.
				var stretch := lerpf(62.0, 88.0, t / duration)
				sample = sin(TAU * stretch * t) * 0.5 * exp(-t * 4.0) + (_noise(frame * 5) - 0.5) * 0.12 * exp(-t * 6.0)
			"rip":
				var tear := exp(-t * 7.0)
				sample = ((_noise(frame * 11) * 2.0 - 1.0) * 0.7 + sin(TAU * 140.0 * t) * 0.3) * tear
			"revenge":
				var swell := minf(1.0, t * 12.0) * exp(-t * 2.2)
				sample = (sin(TAU * 41.0 * t) * 0.6 + sin(TAU * 61.5 * t) * 0.25 + (_noise(frame) - 0.5) * 0.1) * swell
			"tap":
				# A knuckle on thick glass, heard from inside the fluid: a dull
				# knock with the ring taken out of it.
				var knock := exp(-t * 38.0)
				sample = (sin(TAU * 170.0 * t) * 0.7 + sin(TAU * 410.0 * t) * 0.18 + (_noise(frame * 9) - 0.5) * 0.3 * exp(-t * 90.0)) * knock
			"door":
				var envelope := exp(-t * 5.0)
				sample = (sin(TAU * 51.0 * t) * 0.62 + sin(TAU * 93.0 * t) * 0.2) * envelope
			_:
				sample = sin(TAU * 110.0 * t) * exp(-t * 8.0) * 0.25
		var value := clampi(roundi(clampf(sample, -1.0, 1.0) * 32760.0), -32768, 32767)
		if value < 0:
			value += 65536
		bytes[frame * 2] = value & 0xff
		bytes[frame * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frame_count
	return stream


func _noise(value: int) -> float:
	var n := value * 1103515245 + 12345
	n = (n >> 16) & 0x7fff
	return float(n) / 32767.0
