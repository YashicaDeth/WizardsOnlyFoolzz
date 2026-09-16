class_name BlackMirrorTransitionAudio
extends Node

## Three temporary sound sketches for the Black Mirror comparison. They share
## one 0.52-second envelope so visual timing, page activation and sound can be
## judged without one candidate winning by simply being longer or louder.
## These generated waves are timing concepts, not final authored recordings.

const AudioRouting := preload("res://systems/audio_bus.gd")
const RATE := 22050
const DURATION := 0.52
const STYLES := ["shutter", "corruption", "carousel"]

var voice: AudioStreamPlayer
var last_style := ""
var played_styles: Array[String] = []
var _streams: Dictionary = {}


func _ready() -> void:
	# Headless contract tests inspect `profile()` and the emitted style; building
	# three PCM buffers there only leaves audio-server references at forced tree
	# shutdown. Runtime and capture scenes still build and play the real sketches.
	if OS.get_environment("ATG_TEST_MODE") == "1":
		return
	AudioRouting.ensure()
	voice = AudioStreamPlayer.new()
	voice.name = "PageMovementVoice"
	# A comparison reel must make the material legible on laptop speakers. This
	# remains below action SFX and is replaced by an authored mix after selection.
	voice.volume_db = -5.0
	add_child(voice)
	AudioRouting.route(voice, AudioRouting.SFX)
	for style in STYLES:
		_streams[style] = _wave(style)


func play_transition(style: String) -> void:
	var candidate := style.to_lower()
	if not STYLES.has(candidate):
		candidate = "shutter"
	last_style = candidate
	played_styles.append(candidate)
	if voice == null or _streams.is_empty():
		return
	voice.stream = _streams.get(candidate, _streams.get("shutter"))
	voice.play()


func profile(style: String) -> Dictionary:
	var candidate := style.to_lower()
	if not STYLES.has(candidate):
		candidate = "shutter"
	return {
		"style": candidate,
		"duration": DURATION,
		"sample_rate": RATE,
		"digital_tear": true,
		"glass_resonance": true,
		"material": {
			"shutter": "ratchet and dragging rib",
			"corruption": "packet chatter and torn decode",
			"carousel": "indexed wheel and detuned bell",
		}[candidate],
		"authored_replacement_required": true,
	}


func _wave(style: String) -> AudioStreamWAV:
	var frame_count := roundi(DURATION * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for frame in frame_count:
		var t := float(frame) / RATE
		var phase := t / DURATION
		var movement_envelope := sin(clampf(phase, 0.0, 1.0) * PI)
		var tear_gate := 1.0 if posmod(int(phase * 92.0), 7) < 3 else 0.18
		var tear := (_noise(frame * 17 + 31) * 2.0 - 1.0) * tear_gate * movement_envelope
		var after_mid := maxf(0.0, t - DURATION * 0.47)
		var glass_envelope := exp(-after_mid * 16.0) if phase >= 0.47 else 0.0
		var glass := (sin(TAU * 1840.0 * after_mid) * 0.21 + sin(TAU * 2310.0 * after_mid) * 0.12) * glass_envelope
		var material := 0.0
		match style:
			"corruption":
				var packet_frequency := 210.0 + float(posmod(int(phase * 26.0), 6)) * 73.0
				material = sin(TAU * packet_frequency * t) * 0.16 + tear * 0.42
			"carousel":
				var tooth := fmod(phase * 10.0, 1.0)
				var click := exp(-tooth * 19.0) * sin(TAU * 118.0 * t)
				material = click * 0.22 + sin(TAU * 63.0 * t + phase * phase * 9.0) * 0.16 + tear * 0.17
			_:
				var tooth := fmod(phase * 13.0, 1.0)
				var ratchet := exp(-tooth * 15.0) * sin(TAU * 74.0 * t)
				material = ratchet * 0.26 + sin(TAU * lerpf(46.0, 71.0, phase) * t) * 0.14 + tear * 0.22
		var sample := clampf((material + glass) * 0.72, -1.0, 1.0)
		var value := clampi(roundi(sample * 32760.0), -32768, 32767)
		if value < 0:
			value += 65536
		bytes[frame * 2] = value & 0xff
		bytes[frame * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream


func _noise(value: int) -> float:
	var n := value * 1103515245 + 12345
	n = (n >> 16) & 0x7fff
	return float(n) / 32767.0
