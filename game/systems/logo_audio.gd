extends Node

## The logo's sounds (Greg, 24 September: more detail on the logo), generated
## like `Opening_Audio`'s placeholders and kept behind one `cue()` so authored
## recordings can replace them: a rising burn as the seal lights, a metal
## clank as its arcs lock, a static crackle on a glitch tear, a low heartbeat
## thump, and a drip tick.

const RATE := 22050
const LENGTHS := {"burn": 1.2, "lock": 0.7, "tear": 0.3, "beat": 0.35, "drip": 0.12}
const LEVELS := {"burn": -12.0, "lock": -6.0, "tear": -16.0, "beat": -14.0, "drip": -20.0}

var voices: Dictionary = {}
var played: Array[String] = []


func _ready() -> void:
	for kind in LENGTHS:
		var player := AudioStreamPlayer.new()
		player.name = "Logo_%s" % kind
		player.stream = wave(kind)
		player.volume_db = float(LEVELS[kind])
		if AudioServer.get_bus_index("SFX") != -1:
			player.bus = "SFX"
		add_child(player)
		voices[kind] = player


func cue(kind: String) -> void:
	played.append(kind)
	var player := voices.get(kind) as AudioStreamPlayer
	if player != null and player.is_inside_tree():
		player.play()


static func wave(kind: String) -> AudioStreamWAV:
	var duration := float(LENGTHS.get(kind, 0.3))
	var frame_count := roundi(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	for frame in frame_count:
		var t := float(frame) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		var sample := 0.0
		match kind:
			"burn":
				# Noise swelling up through a rising tone: something catching.
				var swell := t / duration
				sample = (noise * 0.45 + sin(TAU * lerpf(60.0, 220.0, swell) * t) * 0.35) * swell * (1.0 - swell * 0.3)
			"lock":
				# Iron on iron: a hard hit and two ringing partials.
				sample = (noise * exp(-t * 60.0) * 0.8 + sin(TAU * 310.0 * t) * 0.35 + sin(TAU * 733.0 * t) * 0.18) * exp(-t * 7.0)
			"tear":
				sample = noise * 0.6 * (0.5 + 0.5 * sign(sin(TAU * 38.0 * t))) * exp(-t * 6.0)
			"beat":
				sample = sin(TAU * 46.0 * t) * exp(-t * 16.0) * 0.9
			"drip":
				sample = sin(TAU * lerpf(1400.0, 700.0, t / duration) * t) * exp(-t * 40.0) * 0.6
		var value := clampi(roundi(clampf(sample, -1.0, 1.0) * 32760.0), -32768, 32767)
		if value < 0:
			value += 65536
		bytes[frame * 2] = value & 0xff
		bytes[frame * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream
