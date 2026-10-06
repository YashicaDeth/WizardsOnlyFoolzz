class_name ExaminerVoice
extends AudioStreamPlayer

## Sound-pass placeholder for the examiner. It voices only text already
## authored by Greg/the design files; this component adds no dialogue. The
## narrow, formant-like synthesis is deliberately temporary and sits behind a
## single level dial so a recorded performance can replace it without changing
## the intake or fight sequencing.

const RATE := 12000
const MIN_SECONDS := 0.65
const MAX_SECONDS := 5.2
const CHAR_SECONDS := 0.052

## Assistant default: clearly readable over the low room bed, but still heard
## through the tank rather than presented as a narrator.
var level := 0.34
var phrases_spoken := 0
var last_text := ""


func _ready() -> void:
	name = "ExaminerVoice"
	AudioBus.route(self, "Bodies")


func speak(text: String, hold := 0.0, muffled := true) -> void:
	var clean := text.replace("//", " ").strip_edges()
	if clean.is_empty() or clean == last_text:
		return
	last_text = clean
	phrases_spoken += 1
	var duration := clampf(maxf(hold, float(clean.length()) * CHAR_SECONDS), MIN_SECONDS, MAX_SECONDS)
	stream = synthesize(clean, duration, muffled)
	volume_db = linear_to_db(clampf(level, 0.001, 1.0))
	play()


static func synthesize(text: String, duration: float, muffled := true) -> AudioStreamWAV:
	var frames := maxi(1, roundi(clampf(duration, MIN_SECONDS, MAX_SECONDS) * RATE))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for frame in frames:
		var t := float(frame) / RATE
		var sample := sample_at(text, t, muffled)
		bytes.encode_s16(frame * 2, clampi(roundi(sample * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav


## Public for the headless sound test: a stable sample proves the placeholder
## contains voiced formants rather than an empty timing track.
static func sample_at(text: String, t: float, muffled := true) -> float:
	if text.is_empty() or t < 0.0:
		return 0.0
	var syllable := int(t * 4.6)
	var index := syllable % text.length()
	var code := text.unicode_at(index)
	# Punctuation creates the short, uncomfortable pauses that keep the intake
	# from becoming a continuous wall of speech.
	if code in [32, 44, 46, 58, 59, 33, 63]:
		return 0.0
	var local := fmod(t * 4.6, 1.0)
	var envelope := smoothstep(0.0, 0.12, local) * (1.0 - smoothstep(0.72, 1.0, local))
	var fundamental := 86.0 + float((code * 17 + syllable * 11) % 31)
	var vowel := float((code * 29) % 100) / 100.0
	var first := lerpf(390.0, 680.0, vowel)
	var second := lerpf(820.0, 1280.0, 1.0 - vowel)
	var voiced := sin(TAU * fundamental * t) * 0.42
	voiced += sin(TAU * fundamental * 2.0 * t) * 0.16
	voiced += sin(TAU * first * t) * (0.10 if muffled else 0.16)
	voiced += sin(TAU * second * t) * (0.025 if muffled else 0.08)
	return clampf(voiced * envelope * 0.72, -1.0, 1.0)
